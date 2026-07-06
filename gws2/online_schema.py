"""Online (BigQuery/Snowflake) schema compression via a confidence-weighted
table ranking -- the cloud-backend counterpart of the local confidence graph.

Spider2-Lite cloud databases routinely span 140+ tables per dataset (ReFoRCE's
"1000+ columns" long-context problem). The first online adapter simply took the
first ~20 tables and truncated the DDL, which drops the relevant tables on large
schemas. This module instead ranks every table by a *white-box* confidence score
against the question + external knowledge, keeps the Top-N, and emits a compact
context. No LLM call is used, so this stays inside the cost-bounded design.

    conf(table) = w_name * name_hit
                + w_col  * column_hit
                + w_desc * description_hit
                + w_ek   * external_knowledge_hit

Each factor is a token-overlap ratio in [0, 1]; the blend is deliberately simple
and inspectable (every table carries its score + matched tokens in the trace).
"""
from __future__ import annotations

import csv
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

csv.field_size_limit(min(sys.maxsize, 2**31 - 1))

# Table-ranking weights. Column and name hits dominate; description/external
# knowledge are softer signals (they help but also add noise on public data).
W_NAME = 3.0
W_COLUMN = 2.0
W_DESC = 1.0
W_EK = 1.5

_STOP = {
    "the", "a", "an", "of", "in", "on", "for", "to", "and", "or", "with", "by",
    "what", "which", "who", "how", "many", "list", "show", "find", "all", "each",
    "is", "are", "was", "were", "give", "me", "number", "count", "name", "names",
    "get", "return", "total", "per", "from", "that", "this", "these", "those",
    "as", "at", "be", "have", "has", "do", "does", "not", "no", "than", "then",
    "top", "most", "least", "highest", "lowest", "average", "avg", "sum", "max",
    "min", "between", "over", "into", "using", "value", "values", "table", "column",
}

_TOKEN = re.compile(r"[A-Za-z][A-Za-z0-9]+")


def _tokens(text: str) -> set[str]:
    out: set[str] = set()
    for raw in _TOKEN.findall(text or ""):
        low = raw.lower()
        if low in _STOP or len(low) < 3:
            continue
        out.add(low)
        # split snake_case / concatenated identifiers into sub-tokens too
        for part in re.split(r"[_\d]+", low):
            if len(part) >= 3 and part not in _STOP:
                out.add(part)
    return out


@dataclass
class OnlineTable:
    table_name: str
    ddl: str
    description: str = ""
    dataset: str = ""            # dataset / schema the table lives in
    score: float = 0.0
    matched: list[str] = field(default_factory=list)

    def _column_tokens(self) -> set[str]:
        # column identifiers appear as leading words on DDL body lines
        body = self.ddl
        cols = re.findall(r'^\s*"?([A-Za-z][A-Za-z0-9_]+)"?\s', body, flags=re.M)
        toks: set[str] = set()
        for c in cols:
            toks |= _tokens(c)
        return toks


@dataclass
class OnlineSchema:
    backend: str                 # "bigquery" | "snowflake"
    db_id: str
    tables: list[OnlineTable] = field(default_factory=list)

    @property
    def n_tables(self) -> int:
        return len(self.tables)


def _find_case_insensitive(root: Path, name: str) -> Path | None:
    if not root.exists():
        return None
    target = name.lower()
    for child in root.iterdir():
        if child.is_dir() and child.name.lower() == target:
            return child
    return None


def _read_ddl_rows(path: Path, dataset: str) -> list[OnlineTable]:
    out: list[OnlineTable] = []
    if not path.exists():
        return out
    with open(path, newline="", errors="ignore") as f:
        for row in csv.DictReader(f):
            ddl = row.get("ddl") or row.get("DDL") or ""
            if not ddl.strip():
                continue
            out.append(OnlineTable(
                table_name=(row.get("table_name") or "").strip(),
                ddl=ddl,
                description=(row.get("description") or "").strip(),
                dataset=dataset,
            ))
    return out


