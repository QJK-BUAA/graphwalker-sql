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
from .prompts import PROMPT_ANALYTICAL_HINT
from .schema import (Schema, collect_column_stats, extract_schema,
                     load_column_descriptions)


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
    # Point 1: query-centric concept -> column disambiguation (one extra LLM call
    # for concept extraction + bounded local value probes).
    use_concept_align: bool = True
    # Point 2a: confidence-adaptive schema exposure -- widen the generation schema
    # with bounded graph neighbours when belief is uncertain (else keep it tight).
    use_adaptive_schema: bool = True
    # Point 2b: soft skeleton -- a structural mismatch is a hint, not a forced
    # repair. Set False (hardstruct) to restore the hard structural repair gate.
    soft_structure: bool = True
    # Gate the three grounding-focused mechanisms (concept/adaptive/soft) on an
    # OBSERVABLE per-question signal: whether the schema graph is inferred
    # (FK-sparse -> grounding is the bottleneck). On declared-FK schemas the
    # pipeline already grounds tables well, so the mechanisms only add prompt
    # noise; gating them off there recovers the clean-schema accuracy while
    # keeping the FK-sparse gain. Set False (nogate) to apply them everywhere.
    gate_by_graph: bool = True
    # Multi-candidate generation + execution-result majority vote at Commit
    # (ReFoRCE/SOMA style). 1 = single SQL (default, cost-minimal). >1 trades
    # cost for robustness on hard analytical questions (Spider2).
    n_candidates: int = 1
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
                         self.use_propose, self.use_concept_align,
                         self.use_adaptive_schema, self.soft_structure,
                         self.gate_by_graph])
        variants = []
        if self.use_evidence_injection: variants.append("evidenceblock")
        if self.use_propose_evidence_gate: variants.append("propgate")
        if self.use_column_align: variants.append("colalign")
        if self.n_candidates and self.n_candidates > 1:
            variants.append(f"k{self.n_candidates}")
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
        if not self.use_concept_align: off.append("noconcept")
        if not self.use_adaptive_schema: off.append("noadaptive")
        if not self.soft_structure: off.append("hardstruct")
        if not self.gate_by_graph: off.append("nogate")
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
    n_concept_probes: int = 0
    column_hints: list[str] = field(default_factory=list)
    concept_bindings: dict = field(default_factory=dict)
    query_skeleton: dict = field(default_factory=dict)
    structural_feedback: list[str] = field(default_factory=list)
    propose_verdict: str = ""
    missing_added: list[str] = field(default_factory=list)
    missing_rejected: list[str] = field(default_factory=list)
    widened_tables: list[str] = field(default_factory=list)
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
    gen_llm: LLM | None = None,
    fewshot_retriever=None,
    fewshot_k: int = 0,
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

    # Gate the grounding-focused mechanisms (concept alignment / adaptive schema
    # widening / soft skeleton) on an OBSERVABLE per-question signal: an inferred
    # graph means the schema declares no usable FKs, i.e. grounding is genuinely
    # uncertain and these mechanisms pay off (Spider2-style). A declared-FK graph
    # (BIRD-style) already grounds well, so we keep the tight/hard behaviour there
    # to avoid the prompt noise measured in CONCEPT_ADAPTIVE_EXPERIMENT_REPORT.md.
    grounding_uncertain = graph_obj.method == "inferred"
    forced_off = ab.gate_by_graph and not grounding_uncertain
    eff_concept = ab.use_concept_align and not forced_off
    eff_adaptive = ab.use_adaptive_schema and not forced_off
    eff_soft = ab.soft_structure and not forced_off
    if ab.gate_by_graph:
        trace.append(f"gate: graph={graph_obj.method} grounding_uncertain="
                     f"{grounding_uncertain} -> concept={eff_concept} "
                     f"adaptive={eff_adaptive} soft={eff_soft}")

    anchors = anchor(question, schema, llm, evidence=evidence)
    trace.append(f"anchor: src={anchors.sources} dst={anchors.destinations} "
                 f"literals={anchors.literals}")

    belief = initialise_belief(question, schema, graph_obj, anchors, sqlite_path,
                               value_probe=ab.value_probe)
    trace.append(f"belief0: colH={belief.family_entropy('column'):.3f} "
                 f"valH={belief.family_entropy('value'):.3f}")

    # Point 1: decompose the query into concepts and bind each to its best column
    # via a white-box belief competition (reinforces column belief + hints).
    n_concept_probes = 0
    if eff_concept:
        from .concept_align import align_query_concepts
        ca = align_query_concepts(question, schema, anchors, belief, sqlite_path,
                                  llm, evidence=evidence)
        n_concept_probes = ca.n_value_probes
        trace.extend(f"concept: {s}" for s in ca.steps)

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

    # Retrieval-based few-shot: fetch similar solved (question -> SQL) exemplars
    # from the TRAIN split and inject them into the generation prompt (no LLM call).
    fewshot_block = ""
    if fewshot_retriever is not None and fewshot_k:
        fewshot_block = fewshot_retriever.block(question, fewshot_k)
        if fewshot_block:
            trace.append(f"fewshot: injected {fewshot_k} retrieved exemplars")
    # On FK-sparse / inferred-graph schemas (Spider2-like), the gold SQL is a
    # multi-step CTE pipeline, so nudge the generator toward that shape. Gated OFF
    # on declared-FK schemas (BIRD/Spider1) to avoid over-complicating simpler queries.
    if grounding_uncertain:
        fewshot_block = ((PROMPT_ANALYTICAL_HINT + "\n\n" + fewshot_block)
                         if fewshot_block else PROMPT_ANALYTICAL_HINT)
        trace.append("analytical: CTE-pipeline guidance (inferred graph)")

    cm = commit(q_for_gen, schema, graph_obj, ex_res, belief, sqlite_path, llm,
                dialect=dialect, schema_context=schema_context,
                use_propose=ab.use_propose, max_repairs=ab.max_repairs,
                allow_repair_on_empty=ab.repair_on_empty,
                evidence=evidence, use_evidence_injection=ab.use_evidence_injection,
                use_column_align=ab.use_column_align,
                use_propose_evidence_gate=ab.use_propose_evidence_gate,
                use_structure_plan=ab.use_structure_plan,
                concept_bindings=belief.concept_bindings,
                use_adaptive_schema=eff_adaptive,
                soft_structure=eff_soft,
                n_candidates=ab.n_candidates,
                gen_llm=gen_llm,
                fewshot_block=fewshot_block)
    trace.extend(f"commit: {s}" for s in cm.steps)

    return GWSResult(
        question=question, db_id=schema.name, graph_method=graph_obj.method,
        n_edges=graph_obj.n_edges, sources=anchors.sources,
        destinations=anchors.destinations, literals=anchors.literals,
        linked_tables=cm.linked_tables, join_conditions=cm.join_conditions,
        chosen_path=ex_res.chosen_path.tables if ex_res.chosen_path else [],
        n_probes=ex_res.n_probes, n_column_probes=ex_res.n_column_probes,
        n_concept_probes=n_concept_probes,
        column_hints=ex_res.column_hints,
        concept_bindings=belief.concept_bindings,
        query_skeleton=cm.query_skeleton,
        structural_feedback=cm.structural_feedback,
        propose_verdict=cm.propose_verdict,
        missing_added=cm.missing_added, missing_rejected=cm.missing_rejected,
        widened_tables=cm.widened_tables,
        repaired=cm.repaired, sql=cm.sql, execution=cm.execution,
        belief_entropy={
            "columns": round(belief.family_entropy("column"), 4),
            "values": round(belief.family_entropy("value"), 4),
            "paths": round(belief.family_entropy("path"), 4),
        },
        belief_snapshot=belief.snapshot() if with_snapshot else {},
        trace=trace,
    )


def load_db(sqlite_path: str, with_stats: bool = True,
            with_descriptions: bool = True) -> Schema:
    """Extract schema + (optionally) column statistics for belief scoring.

    ``with_descriptions`` loads a sibling ``database_description/`` directory
    (BIRD ships one per DB) so human column meanings + value notes reach the
    generation prompt. No-op when the directory is absent (Spider/Spider2).
    """
    schema = extract_schema(sqlite_path)
    if with_stats:
        collect_column_stats(sqlite_path, schema)
    if with_descriptions:
        import os
        desc_dir = os.path.join(os.path.dirname(sqlite_path), "database_description")
        schema.descriptions = load_column_descriptions(desc_dir)
    return schema
