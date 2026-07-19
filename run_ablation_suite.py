"""Run all proposed AutoLink / ReFoRCE ablations on Spider2-Lite local.

 sequential configs (each writes its own log + json). Baseline EX=27.41 already
 known from prior full135 run; we re-run variants that add components.

Usage:
  python3 -u run_ablation_suite.py --workers 6
  python3 -u run_ablation_suite.py --workers 6 --limit 30   # smoke
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time


# (tag, extra_cli_args)
CONFIGS = [
    # A. Phase1 baseline (already known ~27.41; re-run only if --rerun-base)
    ("A_base", []),
    # B. value examples in embeddings
    ("B_values", ["--values"]),
    # C. LinkAlign isolation
    ("C_isolate", ["--isolate"]),
    # D. values + isolate
    ("D_values_isolate", ["--values", "--isolate"]),
    # E. repair only
    ("E_repair2", ["--repair", "2"]),
    # F. self-refine only  NOTE: empirically HARMFUL on local135 (EX~11%)
    ("F_refine2", ["--refine", "2"]),
    # G. repair + refine (skipped by default once F is known harmful)
    ("G_repair_refine", ["--repair", "2", "--refine", "2"]),
    # H. multi-candidate vote (k=3)
    ("H_vote3", ["--candidates", "3"]),
    # I. full stack WITH refine (harmful) — prefer J instead
    ("I_fullstack", ["--values", "--isolate", "--repair", "2",
                     "--refine", "2", "--candidates", "3"]),
    # J. best practical stack: values+isolate+repair (NO refine)
    ("J_best_norefine", ["--values", "--isolate", "--repair", "2"]),
    # K. values+isolate+vote3
    ("K_values_isolate_vote3", ["--values", "--isolate", "--candidates", "3"]),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--model", default="deepseek-chat")
    ap.add_argument("--gen-model", default="deepseek-reasoner")
    ap.add_argument("--skip", default="",
                    help="comma-separated tags to skip (e.g. A_base,H_vote3)")
    ap.add_argument("--only", default="",
                    help="comma-separated tags to run exclusively")
    ap.add_argument("--rerun-base", action="store_true")
    ap.add_argument("--summary-path",
                    default="outputs/ablation_suite_summary.txt",
                    help="write this run's summary here")
    args = ap.parse_args()

    skip = {s.strip() for s in args.skip.split(",") if s.strip()}
    only = {s.strip() for s in args.only.split(",") if s.strip()}
    if not args.rerun_base:
        skip.add("A_base")  # already measured EX=27.41

    os.makedirs("outputs", exist_ok=True)
    summary_path = args.summary_path
    results = []
    # seed known baseline
    if "A_base" in skip:
        results.append(("A_base", 27.407, 37, "prior full135"))
        with open(summary_path, "w") as f:
            f.write("A_base\tEX=27.407\tcorrect=37\t(prior full135)\n")

    t_all = time.time()
    for tag, extra in CONFIGS:
        if tag in skip:
            print(f"[suite] SKIP {tag}")
            continue
        if only and tag not in only:
            print(f"[suite] SKIP {tag} (not in --only)")
            continue
        log = f"outputs/log_ablation_{tag}.txt"
        cmd = [
            sys.executable, "-u", "run_autolink_local.py",
            "--workers", str(args.workers),
            "--model", args.model,
            "--gen-model", args.gen_model,
            "--tag", tag,
        ] + extra
        if args.limit:
            cmd += ["--limit", str(args.limit)]
        print(f"\n##### {tag} #####", flush=True)
        print(" ".join(cmd), flush=True)
        t0 = time.time()
        with open(log, "w") as lf:
            p = subprocess.run(cmd, stdout=lf, stderr=subprocess.STDOUT)
        dt = time.time() - t0
        # parse EX from log
        ex = correct = None
        try:
            text = open(log).read()
            for line in text.splitlines():
                if "EX=" in line and "correct=" in line:
                    # [autolink-X] EX=.. correct=..
                    parts = line.split()
                    for p_ in parts:
                        if p_.startswith("EX="):
                            ex = float(p_.split("=", 1)[1])
                        if p_.startswith("correct="):
                            correct = int(p_.split("=", 1)[1])
        except Exception as e:  # noqa: BLE001
            print(f"[suite] parse fail {tag}: {e}")
        status = "OK" if p.returncode == 0 else f"FAIL({p.returncode})"
        print(f"[suite] {tag} {status} EX={ex} correct={correct} ({dt:.0f}s)",
              flush=True)
        results.append((tag, ex, correct, status))
        with open(summary_path, "a") as f:
            f.write(f"{tag}\tEX={ex}\tcorrect={correct}\t{status}\t{dt:.0f}s\n")

    print("\n========== ABLATION SUMMARY ==========")
    for tag, ex, correct, status in results:
        print(f"  {tag:22s}  EX={ex}  correct={correct}  {status}")
    print(f"total wall {time.time()-t_all:.0f}s")
    print(f"wrote {summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
