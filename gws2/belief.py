"""The white-box Schema Belief State (HTML section 2 and 5).

GraphWalker-SQL 2.0 treats Text-to-SQL as *belief refinement* over an uncertain
schema graph. The belief ``b`` is a posterior estimate over three latent objects:

    b(C*)  - which columns are relevant   (column belief)
    b(V*)  - which filter values are right (value belief)
    b(Pi*) - which join path is correct    (path belief)

Rather than fusing heterogeneous evidence (embeddings, BM25, uniqueness, value
coverage, execution probes) as raw probabilities -- whose scales do not match --
we use the paper's *rank-based belief* (section 5): each evidence source emits a
small discrete score, and the belief of a hypothesis is the sum of its scores.
This is deliberately white-box: every number is traceable to a named signal.

Entropy over the (softmax-normalised) scores drives the two gating decisions:
  * Explore only where belief entropy is high (uncertain).
  * Stop when entropy is low or an extra probe is not worth its cost.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

# --------------------------------------------------------------------------- #
# Discrete evidence levels (HTML section 5 table). Positive = supports the
# hypothesis, negative = contradicts it. `type_incompatible` filters instead.
# --------------------------------------------------------------------------- #
SCORE_NAME_MATCH = 2.0          # column/table name strongly matches question term
SCORE_VALUE_HIT = 3.0           # a question literal is found in the column's cells
SCORE_UNIQUE = 2.0              # target column is near-unique (key-like)
SCORE_GRAPH_PRIOR = 1.0         # edge came from a declared/high-conf inferred edge
SCORE_PROBE_NONEMPTY = 3.0      # execution probe returns rows with sane cardinality
SCORE_PROBE_EMPTY = -3.0        # execution probe returns empty -> path likely wrong
SCORE_TYPE_FIT = 1.0            # source/target types are compatible
SCORE_CONCEPT_MATCH = 2.5       # a question concept resolved to its best column


@dataclass
class Evidence:
    """One piece of white-box evidence attached to a hypothesis."""
    source: str          # e.g. "name_match", "value_hit", "exec_probe"
    score: float
    detail: str = ""


@dataclass
class Hypothesis:
    """A belief-carrying hypothesis (a column, a value binding, or a join path)."""
    key: str
    evidence: list[Evidence] = field(default_factory=list)

    @property
    def score(self) -> float:
        return sum(e.score for e in self.evidence)

    def add(self, source: str, score: float, detail: str = "") -> None:
        self.evidence.append(Evidence(source, score, detail))

    def explain(self) -> str:
        parts = [f"{e.source}({e.score:+g})" for e in self.evidence]
        return f"{self.key}: {self.score:+g}  [{', '.join(parts)}]"


def _softmax(scores: list[float], temp: float = 1.0) -> list[float]:
    if not scores:
        return []
    m = max(scores)
    exps = [math.exp((s - m) / max(temp, 1e-6)) for s in scores]
    z = sum(exps) or 1.0
    return [e / z for e in exps]


def entropy(scores: list[float], temp: float = 1.0) -> float:
    """Shannon entropy (bits) of the softmax distribution over `scores`.

    High entropy = the belief cannot yet separate the candidates -> explore.
    A single candidate (or none) has entropy 0.
    """
    if len(scores) <= 1:
        return 0.0
    p = _softmax(scores, temp=temp)
    return -sum(pi * math.log(pi + 1e-12, 2) for pi in p if pi > 0)


@dataclass
class BeliefState:
    """Container of the three belief families plus a running trace."""
    columns: dict[str, Hypothesis] = field(default_factory=dict)   # "table.col"
    values: dict[str, Hypothesis] = field(default_factory=dict)    # literal string
    paths: dict[str, Hypothesis] = field(default_factory=dict)     # path id
    # Query-centric concept -> column bindings (Point 1). Auditable record of the
    # per-concept belief competition: {concept: {column, role, score, confirmed,
    # alternatives}}. Written by concept_align, read by Commit's grounding hints.
    concept_bindings: dict[str, dict] = field(default_factory=dict)
    trace: list[str] = field(default_factory=list)

    # -- generic helpers ---------------------------------------------------- #
    def _bucket(self, family: str) -> dict[str, Hypothesis]:
        return {"column": self.columns, "value": self.values, "path": self.paths}[family]

    def observe(self, family: str, key: str, source: str, score: float,
                detail: str = "") -> None:
        """Record one observation, updating the hypothesis' belief (HTML: b update)."""
        bucket = self._bucket(family)
        h = bucket.setdefault(key, Hypothesis(key=key))
        h.add(source, score, detail)
        self.trace.append(f"[{family}] {key} += {source}({score:+g}) {detail}".rstrip())

    # -- read-outs ---------------------------------------------------------- #
    def map_estimate(self, family: str, top: int | None = None) -> list[str]:
        """Maximum-a-posteriori hypotheses (highest belief first)."""
        bucket = self._bucket(family)
        ranked = sorted(bucket.values(), key=lambda h: h.score, reverse=True)
        keys = [h.key for h in ranked if h.score > 0]
        return keys[:top] if top else keys

    def family_entropy(self, family: str, temp: float = 1.0) -> float:
        bucket = self._bucket(family)
        return entropy([h.score for h in bucket.values()], temp=temp)

    def top_gap(self, family: str) -> float:
        """Score margin between the best and second-best hypothesis.

        A large gap means the belief is confident (Top-1 clearly leads) -> the
        Explore phase can skip probing this family.
        """
        bucket = self._bucket(family)
        scores = sorted((h.score for h in bucket.values()), reverse=True)
        if len(scores) < 2:
            return float("inf") if scores else 0.0
        return scores[0] - scores[1]

    def snapshot(self) -> dict:
        """JSON-serialisable view for the per-question trace / audit log."""
        def dump(bucket):
            return {k: {"score": h.score,
                        "evidence": [(e.source, e.score, e.detail) for e in h.evidence]}
                    for k, h in bucket.items()}
        return {
            "columns": dump(self.columns),
            "values": dump(self.values),
            "paths": dump(self.paths),
            "concept_bindings": self.concept_bindings,
            "entropy": {
                "columns": round(self.family_entropy("column"), 4),
                "values": round(self.family_entropy("value"), 4),
                "paths": round(self.family_entropy("path"), 4),
            },
        }
