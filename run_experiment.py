"""GraphWalker-SQL 2.0 experiment runner.

Runs the Ground -> Explore -> Commit pipeline over a sampled subset of a
benchmark, then scores predictions with the OFFICIAL evaluator. Every result
JSON records the full args, model, seed and LLM usage so runs are reproducible
and auditable (project requirement).

Examples
--------
    export DS_API_KEY=sk-...
    python run_experiment.py --dataset bird         --limit 20
    python run_experiment.py --dataset spider1      --limit 20
    python run_experiment.py --dataset spider2-lite --limit 20
    # ablation:
    python run_experiment.py --dataset bird --limit 20 --ablation nowalk
"""
from __future__ import annotations

import argparse
import json
import os
import threading
import time
from datetime import datetime

from gws2 import config
from gws2.datasets import load_and_sample
from gws2.evaluate_official import evaluate
from gws2.llm import LLM
from gws2.pipeline import AblationConfig, load_db, run_pipeline

ABLATION_PRESETS = {
    "full": {},
    "noinfer": {"use_inferred_graph": False},
    "nowalk": {"use_belief_walk": False},
    "notopk": {"use_topk": False},
    "noprobe": {"use_probes": False},
    "nocolprobe": {"use_column_probes": False},
    "nostop": {"use_entropy_stop": False},
    "nopropose": {"use_propose": False},
    "norepair": {"max_repairs": 0},
    # Opt-in variant: require structural join evidence before accepting a
    # Propose-suggested missing table. BIRD n=100 rerun: 47 vs 48 for default,
    # so it is kept as a studied ablation rather than default.
    "propgate": {"use_propose_evidence_gate": True},
    # Opt-in variant: dedicated evidence block + mined hints (BIRD n=100: worse
    # than the fold default, 44 vs 48). Kept for reproducibility of that finding.
    "evidenceblock": {"use_evidence_injection": True},
    # Opt-in variant: trim/reorder SELECT list to what the question asks (BIRD
    # grades whole rows; ~43 wrong questions are format-only recoverable).
    "colalign": {"use_column_align": True},
}


def build_ablation(name: str) -> AblationConfig:
    if name not in ABLATION_PRESETS:
        raise SystemExit(f"Unknown ablation {name!r}; choose {list(ABLATION_PRESETS)}")
    return AblationConfig(**ABLATION_PRESETS[name])


