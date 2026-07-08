# Concept Alignment + Confidence-Adaptive Constraint — Experiment Report

> Branch: `feat/concept-column-belief` · model=`deepseek-chat`, temperature=0, seed=42,
> official evaluators. All configs in a table share the **same** stratified sample, so
> deltas are mechanism-driven (not run-to-run noise; temp=0 is deterministic per config).

This branch adds two query-centric improvements motivated by the full-set error analysis
(`BIRD错题反思报告.md`): (1) **Query-Centric Concept Alignment** — decompose the question into
concepts and bind each to its best column by a white-box competition (Point 1); (2)
**Confidence-adaptive generation constraint** — widen the exposed schema with bounded graph
neighbours when belief is uncertain, and soften the query skeleton from a hard repair gate to
a hint (Point 2). Ablations: `noconcept` / `noadaptive` / `hardstruct`; `prebaseline` = all three off.

## 1. Headline (honest, and it cuts both ways)

| Setting | pre-branch default | **full (all 3 on)** | Δ EX | driver |
|---|---:|---:|---:|---|
| **Spider2-lite local (n=24, FK-sparse / inferred graph)** | 29.17 (7/24) | **37.50 (9/24)** | **+8.3** | adaptive widening |
| **BIRD-Dev (n=100, declared FK / clean schema)** | 51.0 | 49.0 | **−2.0** | SELECT-shape + widening noise |

**The mechanisms help exactly where schema grounding is the bottleneck (FK-sparse Spider2) and
add noise where grounding is already solved (clean-FK BIRD).** This is consistent with the error
analysis finding that on BIRD ~69% of wrong answers already link the correct tables — so
grounding-focused mechanisms have little to gain and some prompt-noise to lose.

## 2. Spider2-lite local (n=24) — where the improvements are designed to help

| config | EX | correct | calls/q |
|---|---:|---:|---:|
| prebaseline (all off) | 29.17 | 7/24 | 5.5 |
| **full** (concept+adaptive+soft) | **37.50** | **9/24** | 6.1 |
| noconcept (adaptive+soft) | 37.50 | 9/24 | 5.0 |
| noadaptive (concept+soft) | 25.00 | 6/24 | 6.0 |

- **Adaptive widening is the decisive driver**: widening-on (full, noconcept) = 37.5; widening-off
  (noadaptive, prebaseline) = 25–29.
- **Concept alignment is neutral on this sample** (full == noconcept == 37.5) — it neither helped
  nor hurt at n=24.
- **Mechanism evidence**: widening was active on 19/24 questions, and the recovered (optional)
  table was **actually used in the final SQL in 10/24** cases — e.g. `local003`→`customers`,
  `local022/023`→`match`/`ball_by_ball` — i.e. the model recovered tables the grounding had missed.

## 3. BIRD-Dev (n=100) — where grounding is already solved

| config | EX | calls/q | vs prebaseline |
|---|---:|---:|---:|
| **prebaseline** (all off = old default) | **51.0** | 4.25 | — |
| full (concept+adaptive+soft) | 49.0 | 5.10 | −2.0 |
| noconcept (adaptive+soft) | 48.0 | 4.09 | −3.0 |
| noadaptive (concept+soft) | 47.0 | 5.08 | −4.0 |
| hardstruct (concept+adaptive, hard skeleton) | 49.0 | 5.28 | −2.0 |

Per-question diff (full vs prebaseline): **6 fixed / 8 broke → net −2**. Regression taxonomy of the 8:

| # | cause | example |
|---|---|---|
| 3–4 | **SELECT shape** (BIRD grades whole rows) | `bird_1255` soft skeleton dropped `LIMIT 1` for "most common"; `bird_1474`/`bird_1080` added a helper column |
| 1 | **concept mis-binding** | `bird_177` bound "sum" to `amount` instead of `balance` |
| 3 | **widening / linking noise** | `bird_485` made the needed `cards` join "optional" → model used a `LIKE` hack; `bird_953` +6 optional tables |

Key takeaway: on BIRD, the **hard skeleton was a useful guardrail** (it enforces select arity / LIMIT
against strict whole-row grading), and widening's extra optional tables are mostly prompt noise.

## 4. Cost

Concept extraction adds ~1 LLM call/question (BIRD 4.25→5.1). Value/column probes are local SQL
(no LLM). On BIRD this extra cost buys nothing; on Spider2 the widening gain comes with no extra LLM
call (noconcept, which drops the concept call, keeps the +8.3).

## 5. Conclusion & the shipped default (graph-type gating)

- **Do NOT apply these on clean, declared-FK schemas (BIRD-style)** — they are net-negative there.
- **DO apply them on FK-sparse / inferred-graph settings (Spider2-style)** — +8.3 EX, driven by
  adaptive widening recovering missed tables.
- For a paper, the BIRD-negative / Spider2-positive **contrast is itself the finding**: grounding-focused
  belief refinement helps iff grounding is the bottleneck.

**Implemented as the default (`gate_by_graph`, `gws2/pipeline.py`).** The three mechanisms are gated on an
observable per-question signal — whether the schema graph is *inferred* (no usable declared FKs → grounding
is uncertain). Declared-FK questions run the tight/hard baseline; inferred-graph questions run the full
mechanisms. Verified on the real model:

| BIRD n=10 | LLM calls/q |
|---|---:|
| default (gated → mechanisms off on declared FK) | 4.2 |
| `nogate` (mechanisms forced on) | 5.1 |

So the gated default recovers the clean-schema baseline **at lower cost** (the concept-extraction call is
skipped on BIRD) while keeping the Spider2 gain. By construction the gated default equals `prebaseline` on
BIRD (≈51 EX) and `full` on Spider2 (37.5 EX). Use `--ablation nogate` to apply the mechanisms everywhere.

> Remaining validation: confirm the Spider2 gain on the 135-question local set and/or multiple seeds
> (current Spider2 result is n=24, where 2 questions ≈ 8 EX).

> Caveats: Spider2-lite local is only n=24 (±~8 EX per 2 questions); confirm on the 135-question local
> set and/or multiple seeds before headline claims. BIRD n=100 variants fall in a 47–51 band that is
> near the established noise level, but prebaseline is consistently at the top.
