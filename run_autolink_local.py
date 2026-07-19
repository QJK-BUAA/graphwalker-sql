"""AutoLink-style Spider2-Lite LOCAL runner with ablations.

Pipeline per question:
  1. build column vector store (optional value_examples enrichment);
  2. ReAct schema-linking agent;
  3. optional LinkAlign-style irrelevant-column isolation;
  4. SQL generation (R1 / chat) with CTE guidance;
  5. optional execution repair + result-driven self-refine;
  6. optional multi-candidate execution-result majority vote;
  7. safe official evaluation (neutralize non-terminating predictions).

Ablation flags (combinable):
  --values / --isolate / --repair / --refine / --candidates K
"""
from __future__ import annotations

import argparse
import json
import os
import re
import threading
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed

from gws2.datasets import load_spider2_lite_local
from gws2.evaluate_official import evaluate
from gws2.execute import run_query
from gws2.llm import LLM
from gws2.pipeline import load_db
from gws2.prompts import PROMPT_SPIDER2_SELF_REFINE
from gws2.schema_agent import isolate_irrelevant, link_schema
from gws2.schema_vec import (ColumnVectorStore, columns_from_local_schema,
                             enrich_value_examples)

GEN_SYS = """You are a SQLite Text-to-SQL expert. Using ONLY the linked schema below (the \
most relevant tables/columns retrieved for this question), write exactly ONE correct \
SQLite query that answers the question.

Linked schema:
{schema}

External knowledge:
{external}

Question:
{question}

Guidelines:
- Use only tables/columns present in the linked schema; use exact names.
- These questions are usually MULTI-STEP analytical: prefer a pipeline of named CTEs \
(WITH step1 AS (...), ...), window functions for rankings / top-N-per-group / running \
totals, and correct GROUP BY keys. A one-line query is usually wrong.
- Apply every definition/formula/filter from the external knowledge literally.
- Return only the columns the question asks for.
Output only the final SQL in a ```sql``` code block."""

REPAIR_SYS = """The previous SQLite query {problem}. Using the linked schema, the failed \
query and the feedback, output ONE corrected SQLite query. Do not explain.

Linked schema:
{schema}

External knowledge:
{external}

Question:
{question}

Previous SQL:
{sql}

Feedback:
{feedback}

Output only the corrected SQL in a ```sql``` code block."""

_SQL = re.compile(r"```sql\s*(.*?)```", re.DOTALL | re.IGNORECASE)


def _extract(t: str) -> str:
    m = _SQL.search(t) or re.search(r"```\s*(.*?)```", t, re.DOTALL)
    s = (m.group(1) if m else t).strip()
    s = re.sub(r"^```(?:sql)?\s*", "", s, flags=re.I).strip()
    return s.rstrip(";").strip()


def _result_preview(ex: dict, max_rows: int = 5) -> str:
    if not ex.get("ok"):
        return "ERROR: " + str(ex.get("error", ""))[:400]
    cols = ex.get("columns") or []
    rows = ex.get("rows") or []
    body = "\n".join(str(x) for x in rows[:max_rows])
    return f"columns: {', '.join(map(str, cols))}\nn_rows_shown={len(rows)}\n{body}"


def _result_sig(ex: dict):
    if not ex.get("ok"):
        return None
    rows = ex.get("rows") or []
    if not rows:
        return None
    return repr(sorted(tuple(str(x) for x in r) for r in rows))


def gen_sql(question: str, schema_text: str, external: str, gen_llm: LLM,
            temperature: float = 0.0) -> str:
    sys = GEN_SYS.format(schema=schema_text[:14000],
                         external=(external or "(none)")[:2000], question=question)
    return _extract(gen_llm.complete(sys, "Generate the SQL.", temperature=temperature))


