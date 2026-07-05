"""Data-level value-overlap verification for inferred edges (HTML section 4.2).

For a candidate edge ``A.c -> B.k`` we sample distinct values of ``A.c`` and
measure the fraction that also appear in ``B.k``. A high containment ratio turns
a *name-guessed* edge into a *data-supported* one -- one factor of conf(edge).

Honest limitations (kept as a soft factor, never a hard truth):
  * common columns (zip / country / date) can yield false positives;
  * partial coverage yields false negatives;
  * only cheap on SQLite; large cloud tables would need sampled probes.
"""
from __future__ import annotations

import sqlite3

from .schema import ForeignKey


def overlap_ratio(sqlite_path: str, fk: ForeignKey, sample: int = 300) -> float:
    """Fraction of sampled distinct src values found in the ref column, [0, 1].

    Returns 0.0 on any error (missing table/column, type quirk); callers treat
    that as "no data support" rather than "edge rejected".
    """
    try:
        con = sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True)
        cur = con.cursor()
        st, sc = fk.src_table, fk.src_column
        rt, rc = fk.ref_table, fk.ref_column
        sub = (f'SELECT DISTINCT "{sc}" AS v FROM "{st}" '
               f'WHERE "{sc}" IS NOT NULL LIMIT {int(sample)}')
        sampled = cur.execute(f"SELECT COUNT(*) FROM ({sub})").fetchone()[0]
        if not sampled:
            con.close()
            return 0.0
        matched = cur.execute(
            f'SELECT COUNT(*) FROM ({sub}) s '
            f'WHERE s.v IN (SELECT "{rc}" FROM "{rt}")'
        ).fetchone()[0]
        con.close()
        return matched / sampled
    except Exception:  # noqa: BLE001
        return 0.0
