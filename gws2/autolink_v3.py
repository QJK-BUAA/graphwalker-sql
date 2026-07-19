"""Official-grade AutoLink SQL stack with GraphWalker safety controls.

This module ports the parts that materially improved the official reproduction:
five independent Reasoner candidates, bounded execution-guided revision for
every failed candidate, result-equivalence clustering, and Reasoner tie-breaks.
It intentionally keeps GraphWalker's BigQuery dry-run guard, bounded retries,
Snowflake quoting fallback, and checkpoint-friendly structured metadata.
"""
from __future__ import annotations

import itertools
import importlib.util
import math
import re
from dataclasses import dataclass, field

from . import config
from .cloud_execute import CloudResult, run_bigquery, run_snowflake
from .execute import run_query
from .llm import LLM
from .prompts import PROMPT_SNOWFLAKE_DIALECT


@dataclass
class ExecutionResult:
    ok: bool
    columns: list[str] = field(default_factory=list)
    rows: list[tuple] = field(default_factory=list)
    n_shown: int = 0
    error: str = ""
    est_gb: float | None = None
    skipped_cost: bool = False


@dataclass
class SQLCandidate:
    index: int
    sql: str
    execution: ExecutionResult
    source: str = "generated"
    revisions: int = 0
    quote_fixed: bool = False


@dataclass(frozen=True)
class PromptBundle:
    sql_generation: str
    revise_error: str
    sql_selection: str
    bigquery_rules: str
    snowflake_rules: str
    sqlite_rules: str