def repair_and_refine(question: str, schema_text: str, external: str, sql: str,
                      sqlite_path: str, llm: LLM,
                      max_repairs: int = 0, max_refines: int = 0) -> tuple[str, dict]:
    """Execution repair then result-driven self-refine. Returns (sql, meta)."""
    meta = {"repairs": 0, "refines": 0}
    ex = run_query(sqlite_path, sql, max_rows=50, timeout=15.0)

    for attempt in range(max_repairs):
        need = (not ex.get("ok")) or not (ex.get("rows") or [])
        if not need:
            break
        problem = ("failed with an error" if not ex.get("ok")
                   else "returned an empty result")
        feedback = ex.get("error") or "empty result"
        sys = REPAIR_SYS.format(
            problem=problem, schema=schema_text[:12000],
            external=(external or "(none)")[:1500], question=question,
            sql=sql, feedback=str(feedback)[:800])
        rsql = _extract(llm.complete(sys, "Repair the query.", temperature=0.0))
        if not rsql or rsql.strip() == sql.strip():
            break
        rex = run_query(sqlite_path, rsql, max_rows=50, timeout=15.0)
        meta["repairs"] += 1
        if rex.get("ok") and (not ex.get("ok") or (rex.get("rows") or [])):
            sql, ex = rsql, rex
        else:
            break

    for attempt in range(max_refines):
        if (not ex.get("ok")) or not (ex.get("rows") or []):
            break
        sys = PROMPT_SPIDER2_SELF_REFINE.format(
            dialect="SQLite", schema_context=schema_text[:12000],
            external_knowledge=(external or "(none)")[:1500],
            question=question, sql=sql, result_preview=_result_preview(ex))
        resp = llm.complete(sys, "Review, then CONFIRM or output fixed SQL.",
                            temperature=0.0).strip()
        if resp.upper().startswith("CONFIRM"):
            break
        csql = _extract(resp)
        if not csql or csql.strip() == sql.strip():
            break
        cex = run_query(sqlite_path, csql, max_rows=50, timeout=15.0)
        meta["refines"] += 1
        if cex.get("ok") and (cex.get("rows") or []):
            sql, ex = csql, cex
        else:
            break
    return sql, meta


def consensus_sql(question: str, schema_text: str, external: str,
                  sqlite_path: str, gen_llm: LLM, k: int = 3) -> tuple[str, dict]:
    """Generate k candidates and majority-vote on execution results."""
    cands: list[tuple[str, dict, object]] = []
    temps = [0.0] + [0.3] * (k - 1)
    for i in range(k):
        sql = gen_sql(question, schema_text, external, gen_llm,
                      temperature=temps[i] if i < len(temps) else 0.3)
        if not sql:
            sql = "SELECT 1"
        ex = run_query(sqlite_path, sql, max_rows=200, timeout=15.0)
        cands.append((sql, ex, _result_sig(ex)))
    votes = Counter(s for _, _, s in cands if s is not None)
    meta = {"candidates": k,
            "distinct_results": len(votes),
            "top_vote": votes.most_common(1)[0][1] if votes else 0}
    if votes:
        best = votes.most_common(1)[0][0]
        for sql, ex, s in cands:
            if s == best:
                return sql, meta
    for sql, ex, s in cands:
        if ex.get("ok"):
            return sql, meta
    return cands[0][0], meta


