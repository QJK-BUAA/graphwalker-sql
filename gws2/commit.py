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

import json
import re
from dataclasses import dataclass, field

from . import config
from .belief import BeliefState
from .execute import run_query
from .explore import ExploreResult
from .graph_builder import SchemaGraph
from .llm import LLM
from .prompts import (PROMPT_COLUMN_ALIGN, PROMPT_GENERATE, PROMPT_PROPOSE,
                      PROMPT_REPAIR, PROMPT_STRUCTURE_PLAN)
from .schema import Schema

_SQL_BLOCK = re.compile(r"```sql\s*(.*?)```", re.DOTALL | re.IGNORECASE)
_ANY_BLOCK = re.compile(r"```\s*(.*?)```", re.DOTALL)


def _extract_sql(text: str) -> str:
    m = _SQL_BLOCK.search(text) or _ANY_BLOCK.search(text)
    sql = (m.group(1) if m else text).strip()
    # Some model repairs occasionally emit an opening fence without a closing
    # fence. Strip fence markers defensively before execution/evaluation.
    sql = re.sub(r"^```(?:sql)?\s*", "", sql, flags=re.I).strip()
    sql = re.sub(r"\s*```$", "", sql).strip()
    return sql.rstrip(";").strip()


@dataclass
class CommitResult:
    sql: str
    execution: dict
    linked_tables: list[str]
    join_conditions: list[str]
    grounding_hints: str
    query_skeleton: dict = field(default_factory=dict)
    structural_feedback: list[str] = field(default_factory=list)
    propose_verdict: str = ""
    missing_added: list[str] = field(default_factory=list)
    missing_rejected: list[str] = field(default_factory=list)
    widened_tables: list[str] = field(default_factory=list)
    repaired: bool = False
    col_aligned: bool = False
    steps: list[str] = field(default_factory=list)


def _concept_hint_lines(concept: str, binding: dict, sel: set[str]) -> list[str]:
    """Render one concept binding as a grounding hint (only if its column is shown)."""
    col = binding.get("column", "")
    if not col or col.split(".")[0] not in sel:
        return []
    role = binding.get("role", "output")
    if binding.get("confident"):
        tag = "value-confirmed" if binding.get("confirmed") else "high-margin"
        val = binding.get("value") or ""
        extra = f" filter value '{val}'" if role == "filter" and val else ""
        return [f"- \"{concept}\" ({role}) -> {col} [{tag}]{extra}"]
    alts = [a for a in binding.get("alternatives", []) if a.split(".")[0] in sel]
    cand = ", ".join([col] + alts) if alts else col
    return [f"- \"{concept}\" ({role}) is ambiguous; choose by semantics among: {cand}"]


def _neighbor_tables(graph_obj: SchemaGraph, linked: list[str], cap: int) -> list[str]:
    """Bounded 1-hop graph neighbours of the linked set, ranked by edge confidence.

    Used by confidence-adaptive schema exposure (Point 2a) to give the generator a
    little room to recover from a missed table without dumping the whole schema.
    """
    g = graph_obj.graph
    sel = set(linked)
    best: dict[str, float] = {}
    for t in sel:
        if t not in g:
            continue
        for nb in g.neighbors(t):
            if nb in sel:
                continue
            conf = g[t][nb].get("confidence", 0.0)
            best[nb] = max(best.get(nb, 0.0), conf)
    ranked = sorted(best.items(), key=lambda x: x[1], reverse=True)
    return [nb for nb, _ in ranked[:cap]]


