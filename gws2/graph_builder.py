"""Ground phase, part 1: build a *confidence-weighted* schema graph (HTML section 4).

Real databases often declare no foreign keys, so GraphWalker-SQL 2.0 must build
its own joinability graph. Each candidate edge gets a confidence:

    conf(edge) = type_compatible * name_pattern * uniqueness * value_overlap * llm

(HTML section 4.2). Edges with conf >= delta enter the graph as *weighted* edges;
the weight becomes a prior on the path belief. Declared foreign keys are treated
as gold edges (conf = 1.0). The design goal (HTML "hardest part"): a graph that
is *good enough but not over-confident* -- dense enough to contain the right
path, sparse enough not to drown it in wrong ones.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from difflib import SequenceMatcher

import networkx as nx

from . import config
from .llm import LLM
from .prompts import PROMPT_JOINABILITY
from .schema import ForeignKey, Schema
from .value_overlap import overlap_ratio


# --------------------------------------------------------------------------- #
# Edge with provenance + white-box confidence factors.
# --------------------------------------------------------------------------- #
@dataclass
class Edge:
    fk: ForeignKey
    tier: str                       # "gold" | "inferred_strong" | "inferred_weak"
    confidence: float
    factors: dict = field(default_factory=dict)

    def join_cond(self) -> str:
        f = self.fk
        return f"{f.src_table}.{f.src_column} = {f.ref_table}.{f.ref_column}"


@dataclass
class SchemaGraph:
    graph: nx.Graph
    edges: list[Edge]
    method: str                     # "declared" | "inferred"
    rejected: list[tuple] = field(default_factory=list)

    @property
    def n_edges(self) -> int:
        return self.graph.number_of_edges()


def _norm_type(t: str) -> str:
    t = (t or "").upper()
    if any(k in t for k in ("INT", "NUMBER", "REAL", "FLOA", "DOUB", "DEC", "NUMERIC")):
        return "NUMERIC"
    if any(k in t for k in ("CHAR", "TEXT", "CLOB", "STRING")):
        return "TEXT"
    if "DATE" in t or "TIME" in t:
        return "DATETIME"
    return t or "ANY"


def _lex(a: str, b: str) -> float:
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()


# ------- white-box confidence factors (each in [0, 1]) --------------------- #
def _type_compat(schema: Schema, fk: ForeignKey) -> float:
    sc = schema.column(fk.src_table, fk.src_column)
    rc = schema.column(fk.ref_table, fk.ref_column)
    if sc is None or rc is None:
        return 0.0
    return 1.0 if _norm_type(sc.type) == _norm_type(rc.type) else 0.0


def _name_pattern(fk: ForeignKey) -> float:
    """How key-like and how lexically aligned the pair looks."""
    sc, rc = fk.src_column.lower(), fk.ref_column.lower()
    key_like = any(c.endswith("id") or c.endswith("_key") or c == "id"
                   or "code" in c for c in (sc, rc))
    stem = re.sub(r"(_id|id|_key|_code|code)$", "", sc)
    lex = max(_lex(stem, fk.ref_table), _lex(fk.src_column, fk.ref_column),
              _lex(fk.src_column, fk.ref_table))
    contained = 1.0 if stem and stem in fk.ref_table.lower() else 0.0
    base = 0.5 * (1.0 if key_like else 0.0) + 0.5 * max(lex, contained)
    return max(0.05, min(1.0, base))


def _uniqueness(schema: Schema, fk: ForeignKey) -> float:
    """Referenced column should be near-unique (a key). Falls back to 0.5 when
    stats are unavailable so we neither reward nor punish blindly."""
    rc = schema.column(fk.ref_table, fk.ref_column)
    if rc is None or rc.n_rows is None:
        return 0.5
    return max(0.1, rc.uniqueness)


def build_declared(schema: Schema) -> SchemaGraph:
    edges: list[Edge] = []
    for fk in schema.declared_fks:
        edges.append(Edge(fk=fk, tier="gold", confidence=1.0,
                          factors={"declared": 1.0}))
    return SchemaGraph(_assemble(schema, edges), edges, method="declared")


_FK_LINE = re.compile(
    r"^\s*([\w\"`.]+)\s*\.\s*([\w\"`]+)\s*->\s*([\w\"`.]+)\s*\.\s*([\w\"`]+)\s*$"
)


def _clean(x: str) -> str:
    return x.strip().strip('"`')


def parse_joinability(text: str, schema: Schema) -> list[ForeignKey]:
    valid = {t.lower(): t for t in schema.table_names()}
    out: list[ForeignKey] = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.upper() == "NONE":
            continue
        m = _FK_LINE.match(line)
        if not m:
            continue
        st, sc, rt, rc = (_clean(x) for x in m.groups())
        st, rt = st.split(".")[-1], rt.split(".")[-1]
        if st.lower() not in valid or rt.lower() not in valid:
            continue
        out.append(ForeignKey(valid[st.lower()], sc, valid[rt.lower()], rc))
    return out


def build_inferred(schema: Schema, sqlite_path: str, llm: LLM,
                   value_verify: bool = True,
                   delta: float = config.EDGE_CONF_THRESHOLD) -> SchemaGraph:
    """LLM-guided joinability discovery + white-box confidence scoring."""
    raw = llm.complete(PROMPT_JOINABILITY, schema.to_ddl_text(), temperature=0.0)
    candidates = parse_joinability(raw, schema)

    edges: list[Edge] = []
    rejected: list[tuple] = []
    for fk in candidates:
        # column existence
        if schema.column(fk.src_table, fk.src_column) is None or \
                schema.column(fk.ref_table, fk.ref_column) is None:
            rejected.append((fk.__dict__, "column not found"))
            continue
        f_type = _type_compat(schema, fk)
        if f_type == 0.0:
            rejected.append((fk.__dict__, "type incompatible"))
            continue
        f_name = _name_pattern(fk)
        f_uniq = _uniqueness(schema, fk)
        f_llm = 0.85           # edge proposed by the LLM -> strong prior
        f_val = 1.0
        if value_verify:
            ratio = overlap_ratio(sqlite_path, fk,
                                   sample=config.VALUE_OVERLAP_SAMPLE)
            # map containment ratio to a soft [0.2, 1.0] factor
            f_val = 0.2 + 0.8 * max(0.0, min(1.0, ratio))
        conf = f_type * f_name * f_uniq * f_val * f_llm
        if conf < delta:
            rejected.append((fk.__dict__, f"low confidence {conf:.2f}"))
            continue
        tier = "inferred_strong" if conf >= 0.55 else "inferred_weak"
        edges.append(Edge(fk=fk, tier=tier, confidence=round(conf, 4),
                          factors={"type": f_type, "name": round(f_name, 3),
                                   "uniqueness": round(f_uniq, 3),
                                   "value_overlap": round(f_val, 3), "llm": f_llm}))
    return SchemaGraph(_assemble(schema, edges), edges, method="inferred",
                       rejected=rejected)


def _assemble(schema: Schema, edges: list[Edge]) -> nx.Graph:
    g = nx.Graph()
    for t in schema.table_names():
        g.add_node(t)
    for e in edges:
        fk = e.fk
        if fk.src_table == fk.ref_table:
            continue
        if fk.src_table not in g or fk.ref_table not in g:
            continue
        if g.has_edge(fk.src_table, fk.ref_table):
            data = g[fk.src_table][fk.ref_table]
            data["joins"].append((fk.src_table, fk.src_column,
                                  fk.ref_table, fk.ref_column))
            data["confidence"] = max(data["confidence"], e.confidence)
            # edge traversal weight: high confidence -> low cost
            data["weight"] = 1.0 - 0.5 * data["confidence"]
        else:
            g.add_edge(fk.src_table, fk.ref_table,
                       joins=[(fk.src_table, fk.src_column,
                               fk.ref_table, fk.ref_column)],
                       confidence=e.confidence,
                       tier=e.tier,
                       weight=1.0 - 0.5 * e.confidence)
    return g


def build_schema_graph(schema: Schema, sqlite_path: str, llm: LLM,
                       prefer_declared: bool = True,
                       value_verify: bool = True) -> SchemaGraph:
    """Ground the graph: declared FKs if present, else inferred joinability.

    ``prefer_declared=False`` forces the inferred path even when FKs exist -- used
    for the *w/o inferred graph* ablation's counterpart and for BIRD force-infer.
    """
    if prefer_declared and schema.has_declared_fks:
        return build_declared(schema)
    return build_inferred(schema, sqlite_path, llm, value_verify=value_verify)
