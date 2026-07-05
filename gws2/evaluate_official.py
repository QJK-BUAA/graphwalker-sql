"""Evaluation harness wrapping the three OFFICIAL evaluators.

Design principle (project rule): report execution accuracy using the official
scripts, never a bespoke approximate matcher. For each dataset we (a) write the
predictions in exactly the layout the official evaluator expects, then (b) invoke
that evaluator and parse its EX number.

  BIRD          -> 论文复现/.../evaluation/bird_evaluation_raw.py
                   (pred: {idx: "SQL\\t----- bird -----\\tdb"}, gold: dev.sql lines)
  Spider 1.0    -> .../test-suite-sql-eval/evaluation.py --etype exec
                   (pred/gold: one SQL per line, index-aligned)
  Spider 2.0-Lite -> ReFoRCE/spider2-lite/evaluation_suite/evaluate.py --mode sql
                   (pred: one <instance_id>.sql file per question)

Because official gold files are index-aligned/whole files, we build a *gold
subset* aligned to the sampled predictions so partial (smoke) runs evaluate
correctly.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

from . import config
from .datasets import Example


# --------------------------------------------------------------------------- #
# BIRD
# --------------------------------------------------------------------------- #
def evaluate_bird(examples: list[Example], pred_sql: dict[str, str],
                  workdir: str) -> dict:
    """Score with BIRD's OFFICIAL per-question comparator.

    We import ``execute_model`` from the official ``bird_evaluation_raw.py`` and
    call it per question (identical execute-both + round-floats-6dp + set-equality
    logic), then aggregate overall EX ourselves. This avoids the official
    ``compute_acc_by_diff`` division-by-zero when a difficulty bucket is empty in
    small samples, while keeping the exact official matching semantics.
    """
    import importlib.util

    workdir = os.path.abspath(workdir)
    os.makedirs(workdir, exist_ok=True)

    eval_dir = os.path.dirname(config.BIRD_EVAL_SCRIPT)
    shim = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "eval_shims")
    for p in (shim, eval_dir):
        if p not in sys.path:
            sys.path.insert(0, p)
    spec = importlib.util.spec_from_file_location("bird_eval_official",
                                                  config.BIRD_EVAL_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    per_diff: dict[str, list[int]] = {}
    results = []
    for i, ex in enumerate(examples):
        sql = (pred_sql.get(ex.instance_id) or "SELECT 1").replace("\n", " ").strip()
        r = mod.execute_model(sql, ex.gold_sql.strip(), ex.sqlite_path, i, 30.0)
        res = int(r.get("res", 0))
        results.append({"instance_id": ex.instance_id, "res": res})
        per_diff.setdefault(ex.difficulty or "simple", []).append(res)

    n = len(examples)
    ex_overall = 100.0 * sum(x["res"] for x in results) / n if n else None
    out = {"n": n, "ex": round(ex_overall, 2) if ex_overall is not None else None,
           "correct": sum(x["res"] for x in results), "per_question": results}
    for d, xs in per_diff.items():
        out[d] = round(100.0 * sum(xs) / len(xs), 2)
    return out


# --------------------------------------------------------------------------- #
# Spider 1.0 (test-suite evaluator, execution mode against dev DBs)
# --------------------------------------------------------------------------- #
def evaluate_spider1(examples: list[Example], pred_sql: dict[str, str],
                     workdir: str) -> dict:
    workdir = os.path.abspath(workdir)
    os.makedirs(workdir, exist_ok=True)
    pred_lines, gold_lines = [], []
    for ex in examples:
        sql = (pred_sql.get(ex.instance_id) or "SELECT 1").replace("\n", " ").strip()
        pred_lines.append(sql)
        gold_lines.append(f"{ex.gold_sql.strip()}\t{ex.db_id}")
    pred_path = os.path.join(workdir, "pred.sql")
    gold_path = os.path.join(workdir, "gold_subset.sql")
    open(pred_path, "w").write("\n".join(pred_lines) + "\n")
    open(gold_path, "w").write("\n".join(gold_lines) + "\n")

    script = os.path.join(config.SPIDER1_TESTSUITE, "evaluation.py")
    cmd = [sys.executable, script, "--gold", gold_path, "--pred", pred_path,
           "--db", config.SPIDER1_DB_DIR, "--etype", "exec"]
    proc = subprocess.run(cmd, capture_output=True, text=True,
                          cwd=config.SPIDER1_TESTSUITE)
    out = proc.stdout + "\n" + proc.stderr
    return _parse_spider1(out, len(examples))


def _parse_spider1(out: str, n: int) -> dict:
    # The 'all' row reports execution accuracy under the 'exec' column.
    res = {"n": n, "raw_tail": out[-800:]}
    # Find the execution accuracy line: matches "execution   <...> all: x"
    # The script prints a table; grab the 'all' exec figure robustly.
    m = re.search(r"execution\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)", out)
    if m:
        res["ex"] = float(m.group(5)) * 100 if float(m.group(5)) <= 1 else float(m.group(5))
    else:
        res["ex"] = None
    return res


# --------------------------------------------------------------------------- #
# Spider 2.0-Lite (ReFoRCE official evaluate.py, sql mode, local subset)
# --------------------------------------------------------------------------- #
def evaluate_spider2_lite(examples: list[Example], pred_sql: dict[str, str],
                          workdir: str) -> dict:
    result_dir = os.path.join(workdir, "sql_submit")
    os.makedirs(result_dir, exist_ok=True)
    for ex in examples:
        sql = pred_sql.get(ex.instance_id) or "SELECT 1"
        open(os.path.join(result_dir, f"{ex.instance_id}.sql"), "w").write(sql)

    eval_dir = config.SPIDER2_EVAL_DIR
    gold_dir = os.path.join(eval_dir, "gold")
    script = os.path.join(eval_dir, "evaluate.py")
    cmd = [sys.executable, script, "--mode", "sql",
           "--result_dir", os.path.abspath(result_dir), "--gold_dir", gold_dir]
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=eval_dir)
    out = proc.stdout + "\n" + proc.stderr
    return _parse_spider2(out, len(examples))


def _parse_spider2(out: str, n: int) -> dict:
    res = {"n": n, "raw_tail": out[-800:]}
    m = re.search(r"Final score:\s*([\d.]+),\s*Correct examples:\s*(\d+),"
                  r"\s*Total examples:\s*(\d+)", out)
    if m:
        res.update(ex=float(m.group(1)) * 100, correct=int(m.group(2)),
                   scored=int(m.group(3)))
    else:
        res["ex"] = None
    return res


EVALUATORS = {
    "bird": evaluate_bird,
    "spider1": evaluate_spider1,
    "spider2-lite": evaluate_spider2_lite,
    "spider2-lite-local": evaluate_spider2_lite,
}


def evaluate(dataset: str, examples: list[Example], pred_sql: dict[str, str],
             workdir: str) -> dict:
    return EVALUATORS[dataset](examples, pred_sql, workdir)
