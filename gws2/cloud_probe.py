"""Remote belief probes for cloud backends (P2: cloud column/value walk).

The local Explore phase actively probes candidate columns with cheap SQL to
resolve column/value ambiguity (the "same concept across many columns" failure
mode). This module is the cloud counterpart: given the Top-N tables chosen by
the P0 confidence compression, it probes a bounded set of question-relevant
columns on BigQuery / Snowflake and returns grounding hints that are injected
into SQL generation.

Cost discipline (probes cost real money on the cloud):
  * only the top ``CLOUD_PROBE_MAX_TABLES`` tables are probed;
  * only ``CLOUD_PROBE_MAX_COLUMNS`` question/EK-overlapping columns per run;
  * a hard cap ``CLOUD_PROBE_MAX_SQL`` on total probe queries;
  * every probe is LIMIT-capped and, on BigQuery, dry-run-gated to
    ``CLOUD_PROBE_MAX_GB`` before it is allowed to execute.
"""
from __future__ import annotations

import re

from . import config
from .cloud_execute import run_bigquery, run_snowflake
from .online_schema import OnlineTable, _tokens


def _probe_run(backend: str, sql: str, database: str | None):
    """Execute a probe with the P2 (smaller) cost cap, per backend."""
    if backend == "bigquery":
        return run_bigquery(sql, max_rows=config.CLOUD_PROBE_SAMPLE_VALUES,
                            max_gb=config.CLOUD_PROBE_MAX_GB)
    return run_snowflake(sql, database=database,
                         max_rows=config.CLOUD_PROBE_SAMPLE_VALUES)


def _quote_col(backend: str, name: str) -> str:
    if backend == "bigquery":
        return f"`{name}`"
    return '"' + name.replace('"', '""') + '"'


def _is_text_type(typ: str) -> bool:
    t = (typ or "").upper()
    return any(k in t for k in ("CHAR", "TEXT", "STRING", "VARCHAR", "VARIANT"))


def _stem(tokens: set[str]) -> set[str]:
    """Add crude singular/plural variants so 'inventors' matches 'inventor'."""
    out = set(tokens)
    for t in tokens:
        if len(t) > 3 and t.endswith("s"):
            out.add(t[:-1])
        else:
            out.add(t + "s")
    return out


def _pick_columns(table: OnlineTable, q_tokens: set[str],
                  ek_tokens: set[str]) -> list[tuple[str, str]]:
    """Rank columns by token overlap with question/external knowledge.

    Falls back to the first few columns of a high-relevance table when nothing
    overlaps (plural/synonym gaps), so the generator still sees real column
    names + sample values for the table it most likely needs.
    """
    q_stem = _stem(q_tokens)
    ek_stem = _stem(ek_tokens)
    scored: list[tuple[float, str, str]] = []
    all_cols = table.columns()
    for name, typ in all_cols:
        ctoks = _stem(_tokens(name))
        if not ctoks:
            continue
        hit = len(ctoks & q_stem) + 0.5 * len(ctoks & ek_stem)
        if hit > 0:
            scored.append((hit, name, typ))
    scored.sort(key=lambda x: x[0], reverse=True)
    picked = [(n, t) for _s, n, t in scored[:config.CLOUD_PROBE_MAX_COLUMNS]]
    if not picked and all_cols:
        # no lexical overlap: probe the first handful so the LLM sees this
        # (highly ranked) table's real columns and value shapes.
        picked = all_cols[:min(config.CLOUD_PROBE_MAX_COLUMNS, 5)]
    return picked


def _extract_literals(question: str, external_knowledge: str) -> list[str]:
    """Quoted phrases and Capitalized product-like names worth a value check."""
    text = f"{question}\n{external_knowledge}"
    lits: list[str] = []
    lits += re.findall(r"'([^']{2,40})'", text)
    lits += re.findall(r'"([^"]{2,40})"', text)
    # de-dup, drop pure numbers
    seen, out = set(), []
    for l in lits:
        l = l.strip()
        if l and not l.isdigit() and l.lower() not in seen:
            seen.add(l.lower())
            out.append(l)
    return out[:3]


