"""Query-centric concept alignment (Point 1): resolve *which column* each concept means.

Full-set error analysis of GraphWalker-SQL 2.0 (see ``BIRD错题反思报告.md``) found that
~69% of wrong answers already link the correct *tables* -- the dominant residual
error is "right table, wrong column" and the "same concept lives in several tables"
trap (e.g. ``District`` in both ``frpm`` and ``schools`` with different value
conventions). The pipeline grounds tables well but under-models the *query itself*.

This module makes the question a first-class citizen. It (1) decomposes the query
into atomic concepts (one LLM call, ablatable), and (2) for every concept runs a
WHITE-BOX belief competition over candidate columns using the signals the method
already maintains:

    score(concept, column) =  name_overlap                (lexical)
                            + table_anchor_prior           (column sits in an anchored table)
                            + type_fit                     (literal type vs column type)
                            + uniqueness                   (key-like, for output/id concepts)
                            + value_hit                    (literal actually found in the column)  [decisive]

The winning ``concept -> column`` bindings are written into the shared belief state
(reinforcing the column belief) and rendered as explicit grounding hints, so the
generator is *told* which column to use for each concept instead of guessing between
near-synonyms. Everything is bounded (few candidates, capped value probes) and every
number is traceable -- consistent with the project's white-box, cost-constrained design.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

from . import config
from .belief import SCORE_CONCEPT_MATCH, BeliefState
from .execute import scalar
from .ground import Anchors
from .llm import LLM
from .prompts import PROMPT_CONCEPTS
from .schema import Schema

_STOP = {"the", "a", "an", "of", "in", "on", "for", "to", "and", "or", "with",
         "what", "which", "who", "how", "many", "list", "show", "find", "all",
         "is", "are", "was", "were", "give", "me", "number", "count", "name",
         "names", "please", "that", "have", "has", "by", "from", "each", "their",
         "value", "values", "total", "per"}


@dataclass
class Concept:
    phrase: str
    role: str = "output"          # "output" | "filter"
    value: str = ""               # literal filter value, if the question gave one


@dataclass
class ConceptAlignResult:
    bindings: dict[str, dict] = field(default_factory=dict)
    hints: list[str] = field(default_factory=list)
    steps: list[str] = field(default_factory=list)
    n_value_probes: int = 0


def _tokens(text: str) -> list[str]:
    toks = re.findall(r"[A-Za-z_][A-Za-z0-9_]+", (text or "").lower())
    return [t for t in toks if t not in _STOP and len(t) > 1]


def _col_tokens(name: str) -> set[str]:
    # split snake_case / spaced names into tokens
    return {t for t in re.split(r"[_\s]+", (name or "").lower()) if t}


def _looks_numeric(v: str) -> bool:
    return bool(re.fullmatch(r"[-+]?\d[\d,]*(\.\d+)?%?", (v or "").strip()))


def _is_numeric_type(tp: str) -> bool:
    t = (tp or "").upper()
    return any(k in t for k in ("INT", "REAL", "NUM", "DEC", "FLOA", "DOUB"))


def _is_text_type(tp: str) -> bool:
    t = (tp or "").upper()
    return any(k in t for k in ("CHAR", "TEXT", "CLOB", "STRING", "VARCHAR"))


def parse_concepts(text: str) -> list[Concept]:
    """Parse the concept-extraction response into bounded, deduped concepts."""
    out: list[Concept] = []
    seen: set[str] = set()
    for line in (text or "").splitlines():
        line = line.strip()
        if not line or "concept=" not in line.lower():
            continue
        m = re.search(r"concept\s*=\s*(.*?)\s*(?:\||$)", line, re.I)
        if not m:
            continue
        phrase = m.group(1).strip().strip("'\"").strip()
        if not phrase or phrase.lower() in seen:
            continue
        role_m = re.search(r"role\s*=\s*(output|filter)", line, re.I)
        val_m = re.search(r"value\s*=\s*(.*?)\s*(?:\||$)", line, re.I)
        role = role_m.group(1).lower() if role_m else "output"
        value = ""
        if val_m:
            value = val_m.group(1).strip().strip("'\"").strip()
            if value.lower() in {"", "(empty)", "none", "null"}:
                value = ""
        seen.add(phrase.lower())
        out.append(Concept(phrase=phrase, role=role, value=value))
        if len(out) >= config.CONCEPT_MAX_CONCEPTS:
            break
    return out


def extract_concepts(question: str, evidence: str, llm: LLM) -> list[Concept]:
    user = f"Question: {question}"
    if evidence:
        user += f"\nExternal knowledge: {evidence}"
    resp = llm.complete(PROMPT_CONCEPTS, user, temperature=0.0)
    return parse_concepts(resp)


def _name_score(concept_tokens: set[str], col_name: str, table: str) -> float:
    """Lexical alignment between a concept and a column name (and its table)."""
    if not concept_tokens:
        return 0.0
    ctoks = _col_tokens(col_name)
    inter = concept_tokens & ctoks
    score = 1.5 * len(inter)
    cl = col_name.lower()
    # substring hits catch e.g. concept "district" vs column "district_name"
    for tok in concept_tokens:
        if tok not in inter and len(tok) > 2 and (tok in cl or cl in tok):
            score += 0.6
    # a concept token appearing in the table name is a mild co-location signal
    tl = table.lower()
    if any(tok in tl for tok in concept_tokens):
        score += 0.3
    return score


def _candidate_columns(concept: Concept, schema: Schema,
                       anchor_tables: set[str],
                       search_tables: list[str]) -> list[tuple[float, str, str]]:
    """Bounded, lexically-pre-scored candidate columns for one concept."""
    ctoks = set(_tokens(concept.phrase))
    scored: list[tuple[float, str, str]] = []
    for t in search_tables:
        for c in schema.tables.get(t, []):
            ns = _name_score(ctoks, c.name, t)
            if ns <= 0:
                continue
            if t in anchor_tables:
                ns += 0.5
            scored.append((ns, t, c.name))
    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[:config.CONCEPT_MAX_CANDIDATES]


def _value_in_column(sqlite_path: str, table: str, column: str, value: str) -> bool:
    v = value.replace("'", "''")
    sql = (f'SELECT 1 FROM "{table}" WHERE "{column}" = \'{v}\' '
           f'OR CAST("{column}" AS TEXT) LIKE \'%{v}%\' LIMIT 1')
    return scalar(sqlite_path, sql, timeout=config.CONCEPT_PROBE_TIMEOUT) is not None


def align_query_concepts(question: str, schema: Schema, anchors: Anchors,
                         belief: BeliefState, sqlite_path: str, llm: LLM,
                         evidence: str = "") -> ConceptAlignResult:
    """Decompose the query into concepts and bind each to its best-matching column.

    Updates ``belief`` (column + value families and ``concept_bindings``) and returns
    human-readable grounding hints for the Commit prompt.
    """
    res = ConceptAlignResult()
    concepts = extract_concepts(question, evidence, llm)
    if not concepts:
        res.steps.append("concept align skipped: no concepts extracted")
        return res

    anchor_tables = set(anchors.sources + anchors.destinations)
    # Prefer anchored tables; also allow a bounded set of non-anchor tables so a
    # genuinely mislinked concept can escape its anchor. Iterate in schema-definition
    # order (not set order) so results are deterministic under temp=0/seed.
    ordered = schema.table_names()
    search_tables = [t for t in ordered if t in anchor_tables]
    if search_tables:
        extra = [t for t in ordered if t not in anchor_tables]
        search_tables = search_tables + extra[:20]
    else:
        search_tables = ordered[:30]

    res.steps.append(f"concept align: {len(concepts)} concepts, "
                     f"{len(search_tables)} search tables")
    n_probes = 0
    for con in concepts:
        cands = _candidate_columns(con, schema, anchor_tables, search_tables)
        if not cands:
            continue
        scored: list[tuple[float, str, bool]] = []   # (score, "t.c", value_confirmed)
        for pre, t, cname in cands:
            key = f"{t}.{cname}"
            score = pre
            col = schema.column(t, cname)
            # type fit
            if con.value and col is not None:
                if _looks_numeric(con.value) and _is_numeric_type(col.type):
                    score += 0.5
                elif not _looks_numeric(con.value) and _is_text_type(col.type):
                    score += 0.3
            # uniqueness helps id-like OUTPUT concepts (e.g. "id of ...")
            if con.role == "output" and col is not None and col.uniqueness >= 0.98 \
                    and (col.n_rows or 0) > 0:
                score += 0.3
            # value hit: decisive, but bounded
            confirmed = False
            if con.value and n_probes < config.CONCEPT_MAX_VALUE_PROBES:
                n_probes += 1
                if _value_in_column(sqlite_path, t, cname, con.value):
                    score += 3.0
                    confirmed = True
            scored.append((score, key, confirmed))

        scored.sort(key=lambda x: x[0], reverse=True)
        top_score, top_key, top_conf = scored[0]
        second = scored[1][0] if len(scored) > 1 else 0.0
        margin = top_score - second
        confident = top_conf or margin >= config.CONCEPT_MIN_MARGIN
        alternatives = [k for _s, k, _c in scored[1:4]]

        # reinforce the belief of the winning column (white-box, traceable)
        boost = SCORE_CONCEPT_MATCH + (1.0 if top_conf else 0.0)
        belief.observe("column", top_key, "concept_match", boost,
                       detail=f"concept '{con.phrase}' ({con.role})")
        if top_conf:
            belief.observe("value", f"{con.value}@{top_key}", "concept_value_hit",
                           3.0, detail=f"concept '{con.phrase}' literal confirmed")

        belief.concept_bindings[con.phrase] = {
            "column": top_key, "role": con.role, "value": con.value,
            "score": round(top_score, 2), "confirmed": top_conf,
            "confident": confident, "alternatives": alternatives,
        }
        if confident:
            tag = "value-confirmed" if top_conf else f"margin {margin:.1f}"
            alt = f"; over {alternatives}" if alternatives else ""
            res.hints.append(
                f"- For \"{con.phrase}\" ({con.role}) use column {top_key} ({tag}){alt}")
        else:
            res.hints.append(
                f"- \"{con.phrase}\" ({con.role}) is ambiguous: candidates "
                f"{[k for _s, k, _c in scored[:3]]} (pick by question semantics)")

    res.n_value_probes = n_probes
    res.steps.append(f"concept align finished: bound={len(belief.concept_bindings)} "
                     f"value_probes={n_probes}")
    return res
