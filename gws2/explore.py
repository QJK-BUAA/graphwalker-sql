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
import re
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
    n_column_probes: int = 0
    column_hints: list[str] = field(default_factory=list)
    steps: list[str] = field(default_factory=list)


_STOP = {"the", "a", "an", "of", "in", "on", "for", "to", "and", "or", "with",
         "what", "which", "who", "how", "many", "list", "show", "find", "all",
         "is", "are", "was", "were", "give", "me", "number", "count", "name",
         "names", "please", "that", "have", "has", "by", "from", "each", "their"}


def _tokens(text: str) -> list[str]:
    toks = re.findall(r"[A-Za-z_][A-Za-z0-9_]+", text.lower())
    return [t for t in toks if t not in _STOP and len(t) > 2]


def _q(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def _is_text_type(tp: str) -> bool:
    t = (tp or "").upper()
    return any(k in t for k in ("CHAR", "TEXT", "CLOB", "STRING", "VARCHAR"))


def _column_candidates(question: str, schema: Schema, linked_tables: list[str],
                       belief: BeliefState, literals: list[str]) -> list[tuple[str, str]]:
    """Pick a bounded set of columns whose semantics are worth probing.

    Preference order: columns already believed relevant, name-overlap columns,
    and text columns when the question contains filter literals. This keeps the
    probe cheap while targeting the BIRD failure mode: same concept across
    multiple tables/columns.
    """
    qtokens = set(_tokens(question))
    out: list[tuple[float, str, str]] = []
    seen = set()
    for t in linked_tables:
        for c in schema.tables.get(t, []):
            key = f"{t}.{c.name}"
            if key in seen:
                continue
            seen.add(key)
            ctoks = set(re.split(r"[_\s]+", c.name.lower()))
            name_hit = bool(qtokens & ctoks or any(tok in c.name.lower()
                                                   for tok in qtokens))
            bscore = belief.columns.get(key).score if key in belief.columns else 0.0
            text_bonus = 0.75 if literals and _is_text_type(c.type) else 0.0
            score = bscore + (2.0 if name_hit else 0.0) + text_bonus
            if score > 0:
                out.append((score, t, c.name))
    out.sort(key=lambda x: x[0], reverse=True)
    return [(t, c) for _s, t, c in out[:config.COLUMN_PROBE_MAX_COLUMNS]]


def _column_profile(sqlite_path: str, table: str, column: str) -> dict:
    col = _q(column)
    tab = _q(table)
    stats_sql = (f"SELECT COUNT(*) AS n_rows, COUNT({col}) AS n_nonnull, "
                 f"COUNT(DISTINCT {col}) AS n_distinct FROM {tab}")
    stats = run_query(sqlite_path, stats_sql, max_rows=1,
                      timeout=config.COLUMN_PROBE_TIMEOUT)
    if not stats.get("ok") or not stats.get("rows"):
        return {"ok": False, "error": stats.get("error", "empty stats")}
    n_rows, n_nonnull, n_distinct = stats["rows"][0]
    sample_sql = (f"SELECT DISTINCT {col} FROM {tab} WHERE {col} IS NOT NULL "
                  f"LIMIT {config.COLUMN_PROBE_SAMPLE_VALUES}")
    sample = run_query(sqlite_path, sample_sql,
                       max_rows=config.COLUMN_PROBE_SAMPLE_VALUES,
                       timeout=config.COLUMN_PROBE_TIMEOUT)
    samples = [str(r[0]) for r in sample.get("rows", [])] if sample.get("ok") else []
    return {"ok": True, "n_rows": n_rows, "n_nonnull": n_nonnull,
            "n_distinct": n_distinct, "samples": samples}


def _literal_hit(sqlite_path: str, table: str, column: str, literal: str) -> bool:
    v = literal.replace("'", "''")
    col = _q(column)
    tab = _q(table)
    sql = (f"SELECT 1 FROM {tab} WHERE {col} = '{v}' "
           f"OR CAST({col} AS TEXT) LIKE '%{v}%' LIMIT 1")
    res = run_query(sqlite_path, sql, max_rows=1,
                    timeout=config.COLUMN_PROBE_TIMEOUT)
    return bool(res.get("ok") and res.get("rows"))


def _probe_columns(question: str, schema: Schema, linked_tables: list[str],
                   belief: BeliefState, sqlite_path: str,
                   literals: list[str]) -> tuple[int, list[str], list[str]]:
    """Actively refine column/value belief using cheap SQL observations."""
    if not linked_tables:
        return 0, [], ["column walk skipped: no linked tables"]
    col_ent = belief.family_entropy("column")
    candidates = _column_candidates(question, schema, linked_tables, belief, literals)
    if not candidates:
        return 0, [], ["column walk skipped: no candidate columns"]
    if col_ent < config.COLUMN_ENTROPY_PROBE and not literals:
        return 0, [], [f"column walk skipped: col entropy {col_ent:.3f} below threshold"]

    hints: list[str] = []
    steps: list[str] = [f"column walk: {len(candidates)} candidates "
                        f"col_entropy={col_ent:.3f}"]
    n_probes = 0
    literal_subset = literals[:config.COLUMN_PROBE_MAX_LITERALS]
    for table, column in candidates:
        if n_probes >= config.COLUMN_PROBE_MAX_SQL:
            steps.append(f"column walk stopped: reached SQL probe cap "
                         f"{config.COLUMN_PROBE_MAX_SQL}")
            break
        key = f"{table}.{column}"
        prof = _column_profile(sqlite_path, table, column)
        n_probes += 1
        if not prof.get("ok"):
            steps.append(f"column probe {key}: failed {prof.get('error')}")
            continue
        nonnull = prof.get("n_nonnull") or 0
        nrows = prof.get("n_rows") or 0
        distinct = prof.get("n_distinct") or 0
        samples = prof.get("samples") or []
        if nrows and nonnull:
            # A small positive observation: the column is populated and usable.
            belief.observe("column", key, "column_profile", 0.5,
                           detail=f"nonnull={nonnull}/{nrows} distinct={distinct}")

        hit_literals = []
        for lit in literal_subset:
            if n_probes >= config.COLUMN_PROBE_MAX_SQL:
                break
            n_probes += 1
            if _literal_hit(sqlite_path, table, column, lit):
                hit_literals.append(lit)
                belief.observe("value", f"{lit}@{key}", "column_probe_value_hit",
                               3.0, detail=f"literal found during Explore")
                belief.observe("column", key, "column_probe_value_hit",
                               3.0, detail=f"hosts literal '{lit}'")
        if hit_literals:
            hints.append(f"- Prefer {key} for literal filter(s) {hit_literals}; "
                         f"profile nonnull={nonnull}/{nrows}, distinct={distinct}, "
                         f"samples={samples[:3]}")
        else:
            hints.append(f"- {key}: nonnull={nonnull}/{nrows}, distinct={distinct}, "
                         f"samples={samples[:3]}")
    steps.append(f"column walk finished: sql_probes={n_probes} hints={len(hints)}")
    return n_probes, hints[:12], steps


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
            literals: list[str] | None = None,
            use_belief_walk: bool = True,
            use_topk: bool = True,
            use_probes: bool = True,
            use_entropy_stop: bool = True,
            use_column_probes: bool = True) -> ExploreResult:
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
        n_col, col_hints, col_steps = (0, [], [])
        if use_column_probes:
            n_col, col_hints, col_steps = _probe_columns(
                question, schema, linked, belief, sqlite_path, literals or [])
            steps.extend(col_steps)
        return ExploreResult(linked_tables=linked,
                             join_conditions=[f"{a}.{b} = {c}.{d}"
                                              for (a, b, c, d) in _edges_of(graph, linked)],
                             chosen_path=None, n_column_probes=n_col,
                             column_hints=col_hints, steps=steps)

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

    n_col, col_hints, col_steps = (0, [], [])
    if use_column_probes:
        n_col, col_hints, col_steps = _probe_columns(
            question, schema, chosen.tables, belief, sqlite_path, literals or [])
        steps.extend(col_steps)

    return ExploreResult(linked_tables=chosen.tables,
                         join_conditions=chosen.join_conditions(),
                         chosen_path=chosen, candidates=candidates,
                         n_probes=n_probes, n_column_probes=n_col,
                         column_hints=col_hints, steps=steps)


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