def _belief_hints(schema: Schema, belief: BeliefState, tables: list[str],
                  evidence: str = "", concept_bindings: dict | None = None) -> str:
    """Turn the top column / value beliefs into human-readable grounding hints.

    When ``evidence`` (BIRD external knowledge) is present, we additionally mine
    two generic, dataset-agnostic patterns and surface them as explicit bindings:
      * value mappings   e.g. "Operation = 'VYBER KARTOU'", "type = 'OWNER'"
      * ratio/formula     e.g. "rate = a / b", "percentage = ... * 100 / ..."
    These are the failure mode where evidence was available but not applied.

    Query-centric concept bindings (Point 1) are surfaced FIRST when available,
    because "which column does this concept mean" is the dominant residual error.
    """
    sel = set(tables)
    lines: list[str] = []
    # (0) concept -> column bindings first: they directly target "right table,
    # wrong column". Only show bindings whose winning column is in the schema we
    # are about to expose (so we never point at a trimmed-away table).
    if concept_bindings:
        conf_lines = [h for c, b in concept_bindings.items()
                      for h in _concept_hint_lines(c, b, sel)]
        if conf_lines:
            lines.append("Concept -> column bindings (resolve each question concept "
                         "to THIS column):")
            lines.extend(conf_lines)
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


def _extract_json_object(text: str) -> dict:
    """Parse the first JSON object in an LLM response, best-effort."""
    if not text:
        return {}
    text = text.strip()
    m = re.search(r"```(?:json)?\s*(.*?)```", text, re.S | re.I)
    if m:
        text = m.group(1).strip()
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return {}
    try:
        return json.loads(text[start:end + 1])
    except Exception:  # noqa: BLE001
        return {}


def _as_bool(v) -> bool:
    if isinstance(v, bool):
        return v
    if isinstance(v, str):
        return v.strip().lower() in {"true", "yes", "1", "y"}
    return bool(v)


def _normalise_skeleton(raw: dict) -> dict:
    if not isinstance(raw, dict):
        return {}
    set_op = str(raw.get("set_op", "none")).strip().lower()
    if set_op not in {"none", "intersect", "union", "except"}:
        set_op = "none"
    try:
        arity = int(raw.get("select_arity", 0))
    except Exception:  # noqa: BLE001
        arity = 0
    if arity <= 0 or arity > 8:
        arity = None
    return {
        "set_op": set_op,
        "nested": _as_bool(raw.get("nested", False)),
        "group_by": _as_bool(raw.get("group_by", False)),
        "having": _as_bool(raw.get("having", False)),
        "order_by": _as_bool(raw.get("order_by", False)),
        "limit": _as_bool(raw.get("limit", False)),
        "select_arity": arity,
        "aggregation": _as_bool(raw.get("aggregation", False)),
        "notes": str(raw.get("notes", ""))[:200],
    }


def _skeleton_text(skeleton: dict) -> str:
    if not skeleton:
        return "(none)"
    return json.dumps(skeleton, ensure_ascii=False, sort_keys=True)


def plan_query_structure(question: str, schema: Schema, linked_tables: list[str],
                         join_conditions: list[str], hints: str, llm: LLM,
                         dialect: str = "SQLite",
                         schema_context: str | None = None,
                         evidence: str = "") -> dict:
    """Plan a compact query skeleton before SQL generation.

    Ground/Explore decide what to query; this step decides how to query (set op,
    nesting, grouping, ordering, select arity). It remains parseable and small so
    structural verification can check the generated SQL against it.
    """
    schema_text = schema_context or schema.to_ddl_text(linked_tables)
    join_str = "\n".join(join_conditions) if join_conditions else \
        "(no explicit join; tables may be standalone)"
    system = PROMPT_STRUCTURE_PLAN.format(
        dialect=dialect, schema=schema_text, join_path=join_str,
        evidence=evidence.strip() or "(none)", hints=hints, question=question)
    resp = llm.complete(system, "Plan the SQL structure.", temperature=0.0)
    return _normalise_skeleton(_extract_json_object(resp))


def _sql_body(sql: str) -> str:
    return _extract_sql(sql).lower()


def _count_selects(sql: str) -> int:
    return len(re.findall(r"\bselect\b", _sql_body(sql), flags=re.I))


def _top_level_select_arity(sql: str) -> int | None:
    s = _extract_sql(sql)
    m = re.search(r"\bselect\b", s, re.I)
    if not m:
        return None
    i = m.end()
    depth = 0
    start = i
    end = len(s)
    for j in range(i, len(s)):
        ch = s[j]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth = max(0, depth - 1)
        elif depth == 0 and re.match(r"\sfrom\b", s[j:], re.I):
            end = j
            break
    select_part = s[start:end].strip()
    select_part = re.sub(r"^distinct\s+", "", select_part, flags=re.I)
    if not select_part:
        return None
    depth = 0
    arity = 1
    for ch in select_part:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth = max(0, depth - 1)
        elif ch == "," and depth == 0:
            arity += 1
    return arity


