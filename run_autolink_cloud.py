"""AutoLink-style schema linking on Spider2-Lite CLOUD (BQ/SF/GA) sample.

Uses DDL-derived column vector store + ReAct linking + existing online
generate/repair/refine path. Designed for sample-N validation after local
ablations pick a winning flag combo.

Example:
  python3 -u run_autolink_cloud.py --sample 30 --sample-seed 42 --workers 4 \
      --isolate --repair 2 --refine 2 --tag cloud_s30
"""
from __future__ import annotations

import argparse
import calendar
import hashlib
import json
import os
import random
import re
import sys
import threading
import time
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# reuse online loader / eval helpers
from run_spider2lite_online import (  # noqa: E402
    Spider2OnlineExample, load_spider2_lite_mixed, _extract_sql,
    _result_preview, _problem_label, _snowflake_repair_hint,
)
from gws2 import config
from gws2.cloud_consensus import Candidate, result_signature, vote
from gws2.cloud_execute import close_cloud, run_cloud
from gws2.llm import LLM
from gws2.online_schema import OnlineSchema, load_online_schema, rank_tables
from gws2.prompts import (PROMPT_SNOWFLAKE_DIALECT, PROMPT_SPIDER2_ONLINE_REPAIR,
                          PROMPT_SPIDER2_ONLINE_SQL, PROMPT_SPIDER2_SELF_REFINE)
from gws2.schema_agent import isolate_irrelevant, link_schema
from gws2.schema_vec import ColumnVectorStore, columns_from_online_schema

SPIDER2_ROOT = Path(config.SPIDER2_ROOT)
DB_DIR = SPIDER2_ROOT / "resource" / "databases"

GEN_HINT = (
    "\nAnalytical decomposition: prefer a PIPELINE OF NAMED CTEs and WINDOW "
    "FUNCTIONS. A one-line query is usually wrong for these tasks.\n"
)


def _prune_massive_schema(schema: OnlineSchema, question: str,
                          external: str) -> OnlineSchema:
    """Collapse date-sharded warehouses before column embedding.

    Some Spider2 resources expose thousands of daily/monthly physical tables
    (e.g. GITHUB_REPOS_DATE has 5,173 tables / 725k parsed columns). Embedding
    every duplicate shard is both wasteful and harmful. Keep static tables plus
    the month/year shard explicitly requested by the question.
    """
    if len(schema.tables) <= 500:
        return schema

    text = f"{question} {external}".lower()
    years = set(re.findall(r"\b(?:19|20)\d{2}\b", text))
    month_nums: set[str] = set()
    for i, name in enumerate(calendar.month_name):
        if i and name.lower() in text:
            month_nums.add(f"{i:02d}")
    for i, name in enumerate(calendar.month_abbr):
        if i and re.search(rf"\b{re.escape(name.lower())}\b", text):
            month_nums.add(f"{i:02d}")
    month_keys = {y + m for y in years for m in month_nums}
    month_keys.update(
        y + m.zfill(2)
        for y, m in re.findall(r"\b((?:19|20)\d{2})[-/](\d{1,2})\b", text)
    )

    temporal = {"DAY", "MONTH", "YEAR"}
    static = [t for t in schema.tables if t.dataset.upper() not in temporal]
    selected = list(static)
    for t in schema.tables:
        dataset = t.dataset.upper()
        digits = "".join(re.findall(r"\d", t.table_name))
        if dataset == "MONTH" and any(digits.endswith(k) for k in month_keys):
            selected.append(t)
        elif dataset == "YEAR" and not month_keys and any(
                digits.endswith(y) for y in years):
            selected.append(t)

    if len(selected) == len(static):
        # Unknown sharding convention: retain the strongest lexical candidates.
        selected.extend(
            t for t in rank_tables(schema, question, external)
            if t not in static
        )
    selected = selected[:200]
    return OnlineSchema(backend=schema.backend, db_id=schema.db_id,
                        tables=selected)


def _format_cloud_cols(cols: list[dict], backend: str) -> str:
    """DDL-like linked schema; quote Snowflake columns exactly as stored."""
    grouped: "OrderedDict[str, list[dict]]" = OrderedDict()
    for col in cols:
        grouped.setdefault(col["table"], []).append(col)
    blocks = []
    for table, table_cols in grouped.items():
        lines = [f"# Table: {table}"]
        for col in table_cols:
            name = col["column"]
            if backend == "snowflake":
                name = '"' + name.replace('"', '""') + '"'
            desc = f" -- {col['description']}" if col.get("description") else ""
            values = (f" e.g. {col['value_examples']}"
                      if col.get("value_examples") else "")
            lines.append(f"  ({name}: {col.get('type', '')}{values}){desc}")
        blocks.append("\n".join(lines))
    return "\n".join(blocks)


