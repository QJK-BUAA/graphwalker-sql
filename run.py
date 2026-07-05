"""Run GraphWalker-SQL 2.0 on a single (database, question) pair, printing the
full white-box trace (graph, anchors, belief entropy, path probes, final SQL).

Example:
    export DS_API_KEY=sk-...
    python run.py \
        --db "$(python -c 'import gws2.config as c,os;print(os.path.join(c.BIRD_DB_DIR,"financial","financial.sqlite"))')" \
        --question "List the ids of accounts opened in the Prague region."
"""
from __future__ import annotations

import argparse
import textwrap

from gws2.llm import LLM
from gws2.pipeline import AblationConfig, load_db, run_pipeline
from run_experiment import ABLATION_PRESETS, build_ablation


def main():
    ap = argparse.ArgumentParser(description="GraphWalker-SQL 2.0 single question")
    ap.add_argument("--db", required=True, help="path to a .sqlite file")
    ap.add_argument("--question", required=True)
    ap.add_argument("--evidence", default="")
    ap.add_argument("--model", default="deepseek-chat")
    ap.add_argument("--ablation", default="full", choices=list(ABLATION_PRESETS))
    ap.add_argument("--prefer-infer", action="store_true",
                    help="ignore declared FKs; force LLM joinability discovery")
    args = ap.parse_args()

    llm = LLM(model=args.model)
    schema = load_db(args.db, with_stats=True)
    res = run_pipeline(schema, args.db, args.question, llm, evidence=args.evidence,
                       ablation=build_ablation(args.ablation),
                       prefer_declared=not args.prefer_infer, with_snapshot=True)

    print("=" * 80)
    print(f"DB           : {schema.name} | graph={res.graph_method} "
          f"({res.n_edges} edges)")
    print(f"Anchors      : src={res.sources} dst={res.destinations}")
    print(f"Literals     : {res.literals}")
    print(f"Linked tables: {res.linked_tables}")
    print(f"Chosen path  : {' -> '.join(res.chosen_path) or '(single/none)'}")
    print(f"Join conds   : {res.join_conditions}")
    print(f"Belief H     : {res.belief_entropy}  | path_probes={res.n_probes} "
          f"| column_probes={res.n_column_probes} "
          f"| propose={res.propose_verdict} | repaired={res.repaired}")
    if res.column_hints:
        print("Column hints :")
        for h in res.column_hints[:8]:
            print(f"  {h}")
    print("-" * 80)
    print("Trace:")
    for line in res.trace:
        print(f"  {line}")
    print("-" * 80)
    print("Final SQL:")
    print(textwrap.indent(res.sql, "  "))
    print("-" * 80)
    if res.execution.get("ok"):
        print(f"Execution OK. columns={res.execution.get('columns')}")
        for row in (res.execution.get("rows") or [])[:10]:
            print(f"  {row}")
    else:
        print(f"Execution ERROR: {res.execution.get('error')}")
    print(f"LLM stats: {llm.stats()}")
    print("=" * 80)


if __name__ == "__main__":
    main()
