"""ReAct schema-linking agent (AutoLink-style).

From a large database the agent iteratively assembles the set of columns needed
to answer a question, WITHOUT seeing the whole schema. Each turn it reasons and
emits tool calls; the environment executes them and feeds back observations:

  @schema_retrieval(query="...")  -> semantic search over the column vector store
                                     for MISSING columns (only these count as linked)
  @sql_execution(query="...")     -> run an exploratory SQL on the real DB
  @stop()                         -> enough schema gathered

This is training-free (prompt only) and backend-agnostic: the caller passes an
``executor(sql) -> (ok, text)`` so the same loop works for SQLite / BigQuery /
Snowflake. It returns the linked column set + a formatted schema string for the
downstream SQL generator, plus a trace.
"""
from __future__ import annotations

import re
from collections import OrderedDict

from .llm import LLM
from .schema_vec import ColumnVectorStore

SYSTEM = """You are a schema-linking agent for {dialect} Text-to-SQL. Your goal is to \
find EVERY table and column needed to answer the user's question, from a large database \
whose full schema you CANNOT see all at once. You discover it over multiple turns using \
tools.

Available tools (write each call on its own, starting with @):
@schema_retrieval(query="a short natural-language description of a column/concept you still need")
  - Semantic search over the database's columns; returns the top matching columns.
  - This is your main tool. INFER the columns the question implies (entities, metrics, \
join keys, filters, dates, names) and retrieve each of them, even if not literally in \
the question (e.g. "league name", "team full name", "student exam score").
  - IMPORTANT: only columns returned by @schema_retrieval are counted as linked. So you \
MUST retrieve every needed column, including id/code join keys and name/date columns.
@sql_execution(query="an exploratory SQL")
  - Run a lightweight SQL on the REAL database to inspect structure or values, e.g. list \
a table's columns, or SELECT ... LIMIT 5 to see sample values. Always use LIMIT 5.
@stop()
  - Call this (alone) once the linked columns are sufficient to answer the question.

Rules:
- Each turn: 1-2 sentences of reasoning, then one or more tool calls. Never assume a \
tool's result; wait for it.
- @stop() must be the only call in its turn.
- Pay special attention to generic-but-critical columns (*_id, *_code, *_name, *_date) \
used for joins/filters/output; retrieve them explicitly.
- You have up to {max_turns} turns."""

USER = """Question: {question}

External knowledge: {external}

All tables in the database:
{tables}

Initial retrieved columns (seed; likely incomplete):
{seed}

Begin. Retrieve every additional column needed, exploring with SQL when unsure."""


_TOOLNAMES = ("schema_retrieval", "sql_execution", "sql_draft", "stop")


def _parse_tools(text: str) -> list[tuple[str, str]]:
    """Return [(tool, arg_string), ...] parsed from the model output.

    Robust to query="...", query='...', triple-quoted, or bare content; extracts
    the argument by balanced-quote / paren scanning so SQL with parens survives.
    """
    calls: list[tuple[str, str]] = []
    i = 0
    n = len(text)
    while i < n:
        m = re.search(r"@(" + "|".join(_TOOLNAMES) + r")\s*\(", text[i:])
        if not m:
            break
        tool = m.group(1)
        start = i + m.end()  # position right after '('
        if tool == "stop":
            calls.append(("stop", ""))
            i = start
            continue
        # find the argument: prefer a quoted string, else read to matching ')'
        rest = text[start:]
        arg = ""
        stripped = rest.lstrip()
        lead = len(rest) - len(stripped)
        consumed = start + lead
        for q in ('"""', "'''", '"', "'"):
            if stripped.startswith(q):
                end = stripped.find(q, len(q))
                if end != -1:
                    arg = stripped[len(q):end]
                    consumed = start + lead + end + len(q)
                    break
        else:
            # no quote: read until the last ')' on the same logical call (greedy to newline+@ or ')')
            depth = 1
            j = start
            while j < n and depth > 0:
                if text[j] == "(":
                    depth += 1
                elif text[j] == ")":
                    depth -= 1
                j += 1
            arg = text[start:j - 1]
            consumed = j
        # strip a leading  query= / sql=
        arg = re.sub(r'^\s*(?:query|sql|q)\s*=\s*', "", arg).strip()
        arg = arg.strip('"\'').strip()
        calls.append((tool, arg))
        i = max(consumed, start)
    return calls


def _fmt_cols(cols: list[dict]) -> str:
    """Group columns by table into a compact readable schema snippet."""
    by_t: "OrderedDict[str, list[dict]]" = OrderedDict()
    for c in cols:
        by_t.setdefault(c["table"], []).append(c)
    out = []
    for t, cs in by_t.items():
        lines = [f"# Table: {t}"]
        for c in cs:
            d = f" -- {c['description']}" if c.get("description") else ""
            ex = f" e.g. {c['value_examples']}" if c.get("value_examples") else ""
            lines.append(f"  ({c['column']}: {c.get('type','')}{ex}){d}")
        out.append("\n".join(lines))
    return "\n".join(out)


