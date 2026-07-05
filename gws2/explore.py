"""Explore phase: belief-guided walk + path disambiguation (HTML sections 3, 6).

Given the anchored source/destination tables and the confidence graph, the
Explore phase resolves the join path. Its cost-control discipline (HTML section 6):

  * enumerate at most top-k shortest paths (k=3), length-capped (<= MAX_PATH_EDGES);
  * seed each path's belief from its edge confidences (graph prior);
  * fire an *execution probe* ONLY when path-belief entropy is high (ambiguous)
    -- if Top-1 already leads by a clear margin, commit without probing;
  * each probe is a lightweight LIMITed COUNT join, never a full candidate SQL;
  * a non-empty probe with sane cardinality is +3 belief, an empty probe is -3.

The reward gate R = info_gain - lambda * cost decides whether an extra probe is
worth it, and entropy decides when to stop (HTML section 2, R and the stop rule).
"""
from __future__ import annotations

import itertools
from dataclasses import dataclass, field

import networkx as nx

from . import config
from .belief import (SCORE_GRAPH_PRIOR, SCORE_PROBE_EMPTY, SCORE_PROBE_NONEMPTY,
                     BeliefState, entropy)
from .execute import run_query
from .graph_builder import SchemaGraph
from .llm import LLM
from .prompts import PROMPT_PATH_SELECT
from .schema import Schema


@dataclass
class PathCandidate:
    pid: str
    tables: list[str]
    edges: list[tuple]              # (t1, c1, t2, c2)
    conf: float                     # product of edge confidences (graph prior)
    probe: dict | None = None       # execution-probe summary, if run

    def join_conditions(self) -> list[str]:
        return [f"{t1}.{c1} = {t2}.{c2}" for (t1, c1, t2, c2) in self.edges]


@dataclass
class ExploreResult:
    linked_tables: list[str]
    join_conditions: list[str]
    chosen_path: PathCandidate | None
    candidates: list[PathCandidate] = field(default_factory=list)
    n_probes: int = 0
    steps: list[str] = field(default_factory=list)


def _edges_of(graph: nx.Graph, tables: list[str]) -> list[tuple]:
    """All join tuples among a set of tables (for multi-table union paths)."""
    sel = set(tables)
    seen, out = set(), []
    for u, v, data in graph.edges(data=True):
        if u in sel and v in sel:
            for tup in data.get("joins", []):
                if tup not in seen:
                    seen.add(tup)
                    out.append(tup)
    return out


def _path_edges(graph: nx.Graph, node_path: list[str]) -> tuple[list[tuple], float]:
    """Resolve a node sequence into concrete join tuples + confidence product."""
    edges, conf = [], 1.0
    for a, b in zip(node_path, node_path[1:]):
        data = graph[a][b]
        joins = data.get("joins", [])
        edges.append(joins[0] if joins else (a, "?", b, "?"))
        conf *= data.get("confidence", 0.5)
    return edges, conf


def _k_shortest(graph: nx.Graph, src: str, dst: str, k: int,
                max_len: int) -> list[list[str]]:
    if src not in graph or dst not in graph or src == dst:
        return []
    out = []
    try:
        # shortest_simple_paths is a generator: NetworkXNoPath is raised on
        # iteration (not at creation), so the loop itself must be guarded.
        for path in nx.shortest_simple_paths(graph, src, dst, weight="weight"):
            if len(path) - 1 > max_len:
                continue
            out.append(path)
            if len(out) >= k:
                break
    except (nx.NetworkXNoPath, nx.NodeNotFound):
        return out
    return out


def _probe_join(sqlite_path: str, cand: PathCandidate) -> dict:
    """Lightweight join-validity probe (HTML section 6): LIMITed COUNT.

    Only checks whether the path yields rows with sane cardinality; it does NOT
    generate a full answer SQL. Returns {ok, nonempty, count}.
    """
    if not cand.edges:
        return {"ok": True, "nonempty": True, "count": None, "note": "single table"}
    tables = cand.tables
    from_sql = f'"{tables[0]}"'
    for (t1, c1, t2, c2) in cand.edges:
        from_sql += f' JOIN "{t2}" ON "{t1}"."{c1}" = "{t2}"."{c2}"'
    sql = (f"SELECT COUNT(*) AS n FROM (SELECT 1 FROM {from_sql} "
           f"LIMIT {config.PROBE_LIMIT})")
    res = run_query(sqlite_path, sql, max_rows=1, timeout=15.0)
    if not res.get("ok"):
        return {"ok": False, "nonempty": False, "count": 0, "error": res.get("error")}
    n = res["rows"][0][0] if res.get("rows") else 0
    return {"ok": True, "nonempty": n > 0, "count": n}


