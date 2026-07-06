"""Spider2-Lite mixed-backend runner.

This runner is the first online adaptation layer for Spider2-Lite.  The existing
GraphWalker-SQL pipeline is SQLite-native; this script keeps the proven SQLite
path for local examples and adds a conservative BigQuery/Snowflake SQL generator
for online examples using Spider2 resource DDLs and official evaluator format.

Design constraints:
  * credentials are copied only into a temporary eval workdir and removed after
    evaluation;
  * BigQuery/Snowflake remote column probes are not enabled yet, so the online
    path is a dialect-aware generation adapter rather than the full belief-walk
    backend;
  * generated SQL files are laid out exactly as Spider2-Lite evaluate.py expects.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path

from gws2 import config
from gws2.cloud_consensus import Candidate, is_low_confidence, result_signature, vote
from gws2.cloud_execute import close_cloud, run_cloud
from gws2.cloud_probe import probe_tables
from gws2.datasets import Example, load_spider2_lite_local
from gws2.llm import LLM
from gws2.online_schema import build_compressed_context, load_online_schema
from gws2.pipeline import AblationConfig, load_db, run_pipeline
from gws2.prompts import (PROMPT_SNOWFLAKE_DIALECT, PROMPT_SPIDER2_ONLINE_REPAIR,
                          PROMPT_SPIDER2_ONLINE_SQL)


SPIDER2_ROOT = Path(config.SPIDER2_ROOT)
RESOURCE = SPIDER2_ROOT / "resource"
DOC_DIR = RESOURCE / "documents"
DB_DIR = RESOURCE / "databases"
VALID_PREFIXES = ("local", "bq", "ga", "sf")


@dataclass
class Spider2OnlineExample:
    idx: int
    instance_id: str
    db_id: str
    question: str
    external_knowledge: str
    backend: str
    sqlite_path: str = ""


def _backend_for_id(iid: str) -> str:
    if iid.startswith("local"):
        return "local"
    if iid.startswith("bq"):
        return "bigquery"
    if iid.startswith("ga"):
        return "bigquery"
    if iid.startswith("sf"):
        return "snowflake"
    return "unknown"


def load_spider2_lite_mixed(prefixes: set[str] | None = None,
                            limit_per_backend: int | None = None) -> list[Spider2OnlineExample]:
    """Load Spider2-Lite examples across local, BigQuery/GA, and Snowflake."""
    raw = [json.loads(line) for line in open(config.SPIDER2_JSONL)]
    local_by_id = {e.instance_id: e for e in load_spider2_lite_local()}
    counts: dict[str, int] = {}
    out: list[Spider2OnlineExample] = []
    for i, item in enumerate(raw):
        iid = item["instance_id"]
        prefix = next((p for p in VALID_PREFIXES if iid.startswith(p)), "other")
        if prefixes and prefix not in prefixes:
            continue
        backend = _backend_for_id(iid)
        if backend == "unknown":
            continue
        if limit_per_backend is not None:
            if counts.get(prefix, 0) >= limit_per_backend:
                continue
            counts[prefix] = counts.get(prefix, 0) + 1
        local = local_by_id.get(iid)
        out.append(Spider2OnlineExample(
            idx=i,
            instance_id=iid,
            db_id=item.get("db", ""),
            question=item.get("question", ""),
            external_knowledge=item.get("external_knowledge") or "",
            backend=backend,
            sqlite_path=local.sqlite_path if local else "",
        ))
    return out


def _find_case_insensitive(root: Path, name: str) -> Path | None:
    if not root.exists():
        return None
    target = name.lower()
    for child in root.iterdir():
        if child.is_dir() and child.name.lower() == target:
            return child
    return None


def _read_external_doc(name: str, max_chars: int = 8000) -> str:
    if not name:
        return "(none)"
    path = DOC_DIR / name
    if not path.exists():
        return f"(document {name} not found)"
    text = path.read_text(errors="ignore")
    return text[:max_chars]


def _compact_ddl(ddl: str, max_chars: int = 5000) -> str:
    ddl = re.sub(r"\n\s*\n+", "\n", ddl.strip())
    return ddl[:max_chars]


def _read_ddl_csv(path: Path, max_tables: int = 20, max_chars: int = 24000) -> str:
    if not path.exists():
        return f"(DDL.csv not found: {path})"
    chunks: list[str] = []
    total = 0
    with open(path, newline="", errors="ignore") as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            if i >= max_tables:
                break
            ddl = row.get("ddl") or row.get("DDL") or ""
            table = row.get("table_name", "")
            desc = row.get("description", "")
            chunk = f"-- table: {table}\n"
            if desc:
                chunk += f"-- description: {desc}\n"
            chunk += _compact_ddl(ddl)
            chunks.append(chunk)
            total += len(chunk)
            if total >= max_chars:
                break
    return "\n\n".join(chunks)[:max_chars]


def _bigquery_schema_context(db_id: str, max_chars: int = 28000) -> str:
    db_root = _find_case_insensitive(DB_DIR / "bigquery", db_id)
    if db_root is None:
        return f"(BigQuery schema directory not found for {db_id})"
    ddl_files = sorted(db_root.glob("*/DDL.csv"))
    chunks = []
    for ddl in ddl_files[:3]:
        dataset = ddl.parent.name
        note = f"Dataset: {dataset}\n"
        if dataset.endswith("ga4_obfuscated_sample_ecommerce"):
            note += ("Note: this dataset contains date-sharded GA4 tables. "
                     "Use wildcard table `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` "
                     "with _TABLE_SUFFIX for date ranges when appropriate.\n")
        chunks.append(note + _read_ddl_csv(ddl, max_tables=12, max_chars=max_chars // 3))
    return "\n\n".join(chunks)[:max_chars] if chunks else f"(No DDL.csv under {db_root})"


def _snowflake_schema_context(db_id: str, max_chars: int = 28000) -> str:
    db_root = _find_case_insensitive(DB_DIR / "snowflake", db_id)
    if db_root is None:
        return f"(Snowflake schema directory not found for {db_id})"
    chunks = []
    for ddl in sorted(db_root.glob("*/DDL.csv"))[:4]:
        schema_name = ddl.parent.name
        note = (f"Database: {db_root.name}\nSchema: {schema_name}\n"
                f"Use fully qualified table names as {db_root.name}.{schema_name}.<TABLE>.\n"
                "Important Snowflake identifier rule: if columns are shown in double quotes, "
                "use the exact quoted column names in SQL, including lowercase spelling.\n")
        chunks.append(note + _read_ddl_csv(ddl, max_tables=16, max_chars=max_chars // 3))
    return "\n\n".join(chunks)[:max_chars] if chunks else f"(No DDL.csv under {db_root})"


def schema_context_for(ex: Spider2OnlineExample) -> tuple[str, str, list[str], list]:
    """Return (dialect, schema_context, selected_table_trace, selected_tables).

    P0: cloud schemas are compressed via a white-box confidence table ranking
    (gws2.online_schema) instead of blind head-truncation, so relevant tables on
    large (140+ table) schemas survive into the prompt. Falls back to the legacy
    truncated context if ranking finds no tables at all. ``selected_tables`` are
    the OnlineTable objects (for P2 remote probing).
    """
    if ex.backend == "bigquery":
        dialect = "BigQuery"
    elif ex.backend == "snowflake":
        dialect = "Snowflake"
    else:
        return "SQLite", "(local SQLite schema handled by GraphWalker pipeline)", [], []

    schema = load_online_schema(ex.backend, ex.db_id, DB_DIR)
    if schema.n_tables == 0:
        legacy = (_bigquery_schema_context(ex.db_id) if ex.backend == "bigquery"
                  else _snowflake_schema_context(ex.db_id))
        return dialect, legacy, [], []
    context, selected = build_compressed_context(
        schema, ex.question, ex.external_knowledge or "", top_n=8)
    trace = [f"{t.table_name.strip()}({t.score:.2f})" for t in selected]
    return dialect, context, trace, selected


def generate_online_sql(ex: Spider2OnlineExample, llm: LLM,
                        use_repair: bool = True,
                        use_probe: bool = True,
                        use_consensus: bool = False,
                        max_repairs: int = config.CLOUD_MAX_REPAIRS) -> tuple[str, dict]:
    """Generate one cloud SQL with P2 remote probes + P1 bounded repair + P3
    belief-gated selective consensus.

    P2: before generation, run a bounded, cost-guarded remote column/value walk
    on the top compressed tables and inject the evidence as grounding hints.
    P1: after generation, execute (cost-guarded) and apply at most ``max_repairs``
    targeted repairs on error/empty/cost-refusal, kept only if non-regressing.
    P3: if the answer is low-confidence (needed repair / few rows / no probe
    evidence), generate a few extra candidates and majority-vote on results;
    high-confidence answers stay single-shot to preserve the cost budget.
    """
    dialect, schema_context, table_trace, selected = schema_context_for(ex)
    external = _read_external_doc(ex.external_knowledge)

    meta = {
        "backend": ex.backend,
        "dialect": dialect,
        "schema_context_chars": len(schema_context),
        "selected_tables": table_trace,
        "repairs": 0,
        "probe_sql": 0,
        "probe_hints": [],
        "probe_trace": [],
        "exec_trace": [],
        "est_gb": None,
    }

    # --- P2: remote belief probes -> grounding hints ------------------------ #
    probe_hints: list[str] = []
    if use_probe and selected:
        probe_hints, probe_trace = probe_tables(
            ex.backend, ex.db_id, selected, ex.question, ex.external_knowledge or "")
        meta["probe_hints"] = probe_hints
        meta["probe_trace"] = probe_trace
        meta["probe_sql"] = sum(1 for t in probe_trace if t.startswith("probe ")
                                or "literal-" in t)

    hints_block = ("\n".join(probe_hints) if probe_hints
                   else "(no remote probe evidence)")
    dialect_block = ("\n\n" + PROMPT_SNOWFLAKE_DIALECT
                     if ex.backend == "snowflake" else "")
    system = PROMPT_SPIDER2_ONLINE_SQL.format(
        dialect=dialect,
        schema_context=schema_context + "\n\nRemote probe evidence (sampled live "
        "from the database; prefer these real columns/values):\n" + hints_block
        + dialect_block,
        external_knowledge=external,
        question=ex.question,
    )
    resp = llm.complete(system, "Generate the SQL.", temperature=0.0)
    sql = _extract_sql(resp)

    if not use_repair:
        return sql, meta

    res = run_cloud(ex.backend, sql, database=ex.db_id)
    meta["est_gb"] = res.est_gb
    meta["exec_trace"].append(_exec_summary("generate", res))

    for attempt in range(max_repairs):
        need = (not res.ok) or res.n_shown == 0
        if not need:
            break
        problem = _problem_label(res)
        feedback = res.error or "the query executed but returned an empty result"
        # dialect-aware repair hint: map the Snowflake error to a concrete rewrite
        feedback = feedback[:1500] + _snowflake_repair_hint(ex.backend, feedback)
        sc = schema_context + (("\n\n" + PROMPT_SNOWFLAKE_DIALECT)
                               if ex.backend == "snowflake" else "")
        repair_sys = PROMPT_SPIDER2_ONLINE_REPAIR.format(
            dialect=dialect, problem=problem, schema_context=sc,
            external_knowledge=external, question=ex.question, sql=sql,
            feedback=feedback,
        )
        rsql = _extract_sql(llm.complete(repair_sys, "Repair the query.",
                                         temperature=0.0))
        if not rsql or rsql.strip() == sql.strip():
            meta["exec_trace"].append(f"repair{attempt+1}: no-change, stop")
            break
        rres = run_cloud(ex.backend, rsql, database=ex.db_id)
        meta["exec_trace"].append(_exec_summary(f"repair{attempt+1}", rres))
        meta["repairs"] += 1
        # keep repair only if it did not regress
        if rres.ok and (not res.ok or rres.n_shown > 0):
            sql, res = rsql, rres
            if res.est_gb is not None:
                meta["est_gb"] = res.est_gb
        else:
            meta["exec_trace"].append(f"repair{attempt+1}: discarded (no improvement)")
            break

    # --- P3: belief-gated selective consensus ------------------------------- #
    meta["consensus"] = "off"
    if use_consensus:
        low_conf, reason = is_low_confidence(
            repairs=meta["repairs"], final_rows=res.n_shown, final_ok=res.ok,
            n_probe_hints=len(probe_hints), min_rows=config.CLOUD_CONSENSUS_MIN_ROWS)
        if not low_conf:
            meta["consensus"] = f"skipped ({reason})"
        else:
            primary = Candidate(sql=sql, ok=res.ok, n_rows=res.n_shown,
                                signature=result_signature(res.rows, res.columns),
                                est_gb=res.est_gb)
            cands = [primary]
            for k in range(config.CLOUD_CONSENSUS_CANDIDATES):
                cresp = llm.complete(system, "Generate the SQL.",
                                     temperature=config.CLOUD_CONSENSUS_TEMPERATURE)
                csql = _extract_sql(cresp)
                if not csql or csql.strip() == sql.strip():
                    continue
                cres = run_cloud(ex.backend, csql, database=ex.db_id)
                meta["exec_trace"].append(_exec_summary(f"consensus{k+1}", cres))
                cands.append(Candidate(sql=csql, ok=cres.ok, n_rows=cres.n_shown,
                                       signature=result_signature(cres.rows, cres.columns),
                                       est_gb=cres.est_gb))
            winner, info = vote(cands)
            meta["consensus"] = f"triggered ({reason}) -> {info.get('decision')}"
            meta["consensus_info"] = info
            # adopt the winner only if it out-votes the primary's own group
            if winner is not None and winner.sql.strip() != sql.strip():
                primary_votes = sum(1 for c in cands
                                    if c.ok and c.n_rows > 0
                                    and c.signature == primary.signature)
                if info.get("winner_votes", 0) > primary_votes:
                    sql = winner.sql
                    res_ok, res_rows = winner.ok, winner.n_rows
                    meta["exec_trace"].append(
                        f"consensus adopted winner (votes={info.get('winner_votes')})")
                    meta["final_exec_ok"] = res_ok
                    meta["final_rows"] = res_rows
                    return sql, meta

    meta["final_exec_ok"] = res.ok
    meta["final_rows"] = res.n_shown
    return sql, meta


def _snowflake_repair_hint(backend: str, error: str) -> str:
    """Map a Snowflake compile error to a concrete rewrite instruction."""
    if backend != "snowflake" or not error:
        return ""
    e = error.lower()
    if "unsupported subquery" in e:
        return ("\nHINT: Snowflake cannot evaluate this correlated subquery. "
                "Move the FLATTEN/aggregation into a CTE grouped by the join key, "
                "then JOIN that CTE back to the main table.")
    if "lateral" in e and ("outer join" in e or "unsupported feature" in e):
        return ("\nHINT: do not use CROSS JOIN LATERAL FLATTEN with an OUTER JOIN. "
                "Use a comma lateral `, LATERAL FLATTEN(input => x) f`, or "
                "`LATERAL FLATTEN(input => x, OUTER => TRUE)`.")
    if "can't parse" in e or "as date" in e:
        return ("\nHINT: an integer date has a 0/NULL sentinel. Use "
                "`TO_DATE(TO_VARCHAR(NULLIF(col, 0)), 'YYYYMMDD')` and filter "
                "col > 0 before any date math.")
    if "unknown function" in e or "does not exist" in e and "function" in e:
        return ("\nHINT: use a Snowflake-native function (DATEADD, DATE_TRUNC, "
                "ARRAY_SIZE, LISTAGG, IFF, TO_DATE/TO_VARCHAR); avoid BigQuery-only "
                "names like SAFE_CAST/PARSE_DATE/GENERATE_DATE_ARRAY.")
    if "invalid identifier" in e:
        return ("\nHINT: use the exact 3-part DATABASE.SCHEMA.TABLE name given, and "
                "keep double-quoted case-sensitive column names as shown.")
    return ""


def _problem_label(res) -> str:
    if getattr(res, "skipped_cost", False):
        return "was refused by the cost guard (scans too much data)"
    if not res.ok:
        return "failed to execute"
    if res.n_shown == 0:
        return "executed but returned an empty result"
    return "needs adjustment"


def _exec_summary(stage: str, res) -> str:
    if res.ok:
        gb = f" est_gb={res.est_gb:.3f}" if res.est_gb is not None else ""
        return f"{stage}: ok rows={res.n_shown}{gb}"
    tag = "cost-refused" if getattr(res, "skipped_cost", False) else "error"
    return f"{stage}: {tag} {res.error[:80]}"


_SQL_BLOCK = re.compile(r"```sql\s*(.*?)```", re.DOTALL | re.IGNORECASE)
_ANY_BLOCK = re.compile(r"```\s*(.*?)```", re.DOTALL)


def _extract_sql(text: str) -> str:
    m = _SQL_BLOCK.search(text) or _ANY_BLOCK.search(text)
    sql = (m.group(1) if m else text).strip()
    sql = re.sub(r"^```(?:sql)?\s*", "", sql, flags=re.I).strip()
    sql = re.sub(r"\s*```$", "", sql).strip()
    return sql.rstrip(";").strip()


def run_local_graphwalker(ex: Spider2OnlineExample, llm: LLM, schema_cache: dict,
                          cache_lock: threading.Lock) -> tuple[str, dict]:
    with cache_lock:
        schema = schema_cache.get(ex.sqlite_path)
    if schema is None:
        schema = load_db(ex.sqlite_path, with_stats=True)
        with cache_lock:
            schema_cache[ex.sqlite_path] = schema
    ab = AblationConfig()
    res = run_pipeline(
        schema, ex.sqlite_path, ex.question, llm,
        evidence=ex.external_knowledge, ablation=ab, dialect="SQLite",
        prefer_declared=True, with_snapshot=False,
    )
    return res.sql, {
        "backend": "local",
        "graph_method": res.graph_method,
        "linked_tables": res.linked_tables,
        "query_skeleton": res.query_skeleton,
        "exec_ok": res.execution.get("ok"),
    }


def _prepare_eval_work(run_id: str, result_dir: Path) -> Path:
    work = Path("outputs") / "eval_work" / run_id / "evaluation_suite"
    if work.exists():
        shutil.rmtree(work.parent)
    work.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SPIDER2_ROOT / "evaluation_suite" / "evaluate.py", work / "evaluate.py")
    os.symlink(SPIDER2_ROOT / "evaluation_suite" / "gold", work / "gold")
    shutil.copy2(SPIDER2_ROOT / "spider2-lite.jsonl", work.parent / "spider2-lite.jsonl")
    # evaluate.py refers to ../resource/databases/spider2-localdb for local
    # examples, so the temporary workdir must mirror that relative layout.
    os.symlink(SPIDER2_ROOT / "resource", work.parent / "resource")
    bq_cred = Path("/Users/bytedance/Desktop/研二下/spider2凭证文件/bigquery_credential.json")
    sf_cred = Path("/Users/bytedance/Desktop/研二下/spider2凭证文件/snowflake_credential.json")
    if bq_cred.exists():
        shutil.copy2(bq_cred, work / "bigquery_credential.json")
    if sf_cred.exists():
        shutil.copy2(sf_cred, work / "snowflake_credential.json")
    return work


def _cleanup_eval_credentials(work: Path) -> None:
    for name in ("bigquery_credential.json", "snowflake_credential.json"):
        path = work / name
        if path.exists():
            path.unlink()


def evaluate_official(run_id: str, result_dir: Path) -> dict:
    work = _prepare_eval_work(run_id, result_dir)
    try:
        cmd = [
            sys.executable, "evaluate.py", "--mode", "sql",
            "--result_dir", str(result_dir.resolve()), "--gold_dir", "gold",
        ]
        proc = subprocess.run(cmd, cwd=work, capture_output=True, text=True)
        out = proc.stdout + "\n" + proc.stderr
    finally:
        _cleanup_eval_credentials(work)
    m = re.search(r"Final score:\s*([\d.]+),\s*Correct examples:\s*(\d+),\s*Total examples:\s*(\d+)", out)
    res = {"raw_tail": out[-2000:]}
    if m:
        res.update(ex=float(m.group(1)) * 100,
                   correct=int(m.group(2)), scored=int(m.group(3)))
    else:
        res["ex"] = None
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description="Run Spider2-Lite mixed online adapter")
    ap.add_argument("--prefix", action="append", choices=list(VALID_PREFIXES),
                    help="prefix to include; can repeat. default: all")
    ap.add_argument("--limit-per-backend", type=int, default=None)
    ap.add_argument("--full", action="store_true", help="run all selected examples")
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--tag", default="online")
    ap.add_argument("--model", default=config.DEFAULT_MODEL)
    ap.add_argument("--no-eval", action="store_true")
    ap.add_argument("--no-repair", action="store_true",
                    help="disable the P1 cloud bounded belief-repair loop (ablation)")
    ap.add_argument("--no-probe", action="store_true",
                    help="disable the P2 remote belief probes (ablation)")
    ap.add_argument("--consensus", action="store_true",
                    help="enable P3 belief-gated selective consensus (extra cloud cost)")
    args = ap.parse_args()

    prefixes = set(args.prefix or VALID_PREFIXES)
    limit = None if args.full else args.limit_per_backend
    examples = load_spider2_lite_mixed(prefixes=prefixes, limit_per_backend=limit)
    if not examples:
        raise SystemExit("No examples selected.")

    run_id = f"spider2-lite_{args.tag}_{args.model}_seed{config.DEFAULT_SEED}"
    out_dir = Path("outputs")
    result_dir = out_dir / "eval_work" / run_id / "sql_submit"
    result_dir.mkdir(parents=True, exist_ok=True)
    print(f"[{run_id}] {len(examples)} examples | prefixes={sorted(prefixes)} workers={args.workers}")

    llm = LLM(model=args.model, seed=config.DEFAULT_SEED)
    schema_cache: dict = {}
    cache_lock = threading.Lock()
    records_by_id: dict[str, dict] = {}
    t0 = time.time()

    def work(ex: Spider2OnlineExample):
        try:
            if ex.backend == "local":
                sql, meta = run_local_graphwalker(ex, llm, schema_cache, cache_lock)
            else:
                sql, meta = generate_online_sql(
                    ex, llm, use_repair=not args.no_repair,
                    use_probe=not args.no_probe,
                    use_consensus=args.consensus)
            (result_dir / f"{ex.instance_id}.sql").write_text(sql)
            return ex.instance_id, {
                "instance_id": ex.instance_id,
                "db_id": ex.db_id,
                "backend": ex.backend,
                "question": ex.question,
                "external_knowledge": ex.external_knowledge,
                "pred_sql": sql,
                **meta,
            }
        except Exception as exc:  # noqa: BLE001
            sql = "SELECT 1"
            (result_dir / f"{ex.instance_id}.sql").write_text(sql)
            return ex.instance_id, {
                "instance_id": ex.instance_id,
                "db_id": ex.db_id,
                "backend": ex.backend,
                "question": ex.question,
                "error": str(exc),
                "pred_sql": sql,
            }

    done = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(work, ex): ex for ex in examples}
        for fut in as_completed(futures):
            iid, rec = fut.result()
            records_by_id[iid] = rec
            done += 1
            if done % 10 == 0 or done == len(examples):
                print(f"  [{done}/{len(examples)}] latest={iid} ({time.time() - t0:.0f}s)")

    records = [records_by_id[ex.instance_id] for ex in examples]
    close_cloud()
    n_repairs = sum(r.get("repairs", 0) for r in records)
    n_probes = sum(r.get("probe_sql", 0) for r in records)
    n_consensus = sum(1 for r in records
                      if str(r.get("consensus", "")).startswith("triggered"))
    print(f"[{run_id}] cloud repairs: {n_repairs} | probe SQLs: {n_probes} | "
          f"consensus triggered: {n_consensus}")
    eval_result = {}
    if not args.no_eval:
        print(f"[{run_id}] running official Spider2-Lite evaluator ...")
        eval_result = evaluate_official(run_id, result_dir)
        print(f"[{run_id}] EX={eval_result.get('ex')} correct={eval_result.get('correct')} scored={eval_result.get('scored')}")

    payload = {
        "run_id": run_id,
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "args": vars(args),
        "n_questions": len(examples),
        "prefixes": sorted(prefixes),
        "llm_stats": llm.stats(),
        "official_eval": eval_result,
        "records": records,
        "elapsed_sec": round(time.time() - t0, 1),
    }
    out_path = out_dir / f"{run_id}.json"
    json.dump(payload, open(out_path, "w"), ensure_ascii=False, indent=2)
    print(f"[{run_id}] wrote {out_path}")
    print(f"[{run_id}] LLM: {llm.stats()} | {time.time() - t0:.1f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