def _quote_snowflake_sql(sql: str) -> str:
    """Quote all parsed identifiers while preserving their written case."""
    try:
        import sqlglot
        return sqlglot.transpile(
            sql, read="snowflake", write="snowflake",
            identify=True, pretty=True)[0]
    except Exception:  # noqa: BLE001
        return sql


def _execute_with_quote_fallback(ex: Spider2OnlineExample,
                                 sql: str) -> tuple[str, object, bool]:
    """Execute SQL; on Snowflake identifier failure, retry quoted SQL."""
    res = run_cloud(ex.backend, sql, database=ex.db_id)
    if ex.backend != "snowflake" or res.ok:
        return sql, res, False
    quoted = _quote_snowflake_sql(sql)
    if not quoted or quoted.strip() == sql.strip():
        return sql, res, False
    quoted_res = run_cloud(ex.backend, quoted, database=ex.db_id)
    if quoted_res.ok:
        return quoted, quoted_res, True
    return sql, res, False


def make_cloud_executor(backend: str, db_id: str):
    def _ex(sql: str):
        # force LIMIT if missing (cheap guard)
        s = sql.strip().rstrip(";")
        if "limit" not in s.lower():
            s = s + " LIMIT 5"
        res = run_cloud(backend, s, database=db_id)
        if res.ok:
            cols = ", ".join(map(str, res.columns or []))
            rows = "\n".join(str(x) for x in (res.rows or [])[:5])
            return True, f"columns: {cols}\n{rows}"
        return False, "ERROR: " + str(res.error or "")[:250]
    return _ex


