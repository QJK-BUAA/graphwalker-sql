"""Timeout-safe official evaluation for Spider2-lite-local runs.

The official ReFoRCE evaluator executes every predicted SQL with no effective
timeout, so a single non-terminating (e.g. over-joined) prediction can stall it
for >25 min. This wrapper first probes each prediction with our watchdog-timed
executor, replaces any that do not terminate within a bound (a genuine failure)
with ``SELECT 1``, then invokes the OFFICIAL evaluator on the sanitised set.

Usage:
    python eval_spider2_safe.py outputs/<run>.json [timeout_s]
"""
from __future__ import annotations

import json
import os
import sys
import time

from gws2.datasets import load_and_sample
from gws2.evaluate_official import evaluate
from gws2.execute import run_query


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: python eval_spider2_safe.py <run.json> [timeout_s]")
        return 2
    run_json = sys.argv[1]
    timeout_s = float(sys.argv[2]) if len(sys.argv) > 2 else 20.0

    data = json.load(open(run_json))
    dataset = data.get("dataset") or "spider2-lite-local"
    recs = {r["instance_id"]: r for r in data["records"]}
    exs = load_and_sample(dataset, None)

    pred: dict[str, str] = {}
    neutralized: list[str] = []
    for e in exs:
        r = recs.get(e.instance_id)
        sql = (r or {}).get("pred_sql") or "SELECT 1"
        # probe: does this prediction terminate quickly?
        t0 = time.time()
        res = run_query(e.sqlite_path, sql, max_rows=1000, timeout=timeout_s)
        if not res.get("ok") and time.time() - t0 >= timeout_s - 0.5:
            neutralized.append(e.instance_id)
            sql = "SELECT 1  -- neutralized: non-terminating prediction"
        pred[e.instance_id] = sql

    workdir = os.path.join("outputs", "eval_work",
                           os.path.basename(run_json).replace(".json", "") + "_safeeval")
    res = evaluate(dataset, exs, pred, workdir)
    print(f"[safe-eval] {os.path.basename(run_json)}")
    print(f"[safe-eval] neutralized {len(neutralized)} non-terminating preds: {neutralized}")
    print(f"[safe-eval] EX={res.get('ex')} correct={res.get('correct')} "
          f"scored={res.get('scored')} n={res.get('n')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
