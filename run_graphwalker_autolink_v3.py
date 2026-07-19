"""GraphWalker-AutoLink v3 benchmark runner.

Uses released high-recall AutoLink schema prompts, then applies an official-like
five-candidate Reasoner stack with GraphWalker cost guards, bounded retries,
Snowflake quoting fallback, checkpoint/resume, and official Spider2 evaluation.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

from run_spider2lite_online import (VALID_PREFIXES, evaluate_official,
                                    load_spider2_lite_mixed)
from gws2.autolink_v3 import load_official_prompts, solve
from gws2.cloud_execute import close_cloud
from gws2.llm import LLM


DEFAULT_AUTOLINK_ROOT = Path(
    os.environ.get(
        "GWS2_AUTOLINK_ROOT",
        str(Path(__file__).resolve().parent.parent / "AutoLink"),
    )
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prefix", action="append",
                        choices=list(VALID_PREFIXES))
    parser.add_argument("--ids", default="")
    parser.add_argument("--ids-file", default="")
    parser.add_argument("--sample", type=int, default=0)
    parser.add_argument("--sample-seed", type=int, default=42)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--model", default="deepseek-reasoner")
    parser.add_argument("--candidates", type=int, default=5)
    parser.add_argument("--revisions", type=int, default=5)
    parser.add_argument("--tag", default="autolink_v3")
    parser.add_argument("--schema-dir",
                        default=str(DEFAULT_AUTOLINK_ROOT / "linking_results"))
    parser.add_argument("--official-config",
                        default=str(DEFAULT_AUTOLINK_ROOT / "run" / "config.py"))
    parser.add_argument("--bq-credential", default="")
    parser.add_argument("--sf-credential", default="")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--no-eval", action="store_true")
    args = parser.parse_args()

    if args.bq_credential:
        os.environ["GWS2_BIGQUERY_CREDENTIAL"] = args.bq_credential
    if args.sf_credential:
        os.environ["GWS2_SNOWFLAKE_CREDENTIAL"] = args.sf_credential

    prefixes = set(args.prefix or VALID_PREFIXES)
    all_examples = load_spider2_lite_mixed(prefixes=prefixes)
    requested = {x.strip() for x in args.ids.split(",") if x.strip()}
    if args.ids_file:
        requested.update(
            line.strip() for line in open(args.ids_file)
            if line.strip()
        )
    if requested:
        all_examples = [
            ex for ex in all_examples if ex.instance_id in requested
        ]
    elif args.sample and args.sample < len(all_examples):
        all_examples = random.Random(args.sample_seed).sample(
            all_examples, args.sample)
    if not all_examples:
        raise SystemExit("No examples selected")

    schema_dir = Path(args.schema_dir)
    prompts = load_official_prompts(args.official_config)
    missing = [
        ex.instance_id for ex in all_examples
        if not (schema_dir / f"{ex.instance_id}.txt").exists()
    ]
    if missing:
        raise SystemExit(
            f"Missing {len(missing)} schema prompts: {missing[:10]}")

    run_name = f"graphwalker_autolink_v3_{args.tag}"
    output_json = Path("outputs") / f"{run_name}.json"
    checkpoint_json = Path(str(output_json) + ".checkpoint")
    predictions: dict[str, str] = {}
    records: dict[str, dict] = {}
    if args.resume:
        saved_path = output_json if output_json.exists() else checkpoint_json
        if saved_path.exists():
            saved = json.load(open(saved_path))
            predictions.update(saved.get("pred") or {})
            records.update(saved.get("meta") or {})
    successful = {
        iid for iid, record in records.items()
        if iid in predictions and not record.get("error")
    }
    examples = [
        ex for ex in all_examples if ex.instance_id not in successful
    ]

    print(f"[{run_name}] total={len(all_examples)} retry={len(examples)} "
          f"workers={args.workers} candidates={args.candidates} "
          f"revisions={args.revisions}", flush=True)
    llm = LLM(model=args.model, seed=None, timeout=600.0,
              max_retries=8)
    lock = threading.Lock()
    started = time.time()

    def checkpoint() -> None:
        tmp = Path(str(checkpoint_json) + ".tmp")
        json.dump({"pred": predictions, "meta": records}, open(tmp, "w"),
                  ensure_ascii=False)
        os.replace(tmp, checkpoint_json)

    def work(ex):
        try:
            schema = (schema_dir / f"{ex.instance_id}.txt").read_text()
            sql, metadata = solve(
                ex, schema, llm, num_candidates=args.candidates,
                max_revisions=args.revisions, prompts=prompts)
            return ex.instance_id, sql, {
                "instance_id": ex.instance_id,
                "backend": ex.backend,
                "db_id": ex.db_id,
                **metadata,
            }
        except Exception as exc:  # noqa: BLE001
            return ex.instance_id, "SELECT 1", {
                "instance_id": ex.instance_id,
                "backend": ex.backend,
                "db_id": ex.db_id,
                "error": f"{type(exc).__name__}: {exc}"[:500],
            }

    done = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(work, ex): ex for ex in examples}
        for future in as_completed(futures):
            iid, sql, record = future.result()
            with lock:
                predictions[iid] = sql
                records[iid] = record
                checkpoint()
                done += 1
                print(f"  [{done}/{len(examples)}] {iid} "
                      f"error={bool(record.get('error'))} "
                      f"({time.time()-started:.0f}s)", flush=True)

    close_cloud()
    result_dir = Path("outputs") / "eval_work" / run_name / "sql_submit"
    result_dir.mkdir(parents=True, exist_ok=True)
    for old in result_dir.glob("*.sql"):
        old.unlink()
    for iid, sql in predictions.items():
        (result_dir / f"{iid}.sql").write_text(sql)

    evaluation = {}
    if not args.no_eval:
        eval_run_id = f"{run_name}_{int(time.time())}"
        print(f"[{run_name}] running official evaluator ...", flush=True)
        evaluation = evaluate_official(eval_run_id, result_dir)
        print(f"[{run_name}] EX={evaluation.get('ex')} "
              f"correct={evaluation.get('correct')} "
              f"scored={evaluation.get('scored')}", flush=True)

    payload = {
        "run_id": run_name,
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "args": vars(args),
        "n": len(all_examples),
        "pred": predictions,
        "meta": records,
        "official_eval": evaluation,
        "llm_stats": llm.stats(),
        "elapsed_sec": round(time.time() - started, 1),
    }
    json.dump(payload, open(output_json, "w"),
              ensure_ascii=False, indent=2)
    print(f"[{run_name}] wrote {output_json}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
