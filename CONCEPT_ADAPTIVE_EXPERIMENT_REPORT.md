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

## 1. Headline (honest — and the full-set result overturns the small-sample one)

| Setting | pre-branch default | **full (all 3 on)** | Δ EX | verdict |
|---|---:|---:|---:|---|
| Spider2-lite local (**n=24**, FK-sparse) | 29.17 (7/24) | 37.50 (9/24) | +8.3 | ⚠️ small-sample noise |
| **Spider2-lite local (n=135, full set)** | **19.26 (26/135)** | **17.04 (23/135)** | **−2.2** | ❌ net negative |
| BIRD-Dev (n=100, declared FK) | 51.0 | 49.0 | −2.0 | ❌ net negative |

**Corrected conclusion: as implemented, the three mechanisms do NOT provide a reliable improvement
on either benchmark.** The n=24 Spider2 "+8.3" was small-sample noise (2 questions; the project's own
noise band at n≈20 is ±~8 EX) and **did not survive scaling to the full 135-question set (−2.2)**.

Worse, **adaptive widening actively backfires by inducing over-joins**: on the 135-set the full config
produced 4 *non-terminating* queries (`local022/100/219/344`) that stalled the official evaluator for
>25 min. In every case prebaseline answered the same question in <1s with fewer joins, while widening's
extra optional tables pushed the model to add joins (e.g. `local100` 2→6 joins) → runaway SQL:

```
local022  PREbase 0.3s ok joins=3  |  FULL 12s+ FAIL joins=4
local100  PREbase 0.0s ok joins=2  |  FULL 12s+ FAIL joins=6
local219  PREbase 0.8s ok joins=2  |  FULL 12s+ FAIL joins=3
local344  PREbase 0.8s ok joins=2  |  FULL 12s+ FAIL joins=2
```

This is the value of validating at scale before shipping: the small-sample signal was misleading.
The surviving contributions are the white-box error analysis and the (negative) finding that naive
belief-driven schema widening over-joins; concept alignment is neutral and needs stronger
disambiguation to pay off.

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

## 5. Conclusion & recommendation (updated after the 135-set)

The earlier recommendation ("gate on graph type, keep it on for Spider2") was based on the n=24 subset.
**The full 135-set overturns it**: the mechanisms are net-negative on Spider2 too (−2.2), and adaptive
widening introduces a real robustness failure (non-terminating over-joined queries). So:

- **Do not ship the three mechanisms on by default anywhere.** As implemented they are net-negative on
  BIRD (−2.0) and on full Spider2 (−2.2), and widening can generate runaway SQL.
- Keep them as **opt-in research switches** (`--ablation nogate` to force on; the individual
  `noconcept/noadaptive/hardstruct` remain for study). The proven-best default is `prebaseline` behaviour.
- Concrete redesign directions before they could earn a default:
  - **Widening**: hard-cap the *total* join count in generation, and only add ONE highest-confidence
    missing table (not up to 6 optional ones); or add a table only after an execution probe shows the
    grounded set is insufficient. The current "dump k neighbours as optional" over-joins.
  - **Concept alignment**: only surface *value-confirmed* bindings (suppress ambiguous ones, which add
    prompt noise), and never let output-concept hints add SELECT columns (BIRD SELECT-shape regressions).
  - **Soft skeleton**: keep the hard skeleton (it was a useful guardrail on strict whole-row grading).

**Context on `gate_by_graph` (`gws2/pipeline.py`):** it still correctly makes BIRD skip the mechanisms
(and the extra concept LLM call: 4.2 vs 5.1 calls/q, verified), i.e. it removes the BIRD regression. But
because Spider2 is inferred-graph, gating leaves the mechanisms ON there — where the 135-set shows −2.2.
So gating alone is not enough; the mechanisms themselves need the redesign above, or should default OFF.

> Methodological takeaway: the n=24 "+8.3" was noise; only the 135-set (and, ideally, multiple seeds)
> gave the trustworthy answer. Validate at scale before shipping.

> Caveats: Spider2-lite local is only n=24 (±~8 EX per 2 questions); confirm on the 135-question local
> set and/or multiple seeds before headline claims. BIRD n=100 variants fall in a 47–51 band that is
> near the established noise level, but prebaseline is consistently at the top.