def gen_and_fix(ex: Spider2OnlineExample, schema_text: str, llm: LLM,
                max_repairs: int, max_refines: int,
                n_candidates: int = 1) -> tuple[str, dict]:
    dialect = ("BigQuery" if ex.backend == "bigquery"
               else "Snowflake" if ex.backend == "snowflake" else "SQLite")
    dialect_block = ("\n\n" + PROMPT_SNOWFLAKE_DIALECT
                     if ex.backend == "snowflake" else "")
    external = (ex.external_knowledge or "")[:2000]
    system = PROMPT_SPIDER2_ONLINE_SQL.format(
        dialect=dialect,
        schema_context=schema_text[:14000] + GEN_HINT + dialect_block,
        external_knowledge=external or "(none)",
        question=ex.question,
    )
    sql = _extract_sql(llm.complete(system, "Generate the SQL.", temperature=0.0))
    meta = {"repairs": 0, "refines": 0, "quote_fixes": 0,
            "exec_trace": []}
    sql, res, quote_fixed = _execute_with_quote_fallback(ex, sql)
    meta["quote_fixes"] += int(quote_fixed)

    for attempt in range(max_repairs):
        need = (not res.ok) or res.n_shown == 0
        if not need:
            break
        feedback = (res.error or "empty result")[:1500] + _snowflake_repair_hint(
            ex.backend, res.error or "")
        repair_sys = PROMPT_SPIDER2_ONLINE_REPAIR.format(
            dialect=dialect, problem=_problem_label(res),
            schema_context=schema_text[:12000] + dialect_block,
            external_knowledge=external or "(none)",
            question=ex.question, sql=sql, feedback=feedback)
        rsql = _extract_sql(llm.complete(repair_sys, "Repair the query.",
                                         temperature=0.0))
        if not rsql or rsql.strip() == sql.strip():
            break
        rsql, rres, quote_fixed = _execute_with_quote_fallback(ex, rsql)
        meta["quote_fixes"] += int(quote_fixed)
        meta["repairs"] += 1
        if rres.ok and (not res.ok or rres.n_shown > 0):
            sql, res = rsql, rres
        else:
            break

    for attempt in range(max_refines):
        if (not res.ok) or res.n_shown == 0:
            break
        refine_sys = PROMPT_SPIDER2_SELF_REFINE.format(
            dialect=dialect, schema_context=schema_text[:12000] + dialect_block,
            external_knowledge=external or "(none)", question=ex.question,
            sql=sql, result_preview=_result_preview(res))
        resp = llm.complete(refine_sys, "Review, then CONFIRM or output fixed SQL.",
                            temperature=0.0).strip()
        if resp.upper().startswith("CONFIRM"):
            break
        csql = _extract_sql(resp)
        if not csql or csql.strip() == sql.strip():
            break
        csql, cres, quote_fixed = _execute_with_quote_fallback(ex, csql)
        meta["quote_fixes"] += int(quote_fixed)
        meta["refines"] += 1
        if cres.ok and cres.n_shown > 0:
            sql, res = csql, cres
        else:
            break

    if n_candidates > 1:
        candidates = [
            Candidate(
                sql=sql,
                ok=res.ok,
                n_rows=res.n_shown,
                signature=result_signature(res.rows or [], res.columns or []),
                est_gb=res.est_gb,
            )
        ]
        for _ in range(n_candidates - 1):
            csql = _extract_sql(
                llm.complete(system, "Generate an alternative SQL.",
                             temperature=0.3)
            )
            csql, cres, quote_fixed = _execute_with_quote_fallback(ex, csql)
            meta["quote_fixes"] += int(quote_fixed)
            candidates.append(
                Candidate(
                    sql=csql,
                    ok=cres.ok,
                    n_rows=cres.n_shown,
                    signature=result_signature(cres.rows or [],
                                               cres.columns or []),
                    est_gb=cres.est_gb,
                )
            )
        winner, info = vote(candidates)
        meta["consensus"] = info
        # Agreement is meaningful; row-count tie-breaking is not. Preserve an
        # executable primary on all-unique ties, but recover a failed/empty
        # primary with any executable alternative.
        should_adopt = (
            winner is not None
            and (info.get("winner_votes", 0) >= 2
                 or not res.ok or res.n_shown == 0)
        )
        info["adopted"] = bool(should_adopt)
        if should_adopt:
            sql = winner.sql
            meta["final_ok"] = winner.ok
            meta["final_rows"] = winner.n_rows
        else:
            meta["final_ok"] = res.ok
            meta["final_rows"] = res.n_shown
    else:
        meta["final_ok"] = res.ok
        meta["final_rows"] = res.n_shown
    meta["final_error"] = "" if meta["final_ok"] else (res.error or "")[:500]
    return sql or "SELECT 1", meta


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample", type=int, default=30)
    ap.add_argument("--sample-seed", type=int, default=42)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--model", default="deepseek-chat")
    ap.add_argument("--gen-model", default="deepseek-chat",
                    help="cloud gen default=chat (R1 slower/costlier on cloud)")
    ap.add_argument("--seed-top-n", type=int, default=40)
    ap.add_argument("--max-turns", type=int, default=5)
    ap.add_argument("--isolate", action="store_true")
    ap.add_argument("--repair", type=int, default=2)
    ap.add_argument("--refine", type=int, default=2)
    ap.add_argument("--candidates", type=int, default=1,
                    help="execution-result vote over K candidates (1=off)")
    ap.add_argument("--tag", default="cloud_al")
    ap.add_argument("--resume", action="store_true",
                    help="keep successful saved results and retry errors/missing")
    ap.add_argument("--prefix", action="append", default=None,
                    help="repeatable: bq/sf/ga (default: all cloud)")
    ap.add_argument("--ids", default="",
                    help="comma-separated instance IDs; overrides --sample")
    args = ap.parse_args()

    prefixes = set(args.prefix) if args.prefix else {"bq", "sf", "ga"}
    all_exs = load_spider2_lite_mixed(prefixes=prefixes)
    rng = random.Random(args.sample_seed)
    requested_ids = {x.strip() for x in args.ids.split(",") if x.strip()}
    if requested_ids:
        all_exs = [e for e in all_exs if e.instance_id in requested_ids]
    elif args.sample and args.sample < len(all_exs):
        all_exs = rng.sample(all_exs, args.sample)
    out_json = f"outputs/spider2-lite_autolink_{args.tag}.json"
    checkpoint_json = out_json + ".checkpoint"
    pred: dict = {}
    recs: dict = {}
    if args.resume:
        saved_path = out_json if os.path.exists(out_json) else checkpoint_json
        if os.path.exists(saved_path):
            saved = json.load(open(saved_path))
            pred.update(saved.get("pred") or {})
            recs.update(saved.get("meta") or {})
    successful = {
        iid for iid, meta in recs.items()
        if iid in pred and not (meta or {}).get("error")
    }
    exs = [e for e in all_exs if e.instance_id not in successful]
    print(f"[autolink-cloud-{args.tag}] n={len(exs)} prefixes={sorted(prefixes)} "
          f"isolate={args.isolate} repair={args.repair} refine={args.refine} "
          f"candidates={args.candidates}")
    if args.resume:
        print(f"[autolink-cloud-{args.tag}] resume: kept {len(successful)}, "
              f"retrying {len(exs)}", flush=True)

    aux = LLM(model=args.model)
    gen = LLM(model=args.gen_model)
    cache: dict = {}
    raw_schema_cache: dict = {}
    clock = threading.Lock()

    def get_store(ex: Spider2OnlineExample):
        raw_key = (ex.backend, ex.db_id)
        with clock:
            if raw_key not in raw_schema_cache:
                raw_schema_cache[raw_key] = load_online_schema(
                    ex.backend, ex.db_id, DB_DIR)
            raw_schema = raw_schema_cache[raw_key]
            sch = _prune_massive_schema(
                raw_schema, ex.question, ex.external_knowledge or "")
            selected_names = "\n".join(t.fqn() for t in sch.tables)
            selection_id = hashlib.sha1(
                selected_names.encode("utf-8")).hexdigest()[:10]
            key = (ex.backend, ex.db_id, selection_id)
            if key in cache:
                return cache[key]
            cols = columns_from_online_schema(sch)
            suffix = ("" if len(sch.tables) == len(raw_schema.tables)
                      else "_" + selection_id)
            store = ColumnVectorStore.build(
                cols, cache_path=(
                    f"outputs/vec_cache/cloud_{ex.backend}_{ex.db_id}{suffix}"))
            cache[key] = (sch, store)
            return cache[key]

    # Load torch/sentence-transformers and build stores on the main thread.
    # Initialising a Transformers model inside macOS worker threads can leave
    # parameters on the meta device ("Cannot copy out of meta tensor").
    print(f"[autolink-cloud-{args.tag}] prebuilding vector stores for "
          f"{len(exs)} examples ...", flush=True)
    for i, ex in enumerate(exs, 1):
        get_store(ex)
        if i % 20 == 0 or i == len(exs):
            print(f"  [vec {i}/{len(exs)}]", flush=True)
    print(f"[autolink-cloud-{args.tag}] vector stores ready", flush=True)

    t0 = time.time()
    done = 0

    def checkpoint() -> None:
        tmp = checkpoint_json + ".tmp"
        json.dump({"pred": pred, "meta": recs}, open(tmp, "w"),
                  ensure_ascii=False)
        os.replace(tmp, checkpoint_json)

    def work(ex: Spider2OnlineExample):
        try:
            sch, store = get_store(ex)
            tables = [t.fqn() for t in sch.tables]
            linked, schema_text, trace = link_schema(
                ex.question, ex.external_knowledge or "", tables, store,
                make_cloud_executor(ex.backend, ex.db_id), aux,
                dialect=("BigQuery" if ex.backend == "bigquery" else "Snowflake"),
                seed_top_n=args.seed_top_n, max_turns=args.max_turns)
            if args.isolate:
                linked, iso = isolate_irrelevant(
                    linked, ex.question, ex.external_knowledge or "", aux)
            else:
                iso = ""
            schema_text = _format_cloud_cols(linked, ex.backend)
            sql, meta = gen_and_fix(ex, schema_text, gen, args.repair,
                                    args.refine, args.candidates)
            meta.update({"linked": len(linked), "iso": iso})
            return ex.instance_id, sql, meta
        except Exception as e:  # noqa: BLE001
            err = f"{type(e).__name__}: {e}"[:300]
            print(f"  ERR {ex.instance_id}: {err}", flush=True)
            return ex.instance_id, "SELECT 1", {"error": err}

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(work, e): e for e in exs}
        for f in as_completed(futs):
            iid, sql, meta = f.result()
            pred[iid] = sql
            recs[iid] = meta
            done += 1
            checkpoint()
            if done % 5 == 0 or done == len(exs):
                print(f"  [{done}/{len(exs)}] {iid} linked={meta.get('linked','?')} "
                      f"({time.time()-t0:.0f}s)", flush=True)

    work_dir = Path("outputs") / "eval_work" / f"autolink_cloud_{args.tag}"
    result_dir = work_dir / "sql_submit"
    result_dir.mkdir(parents=True, exist_ok=True)
    for iid, sql in pred.items():
        (result_dir / f"{iid}.sql").write_text(sql)
    json.dump({"pred": pred, "meta": recs}, open(out_json, "w"),
              ensure_ascii=False, indent=2)
    print(f"[autolink-cloud-{args.tag}] preds={len(pred)} wrote {out_json}")

    from run_spider2lite_online import evaluate_official
    run_id = f"autolink_cloud_{args.tag}_{int(time.time())}"
    print(f"[autolink-cloud-{args.tag}] running official evaluator ...")
    res = evaluate_official(run_id, result_dir)
    print(f"[autolink-cloud-{args.tag}] EX={res.get('ex')} "
          f"correct={res.get('correct')} scored={res.get('scored')}")
    payload = json.load(open(out_json))
    payload["official_eval"] = res
    json.dump(payload, open(out_json, "w"), ensure_ascii=False, indent=2)

    close_cloud()
    print(f"[autolink-cloud-{args.tag}] done in {time.time()-t0:.0f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