def probe_tables(backend: str, database: str | None, tables: list[OnlineTable],
                 question: str, external_knowledge: str = "") -> tuple[list[str], list[str]]:
    """Return (hints, trace). Bounded, cost-guarded remote column/value walk."""
    q_tokens = _tokens(question)
    ek_tokens = _tokens(external_knowledge)
    q_stem = _stem(q_tokens)
    ek_stem = _stem(ek_tokens)
    literals = _extract_literals(question, external_knowledge)
    hints: list[str] = []
    trace: list[str] = []
    n_sql = 0

    for table in tables[:config.CLOUD_PROBE_MAX_TABLES]:
        if n_sql >= config.CLOUD_PROBE_MAX_SQL:
            break
        # Skip date-sharded tables (GA / GA4 style events_YYYYMMDD): probing a
        # single shard is misleading, the schema is wide and nested, and flat
        # column sampling adds noise rather than signal (regressed bq001).
        if re.search(r"_(?:19|20)\d{6}$", table.table_name.strip()):
            trace.append(f"skip sharded table {table.table_name.strip()}")
            continue
        fqn = table.fqn()
        cols = _pick_columns(table, q_tokens, ek_tokens)
        if not cols:
            continue
        # Columns whose NAME lexically overlaps the question are genuine
        # disambiguation targets; generic fallback columns are not emitted as
        # sample hints (they distracted the generator).
        overlap_cols = {c for c, _t in cols
                        if _stem(_tokens(c)) & (q_stem | ek_stem)}
        col_list = ", ".join(_quote_col(backend, c) for c, _t in cols)
        # one combined sample query for all picked columns (1 probe, not N)
        sample_sql = f"SELECT {col_list} FROM {fqn} LIMIT {config.CLOUD_PROBE_SAMPLE_VALUES}"
        res = _probe_run(backend, sample_sql, database)
        n_sql += 1
        if res.ok and res.rows:
            col_names = [c for c, _t in cols]
            samples_by_col = {cn: [] for cn in col_names}
            for row in res.rows:
                for cn, val in zip(col_names, row):
                    if len(samples_by_col[cn]) < 3 and val is not None:
                        samples_by_col[cn].append(str(val)[:40])
            for cn, _t in cols:
                if cn not in overlap_cols:
                    continue  # only surface question-relevant columns
                sv = samples_by_col.get(cn) or []
                hints.append(f"- {table.table_name.strip()}.{cn} samples: {sv}")
            trace.append(f"probe {fqn}: {len(cols)} cols ok, "
                         f"{len(overlap_cols)} relevant"
                         + (f" est_gb={res.est_gb:.3f}" if res.est_gb is not None else ""))
        else:
            tag = "cost-refused" if getattr(res, "skipped_cost", False) else "err"
            trace.append(f"probe {fqn}: {tag} {res.error[:60]}")

        # literal-hit checks on text columns (bounded)
        text_cols = [c for c, t in cols if _is_text_type(t)]
        for lit in literals:
            if n_sql >= config.CLOUD_PROBE_MAX_SQL or not text_cols:
                break
            col = text_cols[0]
            qc = _quote_col(backend, col)
            safe = lit.replace("'", "''")
            hit_sql = f"SELECT {qc} FROM {fqn} WHERE {qc} = '{safe}' LIMIT 1"
            hres = _probe_run(backend, hit_sql, database)
            n_sql += 1
            if hres.ok and hres.rows:
                hints.append(f"- value '{lit}' EXISTS in "
                             f"{table.table_name.strip()}.{col} (use this column/value)")
                trace.append(f"literal-hit '{lit}' in {col}")
            elif hres.ok:
                trace.append(f"literal-miss '{lit}' in {col}")

    trace.append(f"cloud probes: {n_sql} SQL, {len(hints)} hints")
    return hints[:16], trace