def explore(question: str, schema: Schema, graph_obj: SchemaGraph,
            sources: list[str], destinations: list[str],
            belief: BeliefState, sqlite_path: str, llm: LLM,
            use_belief_walk: bool = True,
            use_topk: bool = True,
            use_probes: bool = True,
            use_entropy_stop: bool = True) -> ExploreResult:
    """Resolve the join path under belief guidance + cost-bounded probing."""
    graph = graph_obj.graph
    steps: list[str] = []
    src_set = sources or destinations
    dst_set = destinations or sources
    if not src_set:
        src_set = dst_set = schema.table_names()[:1]

    # ---- enumerate candidate paths over all (src, dst) anchor pairs -------- #
    raw_paths: list[list[str]] = []
    k = config.TOPK_PATHS if use_topk else 1
    for s, d in itertools.product(src_set, dst_set):
        if s == d:
            raw_paths.append([s])
            continue
        raw_paths.extend(_k_shortest(graph, s, d, k, config.MAX_PATH_EDGES))

    # de-dup node sequences
    uniq, seen = [], set()
    for p in raw_paths:
        key = tuple(p)
        if key not in seen:
            seen.add(key)
            uniq.append(p)

    # Fallback: anchors not connected -> just use the union of anchor tables.
    if not uniq:
        linked = sorted(set(src_set) | set(dst_set))
        steps.append(f"no path between anchors; union fallback -> {linked}")
        return ExploreResult(linked_tables=linked,
                             join_conditions=[f"{a}.{b} = {c}.{d}"
                                              for (a, b, c, d) in _edges_of(graph, linked)],
                             chosen_path=None, steps=steps)

    # ---- build candidates + seed path belief from edge confidence ---------- #
    candidates: list[PathCandidate] = []
    for i, node_path in enumerate(uniq):
        edges, conf = _path_edges(graph, node_path)
        cand = PathCandidate(pid=f"P{i}", tables=list(node_path),
                             edges=edges, conf=conf)
        candidates.append(cand)
        belief.observe("path", cand.pid, "graph_prior",
                       SCORE_GRAPH_PRIOR * (1.0 + conf),
                       detail=f"{'->'.join(node_path)} conf={conf:.2f}")

    if not use_belief_walk:
        # Ablation: greedy single shortest path, no probing / no LLM selection.
        chosen = candidates[0]
        steps.append(f"[w/o belief walk] greedy shortest -> {chosen.tables}")
        return ExploreResult(linked_tables=chosen.tables,
                             join_conditions=chosen.join_conditions(),
                             chosen_path=chosen, candidates=candidates, steps=steps)

    # ---- cost-bounded probing on high-entropy path belief ------------------ #
    n_probes = 0
    path_ent = belief.family_entropy("path")
    gap = belief.top_gap("path")
    steps.append(f"path entropy={path_ent:.3f} top_gap={gap:.2f} "
                 f"({len(candidates)} candidates)")

    ambiguous = (len(candidates) > 1 and
                 (path_ent >= config.PATH_ENTROPY_PROBE or gap < SCORE_GRAPH_PRIOR))
    if use_probes and ambiguous:
        for step in range(min(config.MAX_EXPLORE_STEPS, len(candidates))):
            # reward gate: is another probe worth its cost?
            info_gain = belief.family_entropy("path")
            if use_entropy_stop and info_gain - config.LAMBDA_COST * n_probes <= 0:
                steps.append(f"stop: info_gain {info_gain:.3f} "
                             f"< cost {config.LAMBDA_COST * n_probes:.3f}")
                break
            # probe the currently-most-uncertain unprobed candidate (highest prior)
            unprobed = [c for c in candidates if c.probe is None]
            if not unprobed:
                break
            cand = max(unprobed, key=lambda c: c.conf)
            cand.probe = _probe_join(sqlite_path, cand)
            n_probes += 1
            if cand.probe.get("ok") and cand.probe.get("nonempty"):
                belief.observe("path", cand.pid, "exec_probe", SCORE_PROBE_NONEMPTY,
                               detail=f"probe rows={cand.probe.get('count')}")
            else:
                belief.observe("path", cand.pid, "exec_probe", SCORE_PROBE_EMPTY,
                               detail=f"probe empty/failed")
            steps.append(f"probe {cand.pid} {cand.tables}: {cand.probe}")
            if use_entropy_stop and belief.top_gap("path") >= SCORE_PROBE_NONEMPTY:
                steps.append("stop: Top-1 path now clearly leads")
                break
    else:
        steps.append("no probe: Top-1 path confident or probing disabled")

    # ---- select path: belief MAP, tie-broken by the LLM on semantics ------- #
    ranked = sorted(candidates, key=lambda c: belief.paths[c.pid].score, reverse=True)
    chosen = ranked[0]
    if len(ranked) > 1 and belief.top_gap("path") < 1.0:
        chosen = _llm_pick(question, ranked[:config.TOPK_PATHS], llm) or chosen
        steps.append(f"LLM tie-break -> {chosen.pid} {chosen.tables}")

    return ExploreResult(linked_tables=chosen.tables,
                         join_conditions=chosen.join_conditions(),
                         chosen_path=chosen, candidates=candidates,
                         n_probes=n_probes, steps=steps)


def _llm_pick(question: str, cands: list[PathCandidate], llm: LLM) -> PathCandidate | None:
    lines = []
    for c in cands:
        probe = ""
        if c.probe:
            probe = (f" | probe: {'nonempty' if c.probe.get('nonempty') else 'EMPTY'}"
                     f" ({c.probe.get('count')})")
        lines.append(f"{c.pid}: {' -> '.join(c.tables)} | joins: "
                     f"{'; '.join(c.join_conditions()) or '(single table)'}{probe}")
    user = f"Question: {question}\n\nCandidate join paths:\n" + "\n".join(lines)
    resp = llm.complete(PROMPT_PATH_SELECT, user, temperature=0.0)
    import re
    m = re.search(r"path\s*=\s*(P?\d+)", resp, re.I)
    if not m:
        return None
    pid = m.group(1)
    if not pid.upper().startswith("P"):
        pid = "P" + pid
    for c in cands:
        if c.pid.lower() == pid.lower():
            return c
    return None