def link_schema(question: str, external: str, all_tables: list[str],
                vecstore: ColumnVectorStore, executor, llm: LLM,
                dialect: str = "SQLite", seed_top_n: int = 60,
                retrieve_top_m: int = 4, max_turns: int = 6,
                max_exec: int = 8) -> tuple[list[dict], str, list[str]]:
    """Run the agentic linking loop. Returns (linked_columns, schema_text, trace)."""
    trace: list[str] = []
    used_idx: set[int] = set()
    linked: list[dict] = []

    def _add(cols: list[dict]):
        for c in cols:
            if c["_idx"] not in used_idx:
                used_idx.add(c["_idx"])
                linked.append(c)

    # seed retrieval from the raw question
    _add(vecstore.retrieve(question, top_k=seed_top_n))
    trace.append(f"seed: {len(linked)} cols")

    tbl_str = ", ".join(all_tables) if all_tables else "(unknown)"
    messages = [
        {"role": "system", "content": SYSTEM.format(dialect=dialect, max_turns=max_turns)},
        {"role": "user", "content": USER.format(
            question=question, external=(external or "(none)")[:2000],
            tables=tbl_str, seed=_fmt_cols(linked))},
    ]

    n_exec = 0
    for turn in range(max_turns):
        resp = llm.complete(messages[0]["content"],
                            "\n\n".join(m["content"] for m in messages[1:]),
                            temperature=0.0)
        tools = _parse_tools(resp)
        if not tools:
            trace.append(f"turn{turn}: no tool calls, stop")
            break
        obs = []
        stop = False
        for tool, arg in tools:
            if tool == "stop":
                stop = True
                break
            if tool == "schema_retrieval" and arg:
                got = vecstore.retrieve(arg, top_k=retrieve_top_m, exclude=used_idx)
                _add(got)
                obs.append(f"@schema_retrieval({arg!r}) ->\n" + (_fmt_cols(got) or "(no new columns)"))
            elif tool in ("sql_execution", "sql_draft") and arg:
                if n_exec >= max_exec:
                    obs.append(f"@{tool}: exploration budget exhausted; rely on retrieval + @stop.")
                    continue
                n_exec += 1
                ok, text = executor(arg)
                obs.append(f"@{tool} ->\n{text[:1200]}")
        trace.append(f"turn{turn}: {[t for t,_ in tools]} | linked={len(linked)}")
        if stop:
            break
        messages.append({"role": "assistant", "content": resp[:4000]})
        messages.append({"role": "user", "content": "\n\n".join(obs) +
                         "\n\nContinue: retrieve any still-missing columns (join keys, "
                         "names, dates), or @stop() if the schema is complete."})

    return linked, _fmt_cols(linked), trace


# --------------------------------------------------------------------------- #
# LinkAlign-style irrelevant-information isolation
# --------------------------------------------------------------------------- #
ISOLATE_SYS = """You are filtering a candidate schema for Text-to-SQL. Given a \
question and a list of retrieved columns (many are noise), keep ONLY the columns \
that are necessary or highly useful to answer the question (entities, metrics, \
join keys, filters, dates, output names). Drop clearly irrelevant columns.

Rules:
- Prefer recall over precision: when unsure, KEEP the column.
- Always keep primary/foreign-key style columns (*_id, *_code) of tables you keep.
- Output a JSON array of "table.column" strings to KEEP. No prose, no markdown."""

ISOLATE_USER = """Question: {question}

External knowledge: {external}

Candidate columns:
{cols}

Return JSON array of table.column to keep:"""


def isolate_irrelevant(linked: list[dict], question: str, external: str,
                       llm: LLM, min_keep: int = 12) -> tuple[list[dict], str]:
    """Drop clearly irrelevant columns (LinkAlign isolation). Returns filtered
    list + short trace note. Falls back to original list on parse failure."""
    if len(linked) <= min_keep:
        return linked, f"isolate: skip (only {len(linked)} cols)"
    lines = [f"{c['table']}.{c['column']}"
             + (f" -- {c['description'][:80]}" if c.get("description") else "")
             for c in linked]
    resp = llm.complete(
        ISOLATE_SYS,
        ISOLATE_USER.format(question=question,
                            external=(external or "(none)")[:1500],
                            cols="\n".join(lines[:200])),
        temperature=0.0)
    # parse JSON array of "table.column"
    m = re.search(r"\[.*?\]", resp, re.DOTALL)
    if not m:
        return linked, "isolate: parse-fail, keep all"
    try:
        import json
        keep_raw = json.loads(m.group(0))
    except Exception:  # noqa: BLE001
        return linked, "isolate: json-fail, keep all"
    keep = set()
    for item in keep_raw:
        s = str(item).strip().strip('"').strip("'")
        if "." in s:
            keep.add(s.lower())
    if len(keep) < min_keep // 2:
        return linked, f"isolate: too-aggressive ({len(keep)}), keep all"
    filtered = [c for c in linked
                if f"{c['table']}.{c['column']}".lower() in keep]
    # safety: if filter wiped a whole useful table's join keys, keep originals
    if len(filtered) < min_keep:
        return linked, f"isolate: below min_keep ({len(filtered)}), keep all"
    return filtered, f"isolate: {len(linked)} -> {len(filtered)}"
