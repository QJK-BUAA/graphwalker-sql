"""Detailed error attribution for the full BIRD-Dev run.

For every question whose official EX == 0, we compare the predicted SQL against
the gold SQL along a set of white-box structural signals (table set, #joins,
aggregation, GROUP BY, ORDER/LIMIT, DISTINCT, subquery/CTE, ratio-cast, result
cardinality). Each wrong question is bucketed into a primary root-cause category
so we can reason about WHERE the pipeline breaks, not just that it breaks.
"""
from __future__ import annotations

import json
import re
import sqlite3
import threading
from collections import Counter, defaultdict

RES = "outputs/bird_full_deepseek-chat_FULL_seed42.json"

d = json.load(open(RES))
pq = {r["instance_id"]: r["res"] for r in d["official_eval"]["per_question"]}
recs = {r["instance_id"]: r for r in d["records"]}


def run(sqlite_path, sql, timeout=20.0):
    con = None
    try:
        con = sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True)
        t = threading.Timer(timeout, con.interrupt); t.start()
        try:
            cur = con.cursor(); cur.execute(sql); rows = cur.fetchmany(5000)
        finally:
            t.cancel()
        return rows, None
    except Exception as e:  # noqa: BLE001
        return None, str(e)
    finally:
        if con is not None:
            con.close()


def tset(sql):
    # crude table set: words after FROM/JOIN
    toks = re.findall(r"(?:from|join)\s+[`\"\[]?([A-Za-z_][\w]*)", sql, re.I)
    return {t.lower() for t in toks}


def feat(sql):
    s = sql.lower()
    return {
        "n_join": len(re.findall(r"\bjoin\b", s)),
        "agg": bool(re.search(r"\b(count|sum|avg|max|min)\s*\(", s)),
        "group": "group by" in s,
        "order": "order by" in s,
        "limit": "limit" in s,
        "distinct": "distinct" in s,
        "sub": s.count("select") > 1,
        "cast_real": "as real" in s or "cast(" in s,
        "case": "case " in s or "iif(" in s,
        "like": " like " in s,
    }


# path/db lookup for re-execution
import sys
sys.path.insert(0, ".")
from gws2 import config
import os

def dbpath(db_id):
    return os.path.join(config.BIRD_DB_DIR, db_id, f"{db_id}.sqlite")


cats = Counter()
detail = defaultdict(list)
wrong = [iid for iid in recs if pq.get(iid, 0) == 0]

for iid in wrong:
    r = recs[iid]
    gold, pred = r.get("gold_sql", ""), r.get("pred_sql", "")
    db = r["db_id"]; sp = dbpath(db)
    diff = r.get("difficulty", "")

    # 1) hard execution failure
    if r.get("error"):
        cats["pipeline_error"] += 1; detail["pipeline_error"].append(iid); continue
    if r.get("exec_ok") is False:
        cats["exec_fail"] += 1; detail["exec_fail"].append(iid); continue

    grows, gerr = run(sp, gold)
    prows, perr = run(sp, pred)
    if perr:
        cats["exec_fail"] += 1; detail["exec_fail"].append(iid); continue
    if gerr:
        cats["gold_unrunnable"] += 1; detail["gold_unrunnable"].append(iid); continue

    gts, pts = tset(gold), tset(pred)
    gf, pf = feat(gold), feat(pred)
    gn, pn = len(grows or []), len(prows or [])

    # 2) wrong tables (schema-linking miss): table sets differ on schema tables
    missing_tabs = gts - pts
    extra_tabs = pts - gts
    if missing_tabs:
        cats["missing_table(linking)"] += 1
        detail["missing_table(linking)"].append((iid, diff, sorted(missing_tabs)))
        continue

    # 3) column/shape: same tables, but selected column count differs
    gcols = len(grows[0]) if grows else 0
    pcols = len(prows[0]) if prows else 0
    if gcols != pcols:
        cats["wrong_select_shape"] += 1
        detail["wrong_select_shape"].append((iid, diff, f"gold{gcols}c/pred{pcols}c"))
        continue

    # 4) aggregation / grouping mismatch
    if gf["group"] != pf["group"] or gf["agg"] != pf["agg"]:
        cats["agg_group_mismatch"] += 1
        detail["agg_group_mismatch"].append((iid, diff))
        continue

    # 5) ratio/cast mismatch (integer division etc.)
    if gf["cast_real"] and not pf["cast_real"]:
        cats["ratio_cast_missing"] += 1
        detail["ratio_cast_missing"].append((iid, diff)); continue

    # 6) ordering / limit / top-k mismatch
    if gf["order"] != pf["order"] or gf["limit"] != pf["limit"]:
        cats["order_limit_mismatch"] += 1
        detail["order_limit_mismatch"].append((iid, diff)); continue

    # 7) extra tables (over-join) with same shape
    if extra_tabs:
        cats["extra_table(over_join)"] += 1
        detail["extra_table(over_join)"].append((iid, diff, sorted(extra_tabs)))
        continue

    # 8) row-count off (filter/condition/distinct semantics)
    if gn != pn:
        cats["wrong_rowcount(filter/distinct)"] += 1
        detail["wrong_rowcount(filter/distinct)"].append((iid, diff, f"gold{gn}/pred{pn}"))
        continue

    # 9) same shape & rowcount but values differ (subtle value/column semantics)
    cats["value_semantics(same_shape)"] += 1
    detail["value_semantics(same_shape)"].append((iid, diff))

print("=== WRONG-QUESTION ROOT-CAUSE BREAKDOWN (n_wrong=%d) ===" % len(wrong))
for c, k in cats.most_common():
    print(f"  {k:4d}  {100*k/len(wrong):5.1f}%   {c}")

# difficulty of wrong questions
dc = Counter(recs[i].get("difficulty", "") for i in wrong)
print("\nwrong by difficulty:", dict(dc))

json.dump({"cats": dict(cats), "detail": {k: v for k, v in detail.items()}},
          open("outputs/error_analysis_bird_full.json", "w"),
          ensure_ascii=False, indent=2, default=str)
print("\nwrote outputs/error_analysis_bird_full.json")