def load_online_schema(backend: str, db_id: str, db_root: Path) -> OnlineSchema:
    """Load every table across all DDL.csv files under a cloud db directory."""
    root = _find_case_insensitive(db_root / backend, db_id)
    tables: list[OnlineTable] = []
    if root is not None:
        for ddl_csv in sorted(root.glob("*/DDL.csv")):
            tables.extend(_read_ddl_rows(ddl_csv, dataset=ddl_csv.parent.name))
    return OnlineSchema(backend=backend, db_id=db_id, tables=tables)


def rank_tables(schema: OnlineSchema, question: str,
                external_knowledge: str = "") -> list[OnlineTable]:
    """Score every table by white-box token-overlap confidence, high to low."""
    q_tok = _tokens(question)
    ek_tok = _tokens(external_knowledge)
    if not q_tok and not ek_tok:
        return list(schema.tables)

    def ratio(hit: set[str], ref: set[str]) -> float:
        return len(hit & ref) / len(ref) if ref else 0.0

    for t in schema.tables:
        name_tok = _tokens(t.table_name)
        desc_tok = _tokens(t.description)
        col_tok = t._column_tokens()
        name_hit = ratio(name_tok, q_tok) + 0.5 * ratio(name_tok, ek_tok)
        col_hit = ratio(col_tok, q_tok) + 0.5 * ratio(col_tok, ek_tok)
        desc_hit = ratio(desc_tok, q_tok)
        ek_hit = ratio(name_tok | col_tok, ek_tok)
        t.score = (W_NAME * name_hit + W_COLUMN * col_hit
                   + W_DESC * desc_hit + W_EK * ek_hit)
        matched = sorted((name_tok | col_tok) & (q_tok | ek_tok))
        t.matched = matched[:12]
    return sorted(schema.tables, key=lambda x: x.score, reverse=True)


def _compact_ddl(ddl: str, max_chars: int) -> str:
    ddl = re.sub(r"\n\s*\n+", "\n", ddl.strip())
    return ddl[:max_chars]


def build_compressed_context(schema: OnlineSchema, question: str,
                             external_knowledge: str = "",
                             top_n: int = 8, max_chars: int = 28000,
                             per_table_chars: int = 4000) -> tuple[str, list[OnlineTable]]:
    """Return (context_text, selected_tables). Falls back to first tables when
    ranking yields nothing (e.g. empty question tokens)."""
    ranked = rank_tables(schema, question, external_knowledge)
    selected = [t for t in ranked if t.score > 0][:top_n]
    if not selected:
        selected = ranked[:top_n]

    hint = ""
    if schema.backend == "bigquery":
        hint = ("Use backticks around fully qualified names. For date-sharded "
                "tables (e.g. events_YYYYMMDD) use wildcard `project.dataset.events_*` "
                "with _TABLE_SUFFIX for date ranges.\n")
    elif schema.backend == "snowflake":
        hint = ("Use fully qualified DATABASE.SCHEMA.TABLE names. If columns are "
                "shown in double quotes, use the exact quoted (case-sensitive) "
                "identifiers. Use LATERAL FLATTEN for VARIANT arrays/objects.\n")

    header = (f"Backend: {schema.backend} | database: {schema.db_id} | "
              f"{schema.n_tables} tables total, showing top {len(selected)} by "
              f"relevance.\n{hint}")
    chunks = [header]
    total = len(header)
    for t in selected:
        chunk = f"\n-- dataset: {t.dataset} | table: {t.table_name}"
        if t.matched:
            chunk += f" | matched: {', '.join(t.matched)}"
        chunk += "\n" + _compact_ddl(t.ddl, per_table_chars)
        if total + len(chunk) > max_chars:
            break
        chunks.append(chunk)
        total += len(chunk)
    return "\n".join(chunks), selected