def structural_feedback(sql: str, skeleton: dict) -> list[str]:
    """Return structural mismatches between generated SQL and planned skeleton."""
    if not skeleton:
        return []
    s = _sql_body(sql)
    feedback: list[str] = []
    set_op = skeleton.get("set_op", "none")
    if set_op != "none" and not re.search(rf"\b{re.escape(set_op)}\b", s, re.I):
        feedback.append(f"planned set_op={set_op}, but SQL does not contain {set_op.upper()}")
    if skeleton.get("nested") and _count_selects(sql) <= 1:
        feedback.append("planned nested=true, but SQL has no subquery")
    if skeleton.get("group_by") and not re.search(r"\bgroup\s+by\b", s, re.I):
        feedback.append("planned group_by=true, but SQL has no GROUP BY")
    if skeleton.get("having") and not re.search(r"\bhaving\b", s, re.I):
        feedback.append("planned having=true, but SQL has no HAVING")
    if skeleton.get("order_by") and not re.search(r"\border\s+by\b", s, re.I):
        feedback.append("planned order_by=true, but SQL has no ORDER BY")
    if skeleton.get("limit") and not re.search(r"\blimit\b", s, re.I):
        feedback.append("planned limit=true, but SQL has no LIMIT")
    if skeleton.get("aggregation") and not re.search(
            r"\b(count|sum|avg|max|min)\s*\(", s, re.I):
        feedback.append("planned aggregation=true, but SQL has no aggregate function")
    arity = skeleton.get("select_arity")
    got = _top_level_select_arity(sql)
    if arity and got and got != arity:
        feedback.append(f"planned select_arity={arity}, but SQL selects {got} columns")
    return feedback


def generate_sql(question: str, schema: Schema, linked_tables: list[str],
                 join_conditions: list[str], hints: str, llm: LLM,
                 dialect: str = "SQLite", schema_context: str | None = None,
                 evidence: str = "", skeleton: dict | None = None) -> str:
    schema_text = schema_context or schema.to_ddl_text(linked_tables)
    join_str = "\n".join(join_conditions) if join_conditions else \
        "(no explicit join; tables may be standalone)"
    system = PROMPT_GENERATE.format(
        dialect=dialect, schema=schema_text, join_path=join_str,
        evidence=evidence.strip() or "(none)", hints=hints,
        skeleton=_skeleton_text(skeleton or {}), question=question)
    resp = llm.complete(system, f"Question: {question}", temperature=0.0)
    return _extract_sql(resp)


