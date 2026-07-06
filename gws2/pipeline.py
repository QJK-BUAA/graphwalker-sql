"""GraphWalker-SQL 2.0 pipeline: Ground -> Explore -> Commit.

This is the single entry point that stitches the three phases around one shared
belief state. It exposes an ``AblationConfig`` implementing the paper's required
ablations (HTML section 8):

    w/o Inferred Graph   -> no LLM joinability discovery on FK-sparse schemas
    w/o Belief Walk      -> greedy single shortest path
    w/o Top-k Path       -> k = 1
    w/o Propose          -> skip the evidence checkpoint
    w/o Entropy Stop     -> fixed-budget exploration (no cost-gated early stop)

The core is kept deliberately pure: exactly one SQL is produced, and repair is
capped at one targeted attempt (no unbounded self-refine, no full-schema
fallback), so each ablation isolates one component's contribution.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass, field

from .belief import BeliefState
from .commit import commit
from .explore import explore
from .graph_builder import build_schema_graph
from .ground import anchor, initialise_belief
from .llm import LLM
from .schema import Schema, collect_column_stats, extract_schema


@dataclass
class AblationConfig:
    use_inferred_graph: bool = True   # allow LLM joinability on FK-sparse schemas
    use_belief_walk: bool = True      # belief-guided exploration vs greedy shortest
    use_topk: bool = True             # top-k paths vs single shortest
    use_probes: bool = True           # conditional execution probes
    use_column_probes: bool = True    # active column/value SQL probes in Explore
    use_structure_plan: bool = True   # query skeleton before SQL generation
    use_entropy_stop: bool = True     # cost-gated early stop
    use_propose: bool = True          # evidence checkpoint before generation
    # Optional variant: require join evidence for Propose-added tables. BIRD n=100
    # rerun was slightly negative (47 vs 48), so keep it as an ablation rather
    # than the default method.
    use_propose_evidence_gate: bool = False
    value_verify: bool = True         # data-level value-overlap for inferred edges
    value_probe: bool = True          # probe literals against columns in Ground
    max_repairs: int = 1              # targeted repairs in Commit (0 disables)
    repair_on_empty: bool = True
    # Empirically (BIRD n=100): a dedicated evidence *block* + mined hints scored
    # WORSE (44%) than simply folding evidence into the question (48%). So the
    # default is the fold approach; set True to reproduce the ablation.
    use_evidence_injection: bool = False  # dedicated evidence block + evidence-mined hints
    # Column alignment: trim/reorder the SELECT list to exactly what the question
    # asks (BIRD grades whole rows). Off by default; enable via --ablation colalign.
    use_column_align: bool = False

    def tag(self) -> str:
        # Core "full" pipeline = all belief/graph components ON. Evidence-block,
        # Propose-gating and column-alignment are opt-in variants reported as
        # suffixes because full-run evidence did not support making them default.
        core_full = all([self.use_inferred_graph, self.use_belief_walk,
                         self.use_topk, self.use_probes, self.use_column_probes,
                         self.use_structure_plan, self.use_entropy_stop,
                         self.use_propose])
        variants = []
        if self.use_evidence_injection: variants.append("evidenceblock")
        if self.use_propose_evidence_gate: variants.append("propgate")
        if self.use_column_align: variants.append("colalign")
        if core_full:
            return "+".join(variants) if variants else "full"
        off = []
        if not self.use_inferred_graph: off.append("noinfer")
        if not self.use_belief_walk: off.append("nowalk")
        if not self.use_topk: off.append("notopk")
        if not self.use_probes: off.append("noprobe")
        if not self.use_column_probes: off.append("nocolprobe")
        if not self.use_structure_plan: off.append("nostruct")
        if not self.use_entropy_stop: off.append("nostop")
        if not self.use_propose: off.append("nopropose")
        return "+".join(off + variants) if (off or variants) else "full"


@dataclass
class GWSResult:
    question: str
    db_id: str
    graph_method: str
    n_edges: int
    sources: list[str] = field(default_factory=list)
    destinations: list[str] = field(default_factory=list)
    literals: list[str] = field(default_factory=list)
    linked_tables: list[str] = field(default_factory=list)
    join_conditions: list[str] = field(default_factory=list)
    chosen_path: list[str] = field(default_factory=list)
    n_probes: int = 0
    n_column_probes: int = 0
    column_hints: list[str] = field(default_factory=list)
    query_skeleton: dict = field(default_factory=dict)
    structural_feedback: list[str] = field(default_factory=list)
    propose_verdict: str = ""
    missing_added: list[str] = field(default_factory=list)
    missing_rejected: list[str] = field(default_factory=list)
    repaired: bool = False
    sql: str = ""
    execution: dict = field(default_factory=dict)
    belief_entropy: dict = field(default_factory=dict)
    belief_snapshot: dict = field(default_factory=dict)
    trace: list[str] = field(default_factory=list)


def run_pipeline(
    schema: Schema,
    sqlite_path: str,
    question: str,
    llm: LLM,
    evidence: str = "",
    ablation: AblationConfig | None = None,
    dialect: str = "SQLite",
    schema_context: str | None = None,
    prefer_declared: bool = True,
    with_snapshot: bool = False,
) -> GWSResult:
    ab = ablation or AblationConfig()
    trace: list[str] = []

    # ------------------------------------------------------------------ Ground
    graph_obj = build_schema_graph(
        schema, sqlite_path, llm,
        prefer_declared=prefer_declared,
        value_verify=ab.value_verify,
    )
    # w/o inferred graph: if the schema has no declared FKs and inference is off,
    # strip inferred edges (nodes only) to expose the ablation impact.
    if not ab.use_inferred_graph and graph_obj.method == "inferred":
        for u, v in list(graph_obj.graph.edges()):
            graph_obj.graph.remove_edge(u, v)
        graph_obj.edges = []
        trace.append("[w/o inferred graph] edges removed")
    trace.append(f"ground: graph={graph_obj.method} edges={graph_obj.n_edges}")

    anchors = anchor(question, schema, llm, evidence=evidence)
    trace.append(f"anchor: src={anchors.sources} dst={anchors.destinations} "
                 f"literals={anchors.literals}")

    belief = initialise_belief(question, schema, graph_obj, anchors, sqlite_path,
                               value_probe=ab.value_probe)
    trace.append(f"belief0: colH={belief.family_entropy('column'):.3f} "
                 f"valH={belief.family_entropy('value'):.3f}")

    # ----------------------------------------------------------------- Explore
    ex_res = explore(question, schema, graph_obj, anchors.sources,
                     anchors.destinations, belief, sqlite_path, llm,
                     literals=anchors.literals,
                     use_belief_walk=ab.use_belief_walk, use_topk=ab.use_topk,
                     use_probes=ab.use_probes, use_entropy_stop=ab.use_entropy_stop,
                     use_column_probes=ab.use_column_probes)
    trace.extend(f"explore: {s}" for s in ex_res.steps)

    # ------------------------------------------------------------------ Commit
    # When evidence injection is ON, keep the question clean and pass evidence
    # through the dedicated prompt block; when OFF, fold it into the question so
    # the information is not simply lost (legacy behaviour, for the ablation).
    if ab.use_evidence_injection:
        q_for_gen = question
    else:
        q_for_gen = (question + (f"\nExternal knowledge: {evidence}"
                                 if evidence else "")).strip()
    cm = commit(q_for_gen, schema, graph_obj, ex_res, belief, sqlite_path, llm,
                dialect=dialect, schema_context=schema_context,
                use_propose=ab.use_propose, max_repairs=ab.max_repairs,
                allow_repair_on_empty=ab.repair_on_empty,
                evidence=evidence, use_evidence_injection=ab.use_evidence_injection,
                use_column_align=ab.use_column_align,
                use_propose_evidence_gate=ab.use_propose_evidence_gate,
                use_structure_plan=ab.use_structure_plan)
    trace.extend(f"commit: {s}" for s in cm.steps)

    return GWSResult(
        question=question, db_id=schema.name, graph_method=graph_obj.method,
        n_edges=graph_obj.n_edges, sources=anchors.sources,
        destinations=anchors.destinations, literals=anchors.literals,
        linked_tables=cm.linked_tables, join_conditions=cm.join_conditions,
        chosen_path=ex_res.chosen_path.tables if ex_res.chosen_path else [],
        n_probes=ex_res.n_probes, n_column_probes=ex_res.n_column_probes,
        column_hints=ex_res.column_hints, query_skeleton=cm.query_skeleton,
        structural_feedback=cm.structural_feedback,
        propose_verdict=cm.propose_verdict,
        missing_added=cm.missing_added, missing_rejected=cm.missing_rejected,
        repaired=cm.repaired, sql=cm.sql, execution=cm.execution,
        belief_entropy={
            "columns": round(belief.family_entropy("column"), 4),
            "values": round(belief.family_entropy("value"), 4),
            "paths": round(belief.family_entropy("path"), 4),
        },
        belief_snapshot=belief.snapshot() if with_snapshot else {},
        trace=trace,
    )


def load_db(sqlite_path: str, with_stats: bool = True) -> Schema:
    """Extract schema + (optionally) column statistics for belief scoring."""
    schema = extract_schema(sqlite_path)
    if with_stats:
        collect_column_stats(sqlite_path, schema)
    return schema
