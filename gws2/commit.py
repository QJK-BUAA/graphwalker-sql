"""Commit phase: Propose -> Generate -> (one) Confirm (HTML section 3, Commit).

The Commit phase turns the belief MAP into exactly one SQL:

  1. Propose  -- take the grounded subgraph S* (linked tables + join path +
     top belief columns/values) and run a light evidence check. If a required
     entity is clearly missing, add the LLM-suggested table(s) once; unresolved
     *semantic* concepts are flagged, never invented (HTML section 7).
  2. Generate -- produce ONE SQL from the filtered schema + validated join path
     + belief-derived grounding hints.
  3. Confirm  -- if execution errors OR returns empty, apply AT MOST ONE targeted
     repair. This is intentionally bounded: the design forbids unbounded
     self-refine / full-schema fallback so ablations stay clean.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

from . import config
from .belief import BeliefState
from .execute import run_query
from .explore import ExploreResult
from .graph_builder import SchemaGraph
from .llm import LLM
from .prompts import (PROMPT_COLUMN_ALIGN, PROMPT_GENERATE, PROMPT_PROPOSE,
                      PROMPT_REPAIR)
from .schema import Schema

_SQL_BLOCK = re.compile(r"```sql\s*(.*?)```", re.DOTALL | re.IGNORECASE)
_ANY_BLOCK = re.compile(r"```\s*(.*?)```", re.DOTALL)


def _extract_sql(text: str) -> str:
    m = _SQL_BLOCK.search(text) or _ANY_BLOCK.search(text)
    return (m.group(1) if m else text).strip().rstrip(";").strip()


@dataclass
class CommitResult:
    sql: str
    execution: dict
    linked_tables: list[str]
    join_conditions: list[str]
    grounding_hints: str
    propose_verdict: str = ""
    missing_added: list[str] = field(default_factory=list)
    missing_rejected: list[str] = field(default_factory=list)
    repaired: bool = False
    col_aligned: bool = False
    steps: list[str] = field(default_factory=list)


def _belief_hints(schema: Schema, belief: BeliefState, tables: list[str],
                  evidence: str = "") -> str:
    """Turn the top column / value beliefs into human-readable grounding hints.

    When ``evidence`` (BIRD external knowledge) is present, we additionally mine
    two generic, dataset-agnostic patterns and surface them as explicit bindings:
      * value mappings   e.g. "Operation = 'VYBER KARTOU'", "type = 'OWNER'"
      * ratio/formula     e.g. "rate = a / b", "percentage = ... * 100 / ..."
    These are the failure mode where evidence was available but not applied.
    """
    sel = set(tables)
    lines: list[str] = []
    top_cols = [k for k in belief.map_estimate("column", top=12)
                if k.split(".")[0] in sel]
    if top_cols:
        lines.append("High-belief columns (prefer for concepts in the question):")
        for key in top_cols[:8]:
            lines.append(f"- {key} (belief {belief.columns[key].score:+g})")
    val_keys = belief.map_estimate("value", top=6)
    if val_keys:
        lines.append("Confirmed filter values (literal found in that column):")
        for vk in val_keys:
            lines.append(f"- {vk.replace('@', ' found in ')}")

    ev_hints = _evidence_hints(evidence)
    if ev_hints:
        lines.append("From external knowledge (apply these literally):")
        lines.extend(f"- {h}" for h in ev_hints)
    return "\n".join(lines) if lines else "(none)"


# Generic evidence miners (NOT tuned to any specific question).
_EV_VALUE_MAP = re.compile(
    r"([A-Za-z_][\w ]*?)\s*(?:=|refers to|stands for|means|is)\s*"
    r"'([^']+)'", re.I)
_EV_FORMULA = re.compile(
    r"([A-Za-z_][\w ()%/\-]*?)\s*=\s*([^.\n;]*[/*+\-][^.\n;]*)")


def _evidence_hints(evidence: str, max_hints: int = 6) -> list[str]:
    if not evidence:
        return []
    out: list[str] = []
    for m in _EV_FORMULA.finditer(evidence):
        lhs, rhs = m.group(1).strip(), m.group(2).strip()
        if 2 <= len(rhs) <= 80 and any(op in rhs for op in "/*+-"):
            out.append(f"compute `{lhs}` as: {rhs}")
    for m in _EV_VALUE_MAP.finditer(evidence):
        concept, val = m.group(1).strip(), m.group(2).strip()
        if concept and len(concept) <= 40:
            out.append(f"filter for '{concept}' using the value '{val}'")
    # de-dup preserving order
    seen, uniq = set(), []
    for h in out:
        if h not in seen:
            seen.add(h)
            uniq.append(h)
    return uniq[:max_hints]


def propose(question: str, schema: Schema, linked_tables: list[str],
            join_conditions: list[str], belief: BeliefState, llm: LLM,
            enabled: bool = True) -> tuple[str, list[str]]:
    """Evidence checkpoint. Returns (verdict, tables_to_add)."""
    if not enabled:
        return "SKIPPED", []
    top_cols = ", ".join(belief.map_estimate("column", top=10)) or "(none)"
    user = (f"Question: {question}\n\n"
            f"Proposed tables: {', '.join(linked_tables)}\n"
            f"Join conditions: {'; '.join(join_conditions) or '(none)'}\n"
            f"High-belief columns: {top_cols}\n"
            f"Available tables: {', '.join(schema.table_names())}")
    resp = llm.complete(PROMPT_PROPOSE, user, temperature=0.0)
    verdict = "OK"
    m = re.search(r"verdict\s*=\s*(OK|MISSING)", resp, re.I)
    if m:
        verdict = m.group(1).upper()
    add: list[str] = []
    m = re.search(r"missing\s*=\s*(.*)", resp, re.I)
    if m:
        valid = {t.lower(): t for t in schema.table_names()}
        for tok in re.split(r"[,\s]+", m.group(1).strip()):
            key = tok.strip().strip('"`.').lower()
            if key in valid and valid[key] not in linked_tables:
                add.append(valid[key])
    return verdict, add


def _join_conditions_for(graph_obj: SchemaGraph, tables: list[str]) -> list[str]:
    sel = set(tables)
    seen, out = set(), []
    for u, v, data in graph_obj.graph.edges(data=True):
        if u in sel and v in sel:
            for (t1, c1, t2, c2) in data.get("joins", []):
                cond = f"{t1}.{c1} = {t2}.{c2}"
                if cond not in seen:
                    seen.add(cond)
                    out.append(cond)
    return out


def _has_join_evidence(graph_obj: SchemaGraph, linked: set[str], table: str) -> bool:
    """Whether ``table`` has structural support to enter the grounded subgraph.

    Propose is an anti-hallucination checkpoint, so an LLM-suggested table should
    not become a hard fact unless it connects to the already-grounded subgraph.
    A graph edge (declared or inferred+verified) is the cheapest white-box
    evidence the method already maintains.
    """
    graph = graph_obj.graph
    if table not in graph:
        return False
    for t in linked:
        if t in graph and graph.has_edge(t, table):
            data = graph[t][table]
            if data.get("joins"):
                return True
    return False


def _gate_propose_additions(graph_obj: SchemaGraph, linked_tables: list[str],
                            proposed: list[str]) -> tuple[list[str], list[str]]:
    """Accept only LLM-proposed tables with join evidence to the current subgraph.

    The filter is iterative so a proposed chain A -> B -> C can be accepted when
    A first connects to the grounded subgraph and C then connects through B.
    Tables that remain disconnected are kept out of the generation schema.
    """
    linked = set(linked_tables)
    pending = []
    for t in proposed:
        if t not in linked and t not in pending:
            pending.append(t)

    accepted: list[str] = []
    changed = True
    while changed:
        changed = False
        rest: list[str] = []
        for t in pending:
            if _has_join_evidence(graph_obj, linked, t):
                accepted.append(t)
                linked.add(t)
                changed = True
            else:
                rest.append(t)
        pending = rest
    return accepted, pending


def generate_sql(question: str, schema: Schema, linked_tables: list[str],
                 join_conditions: list[str], hints: str, llm: LLM,
                 dialect: str = "SQLite", schema_context: str | None = None,
                 evidence: str = "") -> str:
    schema_text = schema_context or schema.to_ddl_text(linked_tables)
    join_str = "\n".join(join_conditions) if join_conditions else \
        "(no explicit join; tables may be standalone)"
    system = PROMPT_GENERATE.format(
        dialect=dialect, schema=schema_text, join_path=join_str,
        evidence=evidence.strip() or "(none)", hints=hints, question=question)
    resp = llm.complete(system, f"Question: {question}", temperature=0.0)
    return _extract_sql(resp)


def _repair(question: str, schema: Schema, linked_tables: list[str], sql: str,
            problem: str, feedback: str, llm: LLM, dialect: str,
            schema_context: str | None = None, evidence: str = "") -> str:
    system = PROMPT_REPAIR.format(
        dialect=dialect, problem=problem,
        schema=schema_context or schema.to_ddl_text(linked_tables),
        evidence=evidence.strip() or "(none)",
        question=question, sql=sql, feedback=feedback)
    return _extract_sql(llm.complete(system, "Repair the query.", temperature=0.0))


def _rowcount_sig(ex: dict) -> tuple:
    """(n_rows, n_cols) signature to detect whether alignment changed the data."""
    if not ex.get("ok"):
        return (-1, -1)
    rows = ex.get("rows") or []
    ncol = len(rows[0]) if rows else len(ex.get("columns") or [])
    return (ex.get("n_shown", len(rows)), ncol)


def _column_align(question: str, sql: str, llm: LLM, dialect: str) -> str:
    system = PROMPT_COLUMN_ALIGN.format(dialect=dialect, question=question, sql=sql)
    return _extract_sql(llm.complete(system, "Align the SELECT list.", temperature=0.0))


def _cols_are_subset(ex_new: dict, ex_old: dict) -> bool:
    """True iff every column of the aligned result is (as a value multiset) one of
    the original result's columns. Guarantees alignment only DROPPED columns and
    did not rewrite/replace any selected expression."""
    from collections import Counter
    old_rows = ex_old.get("rows") or []
    new_rows = ex_new.get("rows") or []
    if not new_rows:
        return False
    n_old = len(old_rows[0]) if old_rows else 0
    n_new = len(new_rows[0]) if new_rows else 0
    old_cols = [Counter(str(r[c]) for r in old_rows) for c in range(n_old)]
    new_cols = [Counter(str(r[c]) for r in new_rows) for c in range(n_new)]
    used = [False] * len(old_cols)
    for nc in new_cols:
        hit = False
        for j, oc in enumerate(old_cols):
            if not used[j] and oc == nc:
                used[j] = True; hit = True; break
        if not hit:
            return False
    return True


def commit(question: str, schema: Schema, graph_obj: SchemaGraph,
           explore_res: ExploreResult, belief: BeliefState, sqlite_path: str,
           llm: LLM, dialect: str = "SQLite", schema_context: str | None = None,
           use_propose: bool = True, max_repairs: int = config.MAX_REPAIRS,
           allow_repair_on_empty: bool = True,
           evidence: str = "", use_evidence_injection: bool = True,
           use_column_align: bool = False,
           use_propose_evidence_gate: bool = True) -> CommitResult:
    steps: list[str] = []
    linked = list(explore_res.linked_tables)
    joins = list(explore_res.join_conditions)
    # Evidence is injected into the dedicated prompt block + grounding hints only
    # when enabled (clean ablation). Otherwise the caller may still have folded it
    # into the question string (legacy behaviour).
    ev = evidence if use_evidence_injection else ""

    # 1) Propose: evidence check + at-most-once missing-table addition --------
    verdict, proposed_add = propose(question, schema, linked, joins, belief, llm,
                                    enabled=use_propose)
    rejected: list[str] = []
    if use_propose_evidence_gate and proposed_add:
        add, rejected = _gate_propose_additions(graph_obj, linked, proposed_add)
        if rejected:
            steps.append(f"propose gate rejected unsupported tables {rejected}")
    else:
        add = proposed_add
    if add:
        linked = sorted(set(linked) | set(add))
        joins = _join_conditions_for(graph_obj, linked)
        steps.append(f"[propose={verdict}] added missing tables {add} -> {linked}")
    else:
        steps.append(f"[propose={verdict}] no change")

    # 2) Generate exactly one SQL -------------------------------------------- #
    hints = _belief_hints(schema, belief, linked, evidence=ev)
    ctx = schema_context if schema_context else schema.to_ddl_text(linked)
    sql = generate_sql(question, schema, linked, joins, hints, llm,
                       dialect=dialect, schema_context=ctx, evidence=ev)
    ex = run_query(sqlite_path, sql)
    steps.append(f"generate -> ok={ex.get('ok')} "
                 f"rows={ex.get('n_shown') if ex.get('ok') else ex.get('error')}")

    # 3) Confirm: at most one targeted repair -------------------------------- #
    repaired = False
    if max_repairs > 0:
        need_repair = (not ex.get("ok")) or (
            allow_repair_on_empty and ex.get("ok") and ex.get("n_shown", 0) == 0)
        if need_repair:
            problem = ("failed to execute" if not ex.get("ok")
                       else "executed but returned an empty result")
            feedback = ex.get("error", "empty result set")
            sql2 = _repair(question, schema, linked, sql, problem, feedback, llm,
                           dialect, schema_context=ctx, evidence=ev)
            ex2 = run_query(sqlite_path, sql2)
            # keep the repair only if it did not regress
            if ex2.get("ok") and (not ex.get("ok") or ex2.get("n_shown", 0) > 0):
                sql, ex, repaired = sql2, ex2, True
                steps.append(f"repair -> ok={ex.get('ok')} rows={ex.get('n_shown')}")
            else:
                steps.append("repair discarded (no improvement)")

    # 4) Column alignment: BIRD grades whole rows, so TRIM extra SELECT columns
    #    to what the question asks. Safety net (strict, to never corrupt a correct
    #    answer): only accept when the aligned query still executes, keeps the SAME
    #    row count, and STRICTLY REDUCES the column count (pure trimming) -- and
    #    every surviving column's values already existed in the original result
    #    (so we only drop columns, never rewrite an expression).
    col_aligned = False
    if use_column_align and ex.get("ok") and ex.get("n_shown", 0) > 0:
        old_rows, old_cols = _rowcount_sig(ex)
        if old_cols > 1:  # nothing to trim from a single-column result
            sql3 = _column_align(question, sql, llm, dialect)
            if sql3 and sql3.strip() != sql.strip():
                ex3 = run_query(sqlite_path, sql3)
                new_rows, new_cols = _rowcount_sig(ex3)
                if (ex3.get("ok") and new_rows == old_rows
                        and 0 < new_cols < old_cols
                        and _cols_are_subset(ex3, ex)):
                    sql, ex, col_aligned = sql3, ex3, True
                    steps.append(f"column-align -> trimmed cols {old_cols}->{new_cols} "
                                 f"(rows unchanged={new_rows})")
                else:
                    steps.append("column-align discarded (not a safe pure trim)")

    return CommitResult(sql=sql, execution=ex, linked_tables=linked,
                        join_conditions=joins, grounding_hints=hints,
                        propose_verdict=verdict, missing_added=add,
                        missing_rejected=rejected, repaired=repaired,
                        col_aligned=col_aligned, steps=steps)