def _repair(question: str, schema: Schema, linked_tables: list[str], sql: str,
            problem: str, feedback: str, llm: LLM, dialect: str,
            schema_context: str | None = None, evidence: str = "",
            skeleton: dict | None = None) -> str:
    system = PROMPT_REPAIR.format(
        dialect=dialect, problem=problem,
        schema=schema_context or schema.to_ddl_text(linked_tables),
        skeleton=_skeleton_text(skeleton or {}),
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
           use_propose_evidence_gate: bool = True,
           use_structure_plan: bool = True,
           concept_bindings: dict | None = None,
           use_adaptive_schema: bool = True,
           soft_structure: bool = True) -> CommitResult:
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
    hints = _belief_hints(schema, belief, linked, evidence=ev,
                          concept_bindings=concept_bindings)
    if explore_res.column_hints:
        hints += "\n\nColumn probe evidence (from low-cost SQL probes):\n" + \
            "\n".join(explore_res.column_hints)

    # Confidence-adaptive schema exposure (Point 2a): when belief is uncertain
    # (Propose flagged a missing table, anchors were disconnected, or column/path
    # belief entropy is high), widen the exposed schema with a few 1-hop graph
    # neighbours as OPTIONAL candidate tables so the model can recover from a
    # missed table. High-confidence questions keep the tight, MAP-only schema.
    widened: list[str] = []
    if use_adaptive_schema and not schema_context:
        low_conf = (
            verdict == "MISSING"
            or explore_res.chosen_path is None
            or belief.family_entropy("column") >= config.ADAPTIVE_WIDEN_ENTROPY
            or belief.family_entropy("path") >= config.PATH_ENTROPY_PROBE
        )
        if low_conf:
            widened = _neighbor_tables(graph_obj, linked,
                                       config.SCHEMA_WIDEN_MAX_TABLES)
            if widened:
                steps.append(f"[adaptive schema] low confidence -> +{len(widened)} "
                             f"optional candidate tables {widened}")

    if schema_context:
        ctx = schema_context
    else:
        ctx = schema.to_ddl_text(linked)
        if widened:
            ctx += ("\n\n-- Additional candidate tables (OPTIONAL: only use these if "
                    "the grounded tables above cannot answer the question; if you use "
                    "one you must supply your own JOIN condition):\n"
                    + schema.to_ddl_text(widened))

    skeleton: dict = {}
    if use_structure_plan:
        skeleton = plan_query_structure(question, schema, linked, joins, hints, llm,
                                        dialect=dialect, schema_context=ctx,
                                        evidence=ev)
        steps.append(f"structure-plan -> {_skeleton_text(skeleton)}")

    sql = generate_sql(question, schema, linked, joins, hints, llm,
                       dialect=dialect, schema_context=ctx, evidence=ev,
                       skeleton=skeleton)
    struct_feedback = structural_feedback(sql, skeleton) if use_structure_plan else []
    ex = run_query(sqlite_path, sql)
    steps.append(f"generate -> ok={ex.get('ok')} "
                 f"rows={ex.get('n_shown') if ex.get('ok') else ex.get('error')}")
    if struct_feedback:
        steps.append("structure-check -> " + " | ".join(struct_feedback))

    # 3) Confirm: at most one targeted repair -------------------------------- #
    # Soft skeleton (Point 2b): by default a skeleton mismatch is only a HINT, not
    # a repair trigger -- so the model keeps the freedom to answer the question
    # even when its shape differs from the planner's guess (the planner over-
    # preferred EXCEPT/nested in the Spider1 study). Only execution failures /
    # empty results trigger repair. The `hardstruct` ablation restores the old
    # behaviour where a structural mismatch forces a repair.
    repaired = False
    struct_trigger = bool(struct_feedback) and use_structure_plan and not soft_structure
    if max_repairs > 0:
        exec_bad = (not ex.get("ok")) or (
            allow_repair_on_empty and ex.get("ok") and ex.get("n_shown", 0) == 0)
        need_repair = exec_bad or struct_trigger
        if need_repair:
            if exec_bad:
                problem = ("failed to execute" if not ex.get("ok")
                           else "executed but returned an empty result")
                feedback = ex.get("error", "empty result set")
            else:  # structural-only trigger (hardstruct ablation)
                problem = "does not match the planned query skeleton"
                feedback = "; ".join(struct_feedback)
            sql2 = _repair(question, schema, linked, sql, problem, feedback, llm,
                           dialect, schema_context=ctx, evidence=ev,
                           skeleton=skeleton)
            ex2 = run_query(sqlite_path, sql2)
            struct_feedback2 = structural_feedback(sql2, skeleton) \
                if (use_structure_plan and not soft_structure) else []
            # keep the repair only if it did not regress
            if ex2.get("ok") and not struct_feedback2 and (
                    struct_trigger or not ex.get("ok") or ex2.get("n_shown", 0) > 0):
                sql, ex, repaired = sql2, ex2, True
                struct_feedback = structural_feedback(sql, skeleton) \
                    if use_structure_plan else []
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
                        query_skeleton=skeleton, widened_tables=widened,
                        structural_feedback=struct_feedback,
                        propose_verdict=verdict, missing_added=add,
                        missing_rejected=rejected, repaired=repaired,
                        col_aligned=col_aligned, steps=steps)
