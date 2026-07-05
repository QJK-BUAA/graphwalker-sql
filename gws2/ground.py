"""Ground phase, part 2: anchoring + belief initialisation (HTML section 3, Ground).

After the schema graph is built, the Ground phase:
  1. asks the LLM for a light intent decomposition -> source/destination tables
     and candidate filter literals (POMDP actions SearchColumn / SearchValue);
  2. seeds the belief state b0 with white-box evidence:
       * name-match scores for columns whose names align with question tokens;
       * value-hit scores for literals actually found in a column's cells;
       * uniqueness scores for key-like columns;
       * graph-prior scores for edges already in the confidence graph.

No SQL is written here; the phase only *initialises belief*.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

from .belief import (SCORE_GRAPH_PRIOR, SCORE_NAME_MATCH, SCORE_UNIQUE,
                     SCORE_VALUE_HIT, BeliefState)
from .execute import scalar
from .graph_builder import SchemaGraph
from .llm import LLM
from .prompts import PROMPT_ANCHOR
from .schema import Schema

_STOP = {"the", "a", "an", "of", "in", "on", "for", "to", "and", "or", "with",
         "what", "which", "who", "how", "many", "list", "show", "find", "all",
         "is", "are", "was", "were", "give", "me", "number", "count", "name",
         "names", "please", "that", "have", "has", "by", "from", "each", "their"}


@dataclass
class Anchors:
    sources: list[str] = field(default_factory=list)
    destinations: list[str] = field(default_factory=list)
    literals: list[str] = field(default_factory=list)
    raw: str = ""


def _tokens(question: str) -> list[str]:
    toks = re.findall(r"[A-Za-z_][A-Za-z0-9_]+", question.lower())
    return [t for t in toks if t not in _STOP and len(t) > 2]


def anchor(question: str, schema: Schema, llm: LLM,
           evidence: str = "") -> Anchors:
    """LLM intent decomposition -> src/dst tables + literal filter values."""
    user = (f"Schema:\n{schema.compact_text()}\n\n"
            f"Question: {question}"
            + (f"\nExternal knowledge: {evidence}" if evidence else ""))
    resp = llm.complete(PROMPT_ANCHOR, user, temperature=0.0)
    valid = {t.lower(): t for t in schema.table_names()}

    def parse_tables(line_key: str) -> list[str]:
        m = re.search(rf"{line_key}\s*=\s*(.*)", resp, re.I)
        if not m:
            return []
        out = []
        for tok in re.split(r"[,\s]+", m.group(1).strip()):
            key = tok.strip().strip('"`.').lower()
            if key in valid and valid[key] not in out:
                out.append(valid[key])
        return out

    literals: list[str] = []
    m = re.search(r"literals\s*=\s*(.*)", resp, re.I)
    if m:
        for tok in re.split(r"[;]", m.group(1).strip()):
            v = tok.strip().strip("'\"")
            if v and v.lower() != "(empty)" and len(v) > 0:
                literals.append(v)

    return Anchors(sources=parse_tables("src"), destinations=parse_tables("dst"),
                   literals=literals, raw=resp)


def _value_in_column(sqlite_path: str, table: str, column: str, value: str) -> bool:
    """Cheap existence probe: does `value` occur in table.column?"""
    v = value.replace("'", "''")
    # exact first, then case-insensitive LIKE for text
    sql = (f'SELECT 1 FROM "{table}" WHERE "{column}" = \'{v}\' '
           f'OR CAST("{column}" AS TEXT) LIKE \'%{v}%\' LIMIT 1')
    return scalar(sqlite_path, sql, timeout=5.0) is not None


def initialise_belief(question: str, schema: Schema, graph: SchemaGraph,
                      anchors: Anchors, sqlite_path: str,
                      value_probe: bool = True,
                      max_value_probes: int = 12) -> BeliefState:
    """Seed b0 with name-match, uniqueness, graph-prior and value-hit evidence."""
    b = BeliefState()
    qtokens = set(_tokens(question))
    anchor_tables = set(anchors.sources + anchors.destinations)

    # (1) column beliefs from name match + uniqueness -------------------------
    for t in schema.table_names():
        table_bonus = 0.5 if t in anchor_tables else 0.0
        for c in schema.tables[t]:
            key = f"{t}.{c.name}"
            cl = c.name.lower()
            ctoks = set(re.split(r"[_\s]+", cl))
            if qtokens & ctoks or any(tok in cl for tok in qtokens):
                b.observe("column", key, "name_match",
                          SCORE_NAME_MATCH + table_bonus,
                          detail=f"token overlap with question")
            if c.uniqueness >= 0.98 and (c.n_rows or 0) > 0:
                b.observe("column", key, "uniqueness", SCORE_UNIQUE,
                          detail=f"near-unique ({c.uniqueness:.2f})")

    # (2) value beliefs: probe literals against name-matched text columns ------
    if value_probe and anchors.literals:
        probes = 0
        cand_cols = [f"{t}.{c.name}" for t in (anchor_tables or schema.table_names())
                     for c in schema.tables.get(t, [])]
        for lit in anchors.literals:
            for key in cand_cols:
                if probes >= max_value_probes:
                    break
                t, col = key.split(".", 1)
                probes += 1
                if _value_in_column(sqlite_path, t, col, lit):
                    b.observe("value", f"{lit}@{key}", "value_hit", SCORE_VALUE_HIT,
                              detail=f"'{lit}' found in {key}")
                    b.observe("column", key, "value_hit", SCORE_VALUE_HIT,
                              detail=f"hosts literal '{lit}'")

    # (3) graph prior: every confident edge nudges its endpoint columns --------
    for u, v, data in graph.graph.edges(data=True):
        conf = data.get("confidence", 0.0)
        for (t1, c1, t2, c2) in data.get("joins", []):
            b.observe("column", f"{t1}.{c1}", "graph_prior",
                      SCORE_GRAPH_PRIOR * conf, detail=f"edge {u}-{v} conf={conf:.2f}")
            b.observe("column", f"{t2}.{c2}", "graph_prior",
                      SCORE_GRAPH_PRIOR * conf, detail=f"edge {u}-{v} conf={conf:.2f}")

    return b