def make_executor(sqlite_path: str):
    def _ex(sql: str):
        r = run_query(sqlite_path, sql, max_rows=5, timeout=15.0)
        if r.get("ok"):
            c = r.get("columns") or []
            rows = r.get("rows") or []
            body = "\n".join(str(x) for x in rows[:5])
            return True, "columns: " + ", ".join(map(str, c)) + "\n" + body
        return False, "ERROR: " + str(r.get("error"))[:250]
    return _ex


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="first N examples (0=all 135)")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--model", default="deepseek-chat", help="linking / aux model")
    ap.add_argument("--gen-model", default="deepseek-reasoner", help="SQL generation model")
    ap.add_argument("--seed-top-n", type=int, default=50)
    ap.add_argument("--max-turns", type=int, default=6)
    ap.add_argument("--tag", default="autolink")
    # ablations
    ap.add_argument("--values", action="store_true",
                    help="enrich column docs with DISTINCT value examples")
    ap.add_argument("--isolate", action="store_true",
                    help="LinkAlign-style irrelevant column isolation")
    ap.add_argument("--repair", type=int, default=0,
                    help="max execution repairs (0=off)")
    ap.add_argument("--refine", type=int, default=0,
                    help="max result-driven self-refines (0=off)")
    ap.add_argument("--candidates", type=int, default=1,
                    help="multi-candidate majority vote (1=off)")
    ap.add_argument("--skip-agent", action="store_true",
                    help="seed-only linking (no ReAct turns); for cheap ablations")
    ap.add_argument("--resume", action="store_true",
                    help="keep successful saved results and retry only errors/missing")
    args = ap.parse_args()

    all_exs = load_spider2_lite_local()
    if args.limit > 0:
        all_exs = all_exs[:args.limit]
    flags = []
    if args.values:
        flags.append("values")
    if args.isolate:
        flags.append("isolate")
    if args.repair:
        flags.append(f"repair{args.repair}")
    if args.refine:
        flags.append(f"refine{args.refine}")
    if args.candidates and args.candidates > 1:
        flags.append(f"k{args.candidates}")
    if args.skip_agent:
        flags.append("noagent")
    flag_s = "+".join(flags) if flags else "base"
    out_path = os.path.join("outputs", f"autolink_{args.tag}.json")
    checkpoint_path = out_path + ".checkpoint"
    pred: dict = {}
    recs: dict = {}
    if args.resume:
        saved_path = out_path if os.path.exists(out_path) else checkpoint_path
        if os.path.exists(saved_path):
            saved = json.load(open(saved_path))
            pred.update(saved.get("pred") or {})
            recs.update(saved.get("meta") or {})
    successful = {
        iid for iid, meta in recs.items()
        if iid in pred and not (meta or {}).get("error")
    }
    exs = [e for e in all_exs if e.instance_id not in successful]
    print(f"[autolink-{args.tag}] {len(exs)} local | link={args.model} "
          f"gen={args.gen_model} flags={flag_s} workers={args.workers}")
    if args.resume:
        print(f"[autolink-{args.tag}] resume: kept {len(successful)}, "
              f"retrying {len(exs)}", flush=True)

    aux = LLM(model=args.model)
    gen = LLM(model=args.gen_model)
    cache: dict = {}
    clock = threading.Lock()

    def _build_store(e):
        sch = load_db(e.sqlite_path)
        cols = columns_from_local_schema(sch)
        suffix = "_vals" if args.values else ""
        cache_path = f"outputs/vec_cache/{e.db_id}{suffix}"
        if args.values:
            need_build = True
            if os.path.exists(cache_path + ".json"):
                prev = __import__("json").load(open(cache_path + ".json"))
                if prev and any(c.get("value_examples") for c in prev):
                    need_build = False
            if need_build:
                print(f"  [vec] enrich+embed {e.db_id} ...", flush=True)
                cols = enrich_value_examples(cols, e.sqlite_path)
                for ext in (".npy", ".json"):
                    p = cache_path + ext
                    if os.path.exists(p):
                        os.remove(p)
        store = ColumnVectorStore.build(cols, cache_path=cache_path)
        return sch, store

    # Pre-build vector stores serially (avoids embed/SQLite races under workers).
    db_paths = {}
    for e in exs:
        db_paths.setdefault(e.db_id, e)
    print(f"[autolink-{args.tag}] prebuilding {len(db_paths)} DB vector stores "
          f"(values={args.values}) ...", flush=True)
    for db_id, e in db_paths.items():
        key = (db_id, bool(args.values))
        cache[key] = _build_store(e)
    print(f"[autolink-{args.tag}] vector stores ready", flush=True)

    def get_store(e):
        key = (e.db_id, bool(args.values))
        with clock:
            if key in cache:
                return cache[key]
        # fallback (should not hit after prebuild)
        with clock:
            cache[key] = _build_store(e)
            return cache[key]

    t0 = time.time()
    done = 0

    def checkpoint() -> None:
        tmp = checkpoint_path + ".tmp"
        json.dump({"pred": pred, "meta": recs, "flags": flag_s},
                  open(tmp, "w"), ensure_ascii=False)
        os.replace(tmp, checkpoint_path)

    def work(e):
        try:
            sch, store = get_store(e)
            max_turns = 0 if args.skip_agent else args.max_turns
            linked, schema_text, trace = link_schema(
                e.question, e.evidence, list(sch.tables.keys()), store,
                make_executor(e.sqlite_path), aux, dialect="SQLite",
                seed_top_n=args.seed_top_n, max_turns=max_turns)
            iso_note = ""
            if args.isolate:
                linked, iso_note = isolate_irrelevant(
                    linked, e.question, e.evidence, aux)
                from gws2.schema_agent import _fmt_cols
                schema_text = _fmt_cols(linked)
            meta = {"linked": len(linked), "iso": iso_note,
                    "trace_tail": (trace[-1] if trace else "")}

            if args.candidates and args.candidates > 1:
                sql, cmeta = consensus_sql(
                    e.question, schema_text, e.evidence, e.sqlite_path,
                    gen, k=args.candidates)
                meta.update(cmeta)
            else:
                sql = gen_sql(e.question, schema_text, e.evidence, gen) or "SELECT 1"

            if args.repair or args.refine:
                sql, rmeta = repair_and_refine(
                    e.question, schema_text, e.evidence, sql, e.sqlite_path, gen,
                    max_repairs=args.repair, max_refines=args.refine)
                meta.update(rmeta)
            return e.instance_id, (sql or "SELECT 1"), meta
        except Exception as exc:  # noqa: BLE001
            import traceback
            err = f"{type(exc).__name__}: {exc}"[:300]
            print(f"  ERR {e.instance_id}: {err}", flush=True)
            return e.instance_id, "SELECT 1", {
                "error": err, "tb": traceback.format_exc()[-500:]}

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(work, e): e for e in exs}
        for f in as_completed(futs):
            iid, sql, meta = f.result()
            pred[iid] = sql
            recs[iid] = meta
            done += 1
            checkpoint()
            if done % 10 == 0 or done == len(exs):
                print(f"  [{done}/{len(exs)}] {iid} linked={meta.get('linked','?')} "
                      f"r={meta.get('repairs',0)} f={meta.get('refines',0)} "
                      f"({time.time()-t0:.0f}s)")

    neut = []
    for e in all_exs:
        sql = pred.get(e.instance_id) or "SELECT 1"
        ts = time.time()
        r = run_query(e.sqlite_path, sql, max_rows=1000, timeout=15.0)
        if not r.get("ok") and time.time() - ts >= 14.0:
            pred[e.instance_id] = "SELECT 1  -- neutralized: non-terminating"
            neut.append(e.instance_id)
    print(f"[autolink-{args.tag}] neutralized {len(neut)}: {neut}")

    out_dir = os.path.join("outputs", "eval_work", "autolink_" + args.tag)
    res = evaluate("spider2-lite-local", all_exs, pred, out_dir)
    # persist predictions + meta for later comparison
    json.dump({"pred": pred, "meta": recs, "ex": res.get("ex"),
               "correct": res.get("correct"), "flags": flag_s},
              open(out_path, "w"),
              ensure_ascii=False, indent=2)
    print(f"[autolink-{args.tag}] EX={res.get('ex')} correct={res.get('correct')} "
          f"scored={res.get('scored')} n={res.get('n')} flags={flag_s} "
          f"| {time.time()-t0:.0f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