def load_official_prompts(config_path: str) -> PromptBundle:
    """Load prompt constants from a cloned official AutoLink repository."""
    spec = importlib.util.spec_from_file_location(
        "official_autolink_config", config_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load AutoLink config: {config_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return PromptBundle(
        sql_generation=module.SQL_GENERATION,
        revise_error=module.REVISE_ERROR,
        sql_selection=module.SQL_SELECTION,
        bigquery_rules=module.BIGQUERY_DIALECT_OPTIMIZATION_SQL_GEN,
        snowflake_rules=module.SNOWFLAKE_DIALECT_OPTIMIZATION_SQL_GEN,
        sqlite_rules=module.SQLITE_DIALECT_OPTIMIZATION_SQL_GEN,
    )


GENERATION_SYSTEM = """You are a professional data engineer. Generate one correct
{dialect} SQL query for a difficult real-world Text-to-SQL task.

Use ONLY tables and columns in the linked schema. Reproduce every calculation,
filter, date range, grouping, ranking and output requirement. Prefer named CTEs
for multi-step analysis and window functions where appropriate.

{dialect_rules}

Output reasoning if useful, then put the final complete query in the LAST
```sql``` block."""


GENERATION_USER = """Question:
{question}

Final linked schema and external knowledge:
{schema}
"""


REVISION_SYSTEM = """You are repairing a {dialect} SQL query using real execution
feedback. Preserve correct logic, fix the root cause, and use only identifiers
from the linked schema. Return the corrected complete SQL in the LAST ```sql```
block.

{dialect_rules}

Linked schema:
{schema}

Question:
{question}
"""


REVISION_USER = """Previous SQL:
{sql}

Execution feedback:
{error}

Repair the SQL."""


SELECTION_SYSTEM = """Select which SQL result more correctly answers the question.
Compare semantics, required output shape, filters, aggregation grain and result
plausibility. Respond with exactly SQL1 or SQL2."""


SELECTION_USER = """Dialect: {dialect}
Question: {question}

Linked schema:
{schema}

SQL1:
{sql1}
Result1:
{result1}

SQL2:
{sql2}
Result2:
{result2}
"""


_SQL_BLOCK = re.compile(r"```sql\s*(.*?)```", re.I | re.S)


def extract_sql(text: str) -> str:
    matches = _SQL_BLOCK.findall(text or "")
    if matches:
        return matches[-1].strip().rstrip(";")
    generic = re.findall(r"```\s*(.*?)```", text or "", re.S)
    if generic:
        return generic[-1].strip().rstrip(";")
    return (text or "").strip().rstrip(";")


def _dialect(ex) -> str:
    if ex.backend == "bigquery":
        return "BigQuery"
    if ex.backend == "snowflake":
        return "Snowflake"
    return "SQLite"


def _dialect_rules(ex) -> str:
    if ex.backend == "snowflake":
        return PROMPT_SNOWFLAKE_DIALECT
    if ex.backend == "bigquery":
        return (
            "Use fully-qualified backtick table names, BigQuery functions and "
            "_TABLE_SUFFIX filters for wildcard tables. Use UNNEST for arrays."
        )
    return (
        "Use SQLite functions. Quote exact identifiers. Use julianday/strftime "
        "for date arithmetic when needed."
    )


def _bundle_rules(ex, prompts: PromptBundle) -> str:
    if ex.backend == "bigquery":
        return prompts.bigquery_rules
    if ex.backend == "snowflake":
        return prompts.snowflake_rules
    return prompts.sqlite_rules


def _quote_snowflake(sql: str) -> str:
    try:
        import sqlglot
        return sqlglot.transpile(
            sql, read="snowflake", write="snowflake",
            identify=True, pretty=True)[0]
    except Exception:  # noqa: BLE001
        return sql


def _from_cloud(result: CloudResult) -> ExecutionResult:
    return ExecutionResult(
        ok=result.ok,
        columns=list(result.columns or []),
        rows=[tuple(row) for row in (result.rows or [])],
        n_shown=result.n_shown,
        error=result.error or "",
        est_gb=result.est_gb,
        skipped_cost=result.skipped_cost,
    )


def execute_sql(ex, sql: str, max_rows: int = 1000,
                timeout: float = config.CLOUD_EXEC_TIMEOUT
                ) -> tuple[str, ExecutionResult, bool]:
    if ex.backend == "local":
        result = run_query(ex.sqlite_path, sql, max_rows=max_rows,
                           timeout=timeout)
        converted = ExecutionResult(
            ok=bool(result.get("ok")),
            columns=list(result.get("columns") or []),
            rows=[tuple(row) for row in (result.get("rows") or [])],
            n_shown=int(result.get("n_shown") or 0),
            error=str(result.get("error") or ""),
        )
        return sql, converted, False
    if ex.backend == "bigquery":
        result = _from_cloud(run_bigquery(
            sql, max_rows=max_rows, max_gb=config.BQ_DRYRUN_MAX_GB,
            timeout=timeout))
        return sql, result, False

    result = _from_cloud(run_snowflake(
        sql, database=ex.db_id, max_rows=max_rows, timeout=timeout))
    if result.ok:
        return sql, result, False
    quoted = _quote_snowflake(sql)
    if not quoted or quoted.strip() == sql.strip():
        return sql, result, False
    quoted_result = _from_cloud(run_snowflake(
        quoted, database=ex.db_id, max_rows=max_rows, timeout=timeout))
    if quoted_result.ok:
        return quoted, quoted_result, True
    return sql, result, False


def _is_usable(result: ExecutionResult) -> bool:
    return result.ok and result.n_shown > 0


def _result_preview(result: ExecutionResult, max_rows: int = 30,
                    max_chars: int = 10000) -> str:
    lines = ["columns: " + ", ".join(map(str, result.columns))]
    lines.extend(repr(row) for row in result.rows[:max_rows])
    return "\n".join(lines)[:max_chars]


def _sort_key(value):
    return (value is None, str(value), isinstance(value, (int, float)))


def _cell_equal(a, b, tolerance: float = 1e-2) -> bool:
    if a is None and b is None:
        return True
    try:
        if isinstance(a, (int, float)) and isinstance(b, (int, float)):
            return math.isclose(float(a), float(b), abs_tol=tolerance)
    except (TypeError, ValueError):
        pass
    return str(a) == str(b)


def _vector_equal(first: list, second: list,
                  ignore_order: bool = True) -> bool:
    if len(first) != len(second):
        return False
    if ignore_order:
        first = sorted(first, key=_sort_key)
        second = sorted(second, key=_sort_key)
    return all(_cell_equal(a, b) for a, b in zip(first, second))


def results_equivalent(first: ExecutionResult,
                       second: ExecutionResult) -> bool:
    """Mirror AutoLink's permissive, column-name-agnostic result comparison."""
    if not _is_usable(first) or not _is_usable(second):
        return False
    first_columns = [list(col) for col in zip(*first.rows)]
    second_columns = [list(col) for col in zip(*second.rows)]
    for column in first_columns:
        if not any(_vector_equal(column, other) for other in second_columns):
            return False
    return True


def cluster_candidates(candidates: list[SQLCandidate]
                       ) -> list[list[SQLCandidate]]:
    clusters: list[list[SQLCandidate]] = []
    for candidate in candidates:
        if not _is_usable(candidate.execution):
            continue
        for cluster in clusters:
            if results_equivalent(candidate.execution,
                                  cluster[0].execution):
                cluster.append(candidate)
                break
        else:
            clusters.append([candidate])
    return clusters


def generate_candidates(ex, schema: str, llm: LLM, count: int = 5,
                        prompts: PromptBundle | None = None
                        ) -> list[SQLCandidate]:
    if prompts is not None:
        system = "You are an expert Text-to-SQL data engineer."
        user = (prompts.sql_generation
                .replace("{PROMPT}", schema)
                .replace("{QUESTION}", ex.question)
                .replace("{SQL_DIALECT_OPTIMIZATION}",
                         _bundle_rules(ex, prompts))
                .replace("{SQL_TYPE}", _dialect(ex)))
    else:
        system = GENERATION_SYSTEM.format(
            dialect=_dialect(ex), dialect_rules=_dialect_rules(ex))
        user = GENERATION_USER.format(
            question=ex.question, schema=schema[:220000])
    candidates = []
    for index in range(count):
        response = llm.complete(system, user, temperature=1.0)
        sql = extract_sql(response)
        sql, execution, quote_fixed = execute_sql(ex, sql)
        candidates.append(SQLCandidate(
            index=index, sql=sql, execution=execution,
            quote_fixed=quote_fixed))
    return candidates


def revise_candidate(ex, schema: str, candidate: SQLCandidate, llm: LLM,
                     max_revisions: int = 5,
                     prompts: PromptBundle | None = None) -> SQLCandidate:
    if _is_usable(candidate.execution):
        return candidate
    if prompts is not None:
        initial = (prompts.revise_error
                   .replace("{PROMPT}", schema[:200000])
                   .replace("{QUESTION}", ex.question)
                   .replace("{SQL}", candidate.sql)
                   .replace("{ERROR_MESSAGE}",
                            candidate.execution.error
                            or "Query returned no rows")
                   .replace("{SQL_DIALECT_OPTIMIZATION}",
                            _bundle_rules(ex, prompts))
                   .replace("{SQL_TYPE}", _dialect(ex)))
        messages = [{"role": "user", "content": initial}]
    else:
        system = REVISION_SYSTEM.format(
            dialect=_dialect(ex), dialect_rules=_dialect_rules(ex),
            schema=schema[:200000], question=ex.question)
        messages = [
            {"role": "system", "content": system},
            {"role": "user", "content": REVISION_USER.format(
                sql=candidate.sql,
                error=candidate.execution.error or "Query returned no rows")},
        ]
    for attempt in range(max_revisions):
        response = llm.complete_messages(messages, temperature=0.0)
        revised_sql = extract_sql(response)
        revised_sql, execution, quote_fixed = execute_sql(ex, revised_sql)
        candidate.sql = revised_sql
        candidate.execution = execution
        candidate.source = "revised"
        candidate.revisions = attempt + 1
        candidate.quote_fixed = candidate.quote_fixed or quote_fixed
        if _is_usable(execution):
            break
        messages.extend([
            {"role": "assistant", "content": response},
            {"role": "user", "content": (
                "Execution error:\n"
                + (execution.error or "Query returned no rows")
                + "\nRevise the SQL again."
            )},
        ])
    return candidate


def _judge_tied_clusters(ex, schema: str,
                         clusters: list[list[SQLCandidate]], llm: LLM,
                         prompts: PromptBundle | None = None) -> SQLCandidate:
    representatives = [cluster[0] for cluster in clusters]
    scores = {candidate.index: 0 for candidate in representatives}
    for first, second in itertools.combinations(representatives, 2):
        if prompts is not None:
            system = "Select the better SQL. Output SQL1 or SQL2 only."
            user = (prompts.sql_selection
                    .replace("{Database_Schema}", schema[:120000])
                    .replace("{Question}", ex.question)
                    .replace("{dialect}", _dialect(ex))
                    .replace("{sql1}", first.sql)
                    .replace("{re1}", _result_preview(first.execution))
                    .replace("{sql2}", second.sql)
                    .replace("{re2}", _result_preview(second.execution)))
        else:
            system = SELECTION_SYSTEM
            user = SELECTION_USER.format(
                dialect=_dialect(ex), question=ex.question,
                schema=schema[:120000],
                sql1=first.sql, result1=_result_preview(first.execution),
                sql2=second.sql, result2=_result_preview(second.execution))
        response = llm.complete(system, user, temperature=0.0).upper()
        if "SQL1" in response:
            scores[first.index] += 1
        elif "SQL2" in response:
            scores[second.index] += 1
    best = max(scores, key=lambda index: scores[index])
    return next(candidate for candidate in representatives
                if candidate.index == best)


def select_candidate(ex, schema: str, candidates: list[SQLCandidate],
                     llm: LLM, prompts: PromptBundle | None = None
                     ) -> tuple[SQLCandidate, dict]:
    clusters = cluster_candidates(candidates)
    if not clusters:
        return candidates[0], {
            "decision": "all_failed",
            "cluster_sizes": [],
            "selected_index": candidates[0].index,
        }
    clusters.sort(key=len, reverse=True)
    largest = len(clusters[0])
    tied = [cluster for cluster in clusters if len(cluster) == largest]
    if len(tied) == 1:
        selected = tied[0][0]
        decision = f"unique_plurality_{largest}"
    else:
        selected = _judge_tied_clusters(
            ex, schema, tied, llm, prompts=prompts)
        decision = f"reasoner_tie_{len(tied)}"
    return selected, {
        "decision": decision,
        "cluster_sizes": [len(cluster) for cluster in clusters],
        "selected_index": selected.index,
    }


def solve(ex, schema: str, llm: LLM, num_candidates: int = 5,
          max_revisions: int = 5,
          prompts: PromptBundle | None = None) -> tuple[str, dict]:
    candidates = generate_candidates(
        ex, schema, llm, count=num_candidates, prompts=prompts)
    candidates = [
        revise_candidate(ex, schema, candidate, llm,
                         max_revisions=max_revisions, prompts=prompts)
        for candidate in candidates
    ]
    selected, selection = select_candidate(
        ex, schema, candidates, llm, prompts=prompts)
    metadata = {
        "selection": selection,
        "candidates": [
            {
                "index": candidate.index,
                "sql": candidate.sql,
                "source": candidate.source,
                "revisions": candidate.revisions,
                "quote_fixed": candidate.quote_fixed,
                "ok": candidate.execution.ok,
                "rows": candidate.execution.n_shown,
                "error": candidate.execution.error[:500],
                "est_gb": candidate.execution.est_gb,
            }
            for candidate in candidates
        ],
    }
    return selected.sql or "SELECT 1", metadata
