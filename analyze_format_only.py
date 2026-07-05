"""Diagnostic: how many wrong questions are ONLY a column-format mismatch?

BIRD official EX compares whole-row tuple SETS: set(pred_rows) == set(gold_rows).
So a semantically-correct answer that adds an extra column (or reorders columns)
is judged wrong. This script estimates the UPPER BOUND of such "format-only"
failures by a relaxed, diagnostic check (NOT used for reporting EX):

  A wrong (but executable) question is "format-only recoverable" iff
    * gold and pred return the same number of rows, AND
    * every gold column's value-multiset appears among pred's columns
      (i.e. pred contains all the information gold asks for, possibly plus extra
       columns or in a different order).

If so, projecting pred onto gold's columns would pass official EX. We report this
ONLY as attribution; the official 55.48% stays the reported number.
"""
from __future__ import annotations

import json
import os
import sqlite3
import sys
import threading
from collections import Counter

sys.path.insert(0, ".")
from gws2 import config

d = json.load(open("outputs/bird_full_deepseek-chat_FULL_seed42.json"))
pq = {r["instance_id"]: r["res"] for r in d["official_eval"]["per_question"]}
recs = {r["instance_id"]: r for r in d["records"]}
wrong = [i for i in recs if pq.get(i, 0) == 0]


def run(sp, sql, timeout=20.0):
    con = None
    try:
        con = sqlite3.connect(f"file:{sp}?mode=ro", uri=True)
        t = threading.Timer(timeout, con.interrupt); t.start()
        try:
            cur = con.cursor(); cur.execute(sql); rows = cur.fetchmany(10000)
        finally:
            t.cancel()
        return rows
    except Exception:  # noqa: BLE001
        return None
    finally:
        if con is not None:
            con.close()


def dbpath(db):
    return os.path.join(config.BIRD_DB_DIR, db, f"{db}.sqlite")


def col_multisets(rows):
    """Return list of Counters, one per column (value multiset)."""
    if not rows:
        return []
    ncol = len(rows[0])
    return [Counter(str(r[c]) for r in rows) for c in range(ncol)]


def gold_cols_subset_of_pred(grows, prows):
    """True if every gold column matches some distinct pred column (multiset)."""
    if grows is None or prows is None:
        return False
    if len(grows) != len(prows):
        return False
    if not grows:  # both empty, same rowcount -> handled elsewhere
        return False
    gcols = col_multisets(grows)
    pcols = col_multisets(prows)
    used = [False] * len(pcols)
    for gc in gcols:
        hit = False
        for j, pc in enumerate(pcols):
            if not used[j] and pc == gc:
                used[j] = True; hit = True; break
        if not hit:
            return False
    return True


format_only = []          # pred has all gold cols + extra/reorder, same rows
exact_after_proj = 0
extra_col_cases = 0
checked = 0
for iid in wrong:
    r = recs[iid]
    if r.get("error") or r.get("exec_ok") is False:
        continue
    sp = dbpath(r["db_id"])
    grows = run(sp, r["gold_sql"])
    prows = run(sp, r["pred_sql"])
    if grows is None or prows is None:
        continue
    checked += 1
    gc = len(grows[0]) if grows else 0
    pc = len(prows[0]) if prows else 0
    if gold_cols_subset_of_pred(grows, prows):
        format_only.append((iid, r.get("difficulty"), f"gold{gc}c/pred{pc}c"))
        if pc > gc:
            extra_col_cases += 1

n_wrong = len(wrong)
print(f"wrong total            : {n_wrong}")
print(f"checked (exec-ok both) : {checked}")
print(f"FORMAT-ONLY recoverable: {len(format_only)}  "
      f"({100*len(format_only)/n_wrong:.1f}% of all wrong)")
print(f"  of which extra-column: {extra_col_cases}")
print(f"potential EX if fixed  : "
      f"{100*(851+len(format_only))/1534:.2f}%  (vs official 55.48%)")

by_diff = Counter(x[1] for x in format_only)
print("format-only by difficulty:", dict(by_diff))
print("\nsamples:")
for iid, diff, shp in format_only[:12]:
    r = recs[iid]
    print(f"— {iid} [{diff}] {shp}")
    print(f"   Q   : {r['question'][:80]}")
    print(f"   GOLD: {' '.join(r['gold_sql'].split())[:110]}")
    print(f"   PRED: {' '.join(r['pred_sql'].split())[:110]}")

json.dump({"format_only": format_only,
           "n_format_only": len(format_only),
           "potential_ex": round(100*(851+len(format_only))/1534, 2)},
          open("outputs/format_only_analysis.json", "w"),
          ensure_ascii=False, indent=2, default=str)
