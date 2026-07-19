"""Merge prediction overrides into a base run and evaluate."""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

from run_spider2lite_online import evaluate_official


def _predictions(payload: dict) -> dict[str, str]:
    if payload.get("pred"):
        return dict(payload["pred"])
    return {
        row["instance_id"]: row["pred_sql"]
        for row in payload.get("records", [])
        if row.get("instance_id") and row.get("pred_sql")
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="base run JSON")
    ap.add_argument("--recovery", required=True, help="recovery run JSON")
    ap.add_argument("--tag", required=True)
    ap.add_argument("--ids", default="",
                    help="optional comma-separated override IDs")
    args = ap.parse_args()

    base = json.load(open(args.base))
    recovery = json.load(open(args.recovery))
    base_pred = _predictions(base)
    pred = dict(base_pred)
    recovery_pred = _predictions(recovery)
    allowed = {x.strip() for x in args.ids.split(",") if x.strip()}
    if allowed:
        recovery_pred = {
            iid: sql for iid, sql in recovery_pred.items() if iid in allowed
        }
    pred.update(recovery_pred)

    work_dir = Path("outputs") / "eval_work" / args.tag
    result_dir = work_dir / "sql_submit"
    result_dir.mkdir(parents=True, exist_ok=True)
    for old in result_dir.glob("*.sql"):
        old.unlink()
    for iid, sql in pred.items():
        (result_dir / f"{iid}.sql").write_text(sql)

    run_id = f"{args.tag}_{int(time.time())}"
    result = evaluate_official(run_id, result_dir)
    payload = {
        "tag": args.tag,
        "base": args.base,
        "recovery": args.recovery,
        "n_base": len(base_pred),
        "n_replaced": len(recovery_pred),
        "pred": pred,
        "official_eval": result,
    }
    out = Path("outputs") / f"{args.tag}.json"
    json.dump(payload, open(out, "w"), ensure_ascii=False, indent=2)
    print(f"[{args.tag}] EX={result.get('ex')} "
          f"correct={result.get('correct')} scored={result.get('scored')}")
    print(f"[{args.tag}] wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
