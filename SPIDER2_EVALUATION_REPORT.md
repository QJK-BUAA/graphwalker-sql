# Spider2 Evaluation Report

Date: 2026-07-05

## Scope

This report records the Spider2 evaluation status for the current GraphWalker-SQL
2.0 implementation. The current production runner is SQLite-based:

`build_schema_graph -> anchor -> initialise_belief -> explore -> commit -> official eval`

Therefore, only Spider2-Lite local SQLite tasks are directly comparable as a
main result. Snowflake and DBT materials were inspected and tested separately to
avoid mixing incompatible evaluation protocols.

## Dataset Inventory

| Subset | Path | Size | Execution backend | Current status |
|---|---:|---:|---|---|
| Spider2-Lite | `ReFoRCE/spider2-lite/spider2-lite.jsonl` | 547 | BigQuery / Snowflake / SQLite | Local SQLite evaluated; cloud backends need adapter |
| Spider2-Lite local | `ReFoRCE/spider2-lite/resource/databases/spider2-localdb` | 135 | SQLite | Evaluated with official SQL-mode evaluator |
| Spider2-Snow | `ReFoRCE/spider2-snow/spider2-snow.jsonl` | 547 | Snowflake | Credentials verified; GraphWalker Snow generation not adapted |
| Spider2-DBT | `数据集/Spider2/spider2-dbt/examples/spider2-dbt.jsonl` | 68 | DBT / DuckDB project artifacts | Not a single-SQL task; requires a DBT/file-generation agent |

## Main Comparable Result

| Run | n | Official scorer | Correct | EX |
|---|---:|---|---:|---:|
| `spider2-lite-local_full_deepseek-chat_local135_colwalk_seed42` | 135 | `ReFoRCE/spider2-lite/evaluation_suite/evaluate.py --mode sql` | 31 | 22.96 |

Run artifact:

- `outputs/spider2-lite-local_full_deepseek-chat_local135_colwalk_seed42.json`
- `outputs/log_spider2-lite-local135_colwalk.txt`
- SQL submissions: `outputs/eval_work/spider2-lite-local_full_deepseek-chat_local135_colwalk_seed42/sql_submit/`

Execution summary:

| Metric | Value |
|---|---:|
| Pipeline execution OK | 126 / 135 |
| Pipeline execution error | 9 / 135 |
| Official correct | 31 / 135 |
| LLM calls | 548 |
| Input tokens | 478,852 |
| Output tokens | 110,051 |
| Avg path probes | 0.79 / question |
| Avg column probes | 15.16 / question |
| Wall time | 188.2 s with 8 workers |

For comparison, the 24-question `gold/sql` local subset under the current
Column/Value Belief Walk configuration scored 11/24 = 45.83:

- `outputs/spider2-lite_full_deepseek-chat_colwalk_n100_seed42.json`

The 135-question local full set is harder and includes many long-tail analytic
tasks not covered by the 24 SQL-gold subset, so the two numbers should not be
reported as the same benchmark.

## Snowflake Check

The Snowflake credential in `spider2凭证文件/snowflake_credential.json` was tested
with `SELECT 1` and is usable. The credential file was not stored in project
outputs.

As a compatibility stress test, the 135 SQLite-local predictions were renamed
from `local*.sql` to `sf_local*.sql` and submitted to the official Spider2-Snow
evaluator. This is not a main GraphWalker-SQL result because the SQL was
generated with SQLite schema and dialect assumptions.

| Test | n | Correct | EX | Interpretation |
|---|---:|---:|---:|---|
| SQLite SQL directly mapped to `sf_local*` | 135 | 0 | 0.00 | Snowflake requires schema qualification, Snow functions, and backend-specific grounding |

Artifacts:

- Mapped SQL: `outputs/snow_local_mapped/`
- Official Snow log: `outputs/snow_eval_work/evaluation_suite/log_gws2_snow_local_mapped.txt`
- Correct-ID CSV: `outputs/snow_local_mapped.csv`

Common failure mode:

`Object '<TABLE>' does not exist or not authorized.`

This confirms that full Spider2-Snow evaluation requires a proper Snowflake
adapter, not a direct reuse of the SQLite runner.

## DBT Status

Spider2-DBT is not a Text-to-SQL-only benchmark. Its official submission format
uses `results_metadata.jsonl`, and each instance may require a direct answer,
CSV file, DuckDB file, or DBT project output. The current GraphWalker-SQL commit
stage emits one SQL string, so it cannot honestly produce DBT submissions without
a separate file-generation/DBT execution agent.

## Required Adapter Work For Full Spider2

1. Snowflake backend:
   - parse local `DDL.csv` / JSON schema resources into `Schema`;
   - generate Snowflake SQL with fully qualified table names;
   - replace SQLite value/path/column probes with Snowflake probes;
   - run official `spider2-snow/evaluation_suite/evaluate.py`.

2. BigQuery backend for full Spider2-Lite:
   - load BigQuery schema resources;
   - generate BigQuery dialect SQL;
   - execute via official evaluator with BigQuery credentials.

3. DBT backend:
   - generate or edit project files;
   - run DBT/DuckDB locally;
   - emit official `results_metadata.jsonl` submissions.

Until those adapters exist, the clean publishable number for this codebase on
Spider2 is the official Spider2-Lite local SQLite full-set score: 22.96 on 135
examples.
