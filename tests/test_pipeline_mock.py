"""Offline integration test with a deterministic MockLLM (no network / no API key).

Purpose: validate the full Ground -> Explore -> Commit wiring, belief updates,
path probing, official-evaluator plumbing and result serialisation WITHOUT
calling a real model. The MockLLM returns schema-aware, rule-based answers so the
pipeline exercises every branch. This is a wiring test, not a quality test --
real EX numbers require a real LLM (deepseek-chat).

Run:  python tests/test_pipeline_mock.py
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from gws2.datasets import load_and_sample
from gws2.evaluate_official import evaluate
from gws2.pipeline import AblationConfig, load_db, run_pipeline


class MockLLM:
    """Rule-based stand-in for gws2.llm.LLM (same .complete/.stats interface)."""

    def __init__(self, *a, **k):
        self.num_calls = 0
        self.in_tokens = 0
        self.out_tokens = 0
        self.seed = 42

    def stats(self):
        return {"num_calls": self.num_calls, "input_tokens": 0, "output_tokens": 0}

    def complete(self, system: str, user: str, temperature=None) -> str:
        self.num_calls += 1
        s = system.lower()
        if "joinability" in s or "foreign-key" in s:
            return "NONE"
        if "decompose a natural-language question into the atomic" in s:
            # exercise concept alignment: emit a couple of parseable concepts
            return ("concept=name | role=output | value=\n"
                    "concept=count | role=output | value=")
        if "src:" in s or "src=" in system or "map a natural" in s:
            tables = re.findall(r"^(\w+)\(", user, re.M)
            first = tables[0] if tables else "t"
            return f"src={first}\ndst={first}\nliterals="
        if "join path" in s and "path=" in s:
            return "path=P0"
        if "auditing a grounded" in s or "verdict=" in system.lower():
            return "verdict=OK\nmissing="
        if "query-structure planner" in s or "return json only" in s:
            return ('{"set_op":"none","nested":false,"group_by":false,'
                    '"having":false,"order_by":false,"limit":false,'
                    '"select_arity":1,"aggregation":true,"notes":"count"}')
        if "query-generation specialist" in s or "corrected" in s:
            m = re.search(r'CREATE TABLE "?(\w+)"?', user)
            t = m.group(1) if m else "sqlite_master"
            return f"```sql\nSELECT COUNT(*) FROM {t}\n```"
        return ""


def main():
    ok_all = True
    for ds in ["bird", "spider1", "spider2-lite"]:
        exs = load_and_sample(ds, 2)
        llm = MockLLM()
        pred = {}
        for ex in exs:
            schema = load_db(ex.sqlite_path, with_stats=True)
            res = run_pipeline(schema, ex.sqlite_path, ex.question, llm,
                               evidence=ex.evidence, ablation=AblationConfig(),
                               with_snapshot=True)
            pred[ex.instance_id] = res.sql
            assert res.sql, "empty SQL"
            assert isinstance(res.belief_entropy, dict)
            assert res.trace, "empty trace"
        # official evaluator plumbing (EX will be ~0 with the dumb mock SQL)
        r = evaluate(ds, exs, pred, os.path.join("outputs", "mocktest", ds))
        status = "OK" if r.get("ex") is not None else "PARSE-FAIL"
        print(f"[{ds}] pipeline+eval plumbing: {status} | EX={r.get('ex')} "
              f"| calls/q~{llm.num_calls // max(1,len(exs))}")
        ok_all = ok_all and r.get("ex") is not None

    # ablation switches must all run without error
    ex = load_and_sample("bird", 1)[0]
    schema = load_db(ex.sqlite_path, with_stats=True)
    for tag, kw in [("noinfer", dict(use_inferred_graph=False)),
                    ("nowalk", dict(use_belief_walk=False)),
                    ("notopk", dict(use_topk=False)),
                    ("noprobe", dict(use_probes=False)),
                    ("nocolprobe", dict(use_column_probes=False)),
                    ("nostruct", dict(use_structure_plan=False)),
                    ("nostop", dict(use_entropy_stop=False)),
                    ("nopropose", dict(use_propose=False)),
                    ("propgate", dict(use_propose_evidence_gate=True)),
                    ("noconcept", dict(use_concept_align=False)),
                    ("noadaptive", dict(use_adaptive_schema=False)),
                    ("hardstruct", dict(soft_structure=False)),
                    ("nogate", dict(gate_by_graph=False)),
                    ("consensus", dict(n_candidates=3)),
                    ("norepair", dict(max_repairs=0))]:
        res = run_pipeline(schema, ex.sqlite_path, ex.question, MockLLM(),
                           ablation=AblationConfig(**kw))
        assert res.sql
        print(f"[ablation {tag}] ran OK -> linked={res.linked_tables}")

    # evidence miner must extract value-maps and formulas generically
    from gws2.commit import _evidence_hints
    hh = _evidence_hints("when the account type = 'OWNER', it's eligible for loan; "
                         "rate = a / b")
    assert any("OWNER" in h for h in hh), f"value-map miner failed: {hh}"
    assert any("/" in h for h in hh), f"formula miner failed: {hh}"
    print(f"[evidence miner] OK -> {hh}")

    # Propose evidence gate: accept only tables with join evidence to the current
    # grounded subgraph, but allow an iteratively connected chain.
    import networkx as nx
    from gws2.commit import _gate_propose_additions
    from gws2.graph_builder import SchemaGraph
    g = nx.Graph()
    g.add_nodes_from(["A", "B", "C", "D"])
    g.add_edge("A", "B", joins=[("A", "id", "B", "a_id")])
    g.add_edge("B", "C", joins=[("B", "id", "C", "b_id")])
    sg = SchemaGraph(g, [], method="declared")
    accepted, rejected = _gate_propose_additions(sg, ["A"], ["B", "C", "D"])
    assert accepted == ["B", "C"], (accepted, rejected)
    assert rejected == ["D"], (accepted, rejected)
    print(f"[propose gate] OK -> accepted={accepted} rejected={rejected}")

    print("\nALL PLUMBING TESTS PASSED" if ok_all else "\nSOME EVAL PARSERS FAILED")
    return 0 if ok_all else 1


if __name__ == "__main__":
    raise SystemExit(main())
