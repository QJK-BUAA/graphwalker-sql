"""Belief-gated selective consensus for cloud backends (P3).

ReFoRCE runs several candidates per question and majority-votes on the results.
That is powerful but pays the sampling cost on *every* question. GraphWalker's
differentiator is cost-adaptivity, so here consensus is *gated by belief*: it is
triggered only for low-confidence answers (needed a repair, returned very few
rows, or had no probe evidence). High-confidence single-shot answers are kept as
is, preserving the cost-bounded design.

When triggered we generate a few extra candidates at a higher temperature,
execute each (cost-guarded, reusing cloud_execute), group them by an
order-insensitive, numeric-tolerant result signature, and return the majority
result. The already-computed primary answer participates as one vote.
"""
from __future__ import annotations

import math
from dataclasses import dataclass


def _norm_cell(x) -> str:
    """Numeric-tolerant, stable string form of a single cell."""
    if x is None:
        return "∅"
    if isinstance(x, bool):
        return str(x)
    if isinstance(x, (int, float)):
        try:
            f = float(x)
        except (TypeError, ValueError):
            return str(x)
        if math.isnan(f):
            return "∅"
        # round to 2 decimals so 1e-2-level differences are treated as equal
        return f"{round(f, 2):.2f}"
    s = str(x).strip()
    # numeric strings normalise to the same bucket as numbers
    try:
        return f"{round(float(s), 2):.2f}"
    except (TypeError, ValueError):
        return s


def result_signature(rows: list, columns: list | None = None) -> str:
    """Order-insensitive multiset signature of a result set.

    Column order is normalised per row (sorted cells) so two queries that select
    the same values in a different column order still match, matching the
    Spider2 evaluator's column-agnostic comparison spirit.
    """
    if not rows:
        return "∅empty"
    norm_rows = []
    for r in rows:
        cells = [_norm_cell(c) for c in r]
        norm_rows.append("|".join(sorted(cells)))
    return "\n".join(sorted(norm_rows))


@dataclass
class Candidate:
    sql: str
    ok: bool
    n_rows: int
    signature: str
    est_gb: float | None = None


def vote(candidates: list[Candidate]) -> tuple[Candidate | None, dict]:
    """Majority vote over non-empty, successfully-executed candidates.

    Returns (winner, info). Ties are broken by (vote_count, more_rows, earlier
    index) so the primary candidate is favoured on a tie. Only candidates that
    executed and returned rows are eligible to win.
    """
    eligible = [c for c in candidates if c.ok and c.n_rows > 0]
    info = {"n_candidates": len(candidates), "n_eligible": len(eligible)}
    if not eligible:
        info["decision"] = "no eligible candidate"
        return None, info

    groups: dict[str, list[int]] = {}
    for i, c in enumerate(eligible):
        groups.setdefault(c.signature, []).append(i)

    def group_key(item):
        sig, idxs = item
        votes = len(idxs)
        best_rows = max(eligible[i].n_rows for i in idxs)
        earliest = min(idxs)
        return (votes, best_rows, -earliest)

    best_sig, best_idxs = max(groups.items(), key=group_key)
    winner = eligible[min(best_idxs)]
    info.update(
        n_groups=len(groups),
        winner_votes=len(best_idxs),
        agreement=round(len(best_idxs) / len(eligible), 2),
    )
    info["decision"] = f"majority {len(best_idxs)}/{len(eligible)}"
    return winner, info


def is_low_confidence(repairs: int, final_rows: int, final_ok: bool,
                      n_probe_hints: int, min_rows: int) -> tuple[bool, str]:
    """Belief gate: should this answer get extra consensus candidates?

    Kept deliberately *selective* so consensus stays cost-adaptive. On n=20 a
    loose gate (few-rows / no-probe) fired on nearly every cloud question and
    doubled cost without improving EX, so only the strong low-belief signals
    remain: the answer did not execute, or it needed a repair (both indicate the
    single-shot belief was genuinely uncertain). Empty results also qualify since
    an empty answer is almost always wrong on Spider2-Lite.
    """
    if not final_ok:
        return True, "primary did not execute"
    if final_rows == 0:
        return True, "empty result"
    if repairs > 0:
        return True, f"needed {repairs} repair(s)"
    return False, "high confidence, single-shot"
