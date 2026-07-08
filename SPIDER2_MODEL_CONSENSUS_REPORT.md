# Toward Spider2: Model Swap + Multi-Candidate Consensus

> Dataset: Spider2-lite **local 135** (official evaluator, timeout-safe). Base config =
> `prebaseline` (concept/adaptive/soft OFF — the best Spider2 base per the 135-set study).
> All runs: seed=42, 8 workers. Motivated by the leaderboard leaders (DivSkill-SQL, SOMA-SQL,
> ReFoRCE), whose common recipe is a strong reasoning model + multi-candidate selection.

## Results

| # | Config (135 local) | EX | correct | gen time | note |
|---|---|---:|---:|---:|---|
| A | chat single (`deepseek-chat`) | 19.26 | 26/135 | ~4 min | prior baseline |
| **B** | **+ R1 generation** (hybrid: chat aux, `deepseek-reasoner` gen) | **27.41** | **37/135** | ~16 min | **+8.1 EX** |
| C | + R1 generation + **K=5 result-consensus** | 23.70 | 32/135 | ~51 min | worse than B, 3.3x R1 tokens |

## Findings

**1. The model is the biggest lever — confirmed. Swapping only the SQL-generation call from
`deepseek-chat` to `deepseek-reasoner` (R1) gave +8.1 EX (19.26 -> 27.41).** This matches the
leaderboard, where the same method swings enormously with the model. The **hybrid** design keeps
it affordable: cheap `deepseek-chat` for the auxiliary calls (joinability, anchor, propose, plan)
and R1 only for generation/repair — 135 questions in ~16 min. (All-R1 was ~4x slower because R1
reasons over the full-DDL joinability call; hybrid avoids that.) R1 also produced *fewer* runaway
queries (2 non-terminating vs 4 for chat).

**2. Naive K=5 result-majority consensus did NOT help (27.41 -> 23.70) and cost 3.3x the R1
tokens.** Root cause is a documented failure mode (SOMA-SQL, Limitations): when the candidates
converge on the *same wrong* interpretation, majority vote locks in the systematic error, whereas
a single sample sometimes hits the right reading. Raw majority is the wrong selector — the
leaderboard leaders never use it alone; they select via **ambiguity probing / LLM-judge / diverse
skills**. (Caveat: n=135 single-run noise is ~±3-4 EX, so C-vs-B is near noise, but combined with
3.3x cost and the known failure mode, naive consensus is clearly not the lever.)

Cost detail: B used R1 = 222 calls / 638K output tokens; C used R1 = 702 calls / 2.09M output
tokens for a lower score.

## What this means for chasing SOTA

- **Do the model swap — it is the single biggest, cheapest win.** Use R1 for generation (done),
  and if budget allows a frontier model (GPT-5 / o-series / Claude-Opus) for generation would push
  further; the leaderboard top (72-73) all use frontier models.
- **Drop naive majority consensus. Replace it with smart selection** = SOMA-SQL-style ambiguity
  probing, which is the principled evolution of GraphWalker's own belief-probing idea: use
  cross-candidate *disagreement* to find the ambiguous decision, fire targeted probe SQLs to
  gather data evidence, then select/repair. This is the differentiating, publishable direction.
- **Add iterative decomposition / more repair rounds** for the 48-line CTE analytical queries.

> Honest framing: on `deepseek-*` models, matching the 72% leaderboard SOTA is not attainable
> (that needs frontier models). Realistic, defensible targets: best result among DeepSeek/open
> models, or best accuracy-per-cost. B (27.41, hybrid, single SQL) is a strong, cheap starting
> point; the next real gains come from a stronger generation model + ambiguity-probing selection.