def main():
    ap = argparse.ArgumentParser(description="GraphWalker-SQL 2.0 runner")
    ap.add_argument("--dataset", required=True,
                    choices=["bird", "spider1", "spider2-lite"])
    ap.add_argument("--limit", type=int, default=20,
                    help="number of questions (<=0 or 'full' via --full for all)")
    ap.add_argument("--full", action="store_true",
                    help="run the ENTIRE dataset (ignore --limit)")
    ap.add_argument("--seed", type=int, default=config.DEFAULT_SEED)
    ap.add_argument("--model", default=config.DEFAULT_MODEL)
    ap.add_argument("--ablation", default="full", choices=list(ABLATION_PRESETS))
    ap.add_argument("--workers", type=int, default=1,
                    help="concurrent worker threads (LLM calls are IO-bound)")
    ap.add_argument("--outdir", default="outputs")
    ap.add_argument("--no-eval", action="store_true", help="skip official eval")
    ap.add_argument("--with-snapshot", action="store_true",
                    help="store full belief snapshot per question (verbose)")
    ap.add_argument("--tag", default="", help="optional run tag for the filename")
    args = ap.parse_args()

    ablation = build_ablation(args.ablation)
    llm = LLM(model=args.model, seed=args.seed)
    limit = None if args.full else args.limit
    examples = load_and_sample(args.dataset, limit, seed=args.seed)
    dialect = "SQLite"

    run_id = (f"{args.dataset}_{ablation.tag()}_{args.model}"
              + (f"_{args.tag}" if args.tag else "")
              + f"_seed{args.seed}")
    outdir = os.path.abspath(args.outdir)
    os.makedirs(outdir, exist_ok=True)

    print(f"[{run_id}] {len(examples)} questions | model={args.model} "
          f"seed={args.seed} ablation={ablation.tag()} workers={args.workers}")

    # Per-DB schema cache: BIRD/Spider each reuse a handful of DBs across many
    # questions, so extracting schema + column stats once per DB is a big win.
    schema_cache: dict[str, object] = {}
    cache_lock = threading.Lock()

    def get_schema(sqlite_path: str):
        with cache_lock:
            sc = schema_cache.get(sqlite_path)
        if sc is None:
            sc = load_db(sqlite_path, with_stats=True)
            with cache_lock:
                schema_cache[sqlite_path] = sc
        return sc

    def work(ex):
        try:
            schema = get_schema(ex.sqlite_path)
            res = run_pipeline(
                schema, ex.sqlite_path, ex.question, llm,
                evidence=ex.evidence, ablation=ablation, dialect=dialect,
                prefer_declared=True, with_snapshot=args.with_snapshot,
            )
            rec = {
                "instance_id": ex.instance_id, "db_id": ex.db_id,
                "difficulty": ex.difficulty, "question": ex.question,
                "gold_sql": ex.gold_sql, "pred_sql": res.sql,
                "graph_method": res.graph_method, "n_edges": res.n_edges,
                "sources": res.sources, "destinations": res.destinations,
                "linked_tables": res.linked_tables, "chosen_path": res.chosen_path,
                "n_probes": res.n_probes, "n_column_probes": res.n_column_probes,
                "column_hints": res.column_hints,
                "propose_verdict": res.propose_verdict,
                "missing_added": res.missing_added,
                "missing_rejected": res.missing_rejected, "repaired": res.repaired,
                "exec_ok": res.execution.get("ok"),
                "exec_rows": res.execution.get("n_shown"),
                "belief_entropy": res.belief_entropy, "trace": res.trace,
            }
            if args.with_snapshot:
                rec["belief_snapshot"] = res.belief_snapshot
            return ex.instance_id, res.sql, rec, res.execution.get("ok")
        except Exception as e:  # noqa: BLE001
            return (ex.instance_id, "SELECT 1",
                    {"instance_id": ex.instance_id, "db_id": ex.db_id,
                     "error": str(e), "pred_sql": "SELECT 1"}, None)

    records_by_id: dict[str, dict] = {}
    pred_sql: dict[str, str] = {}
    t0 = time.time()
    done = 0
    if args.workers > 1:
        from concurrent.futures import ThreadPoolExecutor, as_completed
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futs = {pool.submit(work, ex): ex for ex in examples}
            for fut in as_completed(futs):
                iid, sql, rec, ok = fut.result()
                pred_sql[iid] = sql
                records_by_id[iid] = rec
                done += 1
                if done % 25 == 0 or done == len(examples):
                    print(f"  [{done}/{len(examples)}] latest={iid} "
                          f"exec={'ok' if ok else ('ERR' if ok is False else 'PIPE-ERR')}"
                          f"  ({time.time()-t0:.0f}s)")
    else:
        for i, ex in enumerate(examples):
            iid, sql, rec, ok = work(ex)
            pred_sql[iid] = sql
            records_by_id[iid] = rec
            if (i + 1) % 25 == 0 or i + 1 == len(examples):
                print(f"  [{i+1}/{len(examples)}] {iid} "
                      f"exec={'ok' if ok else ('ERR' if ok is False else 'PIPE-ERR')}"
                      f"  ({time.time()-t0:.0f}s)")
    # keep records in the sampled order for stable, aligned evaluation
    records = [records_by_id[ex.instance_id] for ex in examples]
    elapsed = time.time() - t0

    # ---- official evaluation ---------------------------------------------- #
    eval_result = {}
    if not args.no_eval:
        eval_wd = os.path.join(outdir, "eval_work", run_id)
        print(f"[{run_id}] running official {args.dataset} evaluator ...")
        eval_result = evaluate(args.dataset, examples, pred_sql, eval_wd)
        print(f"[{run_id}] EX = {eval_result.get('ex')}  (n={eval_result.get('n')})")

    payload = {
        "run_id": run_id,
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "args": vars(args),
        "model": args.model,
        "seed": args.seed,
        "ablation": ablation.tag(),
        "ablation_config": vars(ablation),
        "dataset": args.dataset,
        "n_questions": len(examples),
        "elapsed_sec": round(elapsed, 1),
        "llm_stats": llm.stats(),
        "official_eval": eval_result,
        "records": records,
    }
    out_path = os.path.join(outdir, f"{run_id}.json")
    json.dump(payload, open(out_path, "w"), ensure_ascii=False, indent=2)
    print(f"[{run_id}] wrote {out_path}")
    print(f"[{run_id}] LLM: {llm.stats()} | {elapsed:.1f}s")


if __name__ == "__main__":
    main()
