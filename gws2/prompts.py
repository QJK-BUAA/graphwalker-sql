"""System prompts for GraphWalker-SQL 2.0.

Each prompt corresponds to one white-box LLM decision in the Ground / Explore /
Commit pipeline. Prompts are deliberately terse and force single-line or single
code-block outputs so parsing stays deterministic.
"""

# --------------------------------------------------------------------------- #
# Ground: LLM-guided joinability discovery (FK-sparse schemas).
# HTML section 4: infer candidate edges from table/column names + types.
# --------------------------------------------------------------------------- #
PROMPT_JOINABILITY = """You are a database schema analyzer. Infer likely joinable \
column pairs (foreign-key-like relationships) from DDL that may NOT declare foreign keys.
Infer purely from table names, column names and types (e.g. 'user_id' likely \
references 'users.id'; 'dept_id' references 'department.dept_id').

Rules:
- One relationship per line, EXACT format: source_table.source_column -> target_table.target_column
- Use table/column names exactly as they appear in the DDL.
- The target column should be a key-like / referenced column (often a primary key).
- Do NOT invent names. Do NOT output explanations.
- If nothing can be reasonably inferred, output exactly: NONE"""

# --------------------------------------------------------------------------- #
# Ground: intent decomposition + source/destination anchoring.
# HTML section 3 (Ground) + POMDP action SearchColumn/SearchValue.
# --------------------------------------------------------------------------- #
PROMPT_ANCHOR = """You map a natural-language question to a database schema.

Identify:
- src: tables whose columns are used in FILTER / WHERE conditions.
- dst: tables that supply the RETURNED / SELECTED columns.
- literals: quoted or clearly-literal filter values mentioned in the question \
(e.g. 'Computer Science', 2020, 'Soccer'). These become candidate filter values.

Output EXACTLY three lines, nothing else:
src=TableA,TableB
dst=TableC
literals=value1;value2

Use only table names from the provided schema. If there are no literals, write \
literals= (empty)."""

# --------------------------------------------------------------------------- #
# Ground: query-centric concept decomposition (Point 1).
# The dominant BIRD/Spider error is "right table, wrong column" / a concept that
# lives in several tables. Before grounding columns, decompose the QUESTION into
# the atomic concepts it needs, each of which must map to exactly one column.
# --------------------------------------------------------------------------- #
PROMPT_CONCEPTS = """You decompose a natural-language question into the atomic \
CONCEPTS it needs from the database, so each concept can later be grounded to a \
single column.

For every concept, output ONE line, EXACT format:
concept=<short noun phrase> | role=output|filter | value=<literal or empty>

Rules:
- role=output: the concept is RETURNED / SELECTED, aggregated, or used to sort.
- role=filter: the concept constrains rows (WHERE / HAVING). If the question gives \
its literal value, put it in value= (e.g. value=Computer Science); else leave empty.
- Use short phrases taken from the question's own wording (1-4 words).
- One concept per line, at most 8 lines. Output nothing except these lines.
- If the question only counts/returns rows, still output its main concept(s)."""

# --------------------------------------------------------------------------- #
# Explore: path disambiguation among top-k candidate join paths.
# HTML section 3 (Explore) + POMDP action FindTopKPaths / Probe.
# --------------------------------------------------------------------------- #
PROMPT_PATH_SELECT = """You are choosing the join path that best matches the SEMANTICS \
of a question, not merely the shortest one (beware the shortest-path paradox: the \
physically shortest join is often semantically wrong).

Given the question and candidate join paths (each a table sequence with join \
conditions and a probe summary), pick the single path that connects all entities \
the question actually needs.

Output exactly one line: path=<ID>"""

# --------------------------------------------------------------------------- #
# Commit: Propose evidence check (anti-hallucination checkpoint).
# HTML section 3 (Commit): verify every table/column/value/path has support.
# --------------------------------------------------------------------------- #
PROMPT_PROPOSE = """You are auditing a grounded schema subgraph before SQL generation.
Given the question and the proposed tables, join conditions and filter columns/values, \
decide whether the subgraph has enough evidence to answer the question.

Check:
- Are all entities in the question covered by some table/column?
- Is any obviously-required concept missing (mark as an unresolved concept, do NOT invent it)?

Output EXACTLY two lines:
verdict=OK|MISSING
missing=<comma-separated table names to add, or empty>"""

# --------------------------------------------------------------------------- #
# Commit: structure-aware SQL planning before final generation.
# This is deliberately a small, parseable skeleton rather than a full SQL draft:
# Ground/Explore decide "what to query"; this step decides "how to query".
# --------------------------------------------------------------------------- #
PROMPT_STRUCTURE_PLAN = """You are a {dialect} query-structure planner for Text-to-SQL.
Given the question, grounded schema, validated join path and belief evidence, decide \
the minimal SQL STRUCTURE needed before writing SQL.

Grounded Schema:
{schema}

Validated Join Path / Conditions:
{join_path}

External Knowledge:
{evidence}

Grounding Hints:
{hints}

Question:
{question}

Return JSON ONLY, with exactly these keys:
{{
  "set_op": "none|intersect|union|except",
  "nested": true|false,
  "group_by": true|false,
  "having": true|false,
  "order_by": true|false,
  "limit": true|false,
  "select_arity": 1,
  "aggregation": true|false,
  "notes": "short reason"
}}

Rules:
- Use "intersect" for questions asking for entities satisfying BOTH separate conditions \
that are naturally expressed as two result sets (e.g. "A and B", "both cat and dog").
- Use "except" for "A but not B", "does not have", "without", unless NOT IN is clearly simpler.
- Mark nested=true for superlatives, comparisons against aggregate values, NOT IN/EXISTS, \
or questions requiring a subquery.
- Mark group_by/having for per-group aggregation or group filters.
- Mark order_by/limit for top-k, highest/lowest, most/least, maximum/minimum entity queries.
- select_arity is the number of result columns asked by the question, not helper columns.
- aggregation=true only when the final answer needs COUNT/SUM/AVG/MAX/MIN or grouped aggregation.
- Do not invent columns. Do not output SQL."""

# --------------------------------------------------------------------------- #
# Commit: final SQL generation from the grounded subgraph. One SQL only.
# --------------------------------------------------------------------------- #
PROMPT_GENERATE = """Task Overview:
You are a {dialect} query-generation specialist. Given a FILTERED schema (only the \
grounded tables), a validated join path, grounding hints and a planned query skeleton, \
generate exactly ONE valid {dialect} query answering the question.

Database Engine:
{dialect}

Grounded Schema:
{schema}

Validated Join Path / Conditions:
{join_path}

External Knowledge (MUST be applied literally):
{evidence}

Grounding Hints (belief-derived; prefer these bindings):
{hints}

Suggested Query Skeleton (a soft prior from a planner; usually right, but you MAY \
deviate when the question or schema clearly calls for a different shape):
{skeleton}

Question:
{question}

Instructions:
- Treat the Suggested Query Skeleton as a helpful default, not a hard rule: prefer its \
INTERSECT/UNION/EXCEPT, nesting, GROUP BY/HAVING, ORDER BY/LIMIT, aggregation and SELECT \
arity, but override it if faithfully answering the question needs a different structure.
- The External Knowledge above is authoritative: apply every definition, formula and \
value mapping it gives (e.g. if it says a concept equals column=VALUE, add that filter; \
if it defines a ratio as a/b, compute exactly that expression).
- Return only the information asked; do not add extra columns.
- Use only columns present in the grounded schema. Do not invent names.
- Use the provided join conditions when joining tables.
- For string filters, prefer exact match when the question gives an exact value; \
otherwise use LIKE.
- For any ratio / percentage / average of integer columns, CAST operands to REAL \
(e.g. CAST(x AS REAL) / y) to avoid integer division.
- If rounding is needed and no precision is specified, keep four decimals.
- Think through the steps internally, then output only the query.

Output Format:
```sql
-- one query
```"""

# --------------------------------------------------------------------------- #
# Commit: single targeted repair (execution error OR empty result).
# By design at most once; NOT an unbounded self-refine loop.
# --------------------------------------------------------------------------- #
PROMPT_REPAIR = """The previous {dialect} query {problem}. Using the grounded schema, \
the failed query and the feedback, output ONE corrected {dialect} query. Do not explain.

Grounded Schema:
{schema}

Planned Query Skeleton:
{skeleton}

External Knowledge (MUST be applied literally):
{evidence}

Question:
{question}

Previous SQL:
{sql}

Feedback:
{feedback}

Output only:
```sql
-- corrected query
```"""

# --------------------------------------------------------------------------- #
# Commit: column alignment (BIRD EX compares whole-row SETS, so an otherwise
# correct answer with extra/reordered SELECT columns is judged wrong). This step
# ONLY touches the SELECT list: keep exactly the columns the question asks for,
# in the order the question mentions them. It must not change tables, joins,
# filters, grouping, ordering or add/remove rows.
# --------------------------------------------------------------------------- #
PROMPT_COLUMN_ALIGN = """You are aligning the SELECT list of a correct {dialect} query \
to exactly what the question asks for. BIRD grades on the whole result row, so extra \
or reordered columns cause a wrong answer even when the data is right.

Rules:
- Change ONLY the SELECT list. Keep FROM/JOIN/WHERE/GROUP BY/HAVING/ORDER BY/LIMIT \
byte-for-byte identical.
- Output exactly the column(s) the question requests, in the order the question \
mentions them. Drop id/helper/extra columns that the question does not ask for.
- Do NOT add DISTINCT, aggregates, casts, or new columns. Do NOT change row count.
- If the current SELECT already matches the question exactly, return it unchanged.

Question:
{question}

Current SQL:
{sql}

Output only:
```sql
-- aligned query
```"""

# --------------------------------------------------------------------------- #
# Spider2-Lite online SQL generation (BigQuery/Snowflake).
# Used by the online adapter before a full remote-probe backend is available.
# --------------------------------------------------------------------------- #
PROMPT_SPIDER2_ONLINE_SQL = """You are a Spider2-Lite {dialect} SQL specialist.
Generate exactly ONE executable SQL query for the question using the provided schema \
and external knowledge.

Dialect:
{dialect}

Schema / DDL context:
{schema_context}

External knowledge:
{external_knowledge}

Question:
{question}

Instructions:
- Output SQL only. Do NOT use Markdown fences. Do NOT explain.
- Use only tables and columns present in the schema context.
- CRITICAL: each table is preceded by a line "USE THIS EXACT TABLE NAME IN SQL: \
<name>". You MUST use that exact fully-qualified name verbatim in FROM/JOIN. Do \
NOT invent or shorten the database/schema prefix.
- For BigQuery, use backticks around fully qualified table names. For sharded tables \
such as events_YYYYMMDD, prefer wildcard tables like `project.dataset.events_*` with \
_TABLE_SUFFIX filters when the question refers to a date range.
- For Snowflake, always use the 3-part DATABASE.SCHEMA.TABLE name exactly as given \
(do NOT guess the schema; e.g. it is often NOT "PUBLIC"). If the DDL shows quoted \
lowercase column names such as "publication_date", you MUST use the exact quoted \
identifier in SQL; unquoted PUBLICATION_DATE is a different identifier and may fail. \
Use LATERAL FLATTEN for VARIANT arrays/objects. Avoid correlated subqueries Snowflake \
cannot evaluate; prefer JOINs or window functions.
- Apply external knowledge literally, including formulas, mappings, date ranges, and \
domain-specific definitions.
- Return only the requested columns. Do not add helper columns.
- If the question asks for top/most/highest/lowest, use ORDER BY and LIMIT unless a \
subquery is clearly required.
- If the question asks for both A and B as separate membership conditions, consider \
INTERSECT or grouped HAVING.

SQL:"""


PROMPT_SPIDER2_ONLINE_REPAIR = """You previously wrote a {dialect} query that {problem}.
Fix it and output exactly ONE corrected {dialect} SQL query.

Schema / DDL context:
{schema_context}

External knowledge:
{external_knowledge}

Question:
{question}

Previous SQL:
{sql}

Execution feedback:
{feedback}

Repair instructions:
- Output SQL only. Do NOT use Markdown fences. Do NOT explain.
- Use only tables/columns in the schema context and keep fully qualified names.
- If the feedback is an invalid-identifier or not-found error, correct the exact \
table/column name (mind BigQuery backticks and Snowflake case-sensitive quoted names).
- If the feedback says the result was empty, relax an over-strict filter or fix a \
join/date-range condition rather than removing needed logic.
- If the feedback is a cost-guard refusal, add a selective filter (date range, \
_TABLE_SUFFIX, WHERE, or a narrower table) so the scan is smaller.
- Keep the answer's column shape aligned with what the question asks.

SQL:"""


# Snowflake dialect cheat-sheet. Injected into generate + repair prompts for the
# snowflake backend. Each rule targets a concrete failure seen on Spider2-Lite
# PATENTS/GOOGLE (Unsupported subquery, lateral+OUTER JOIN, date sentinels,
# VARIANT access, unknown functions).
PROMPT_SNOWFLAKE_DIALECT = """Snowflake dialect rules (follow strictly):
1. VARIANT/array columns (e.g. "citation", "inventor", "abstract_localized"):
   flatten with `, LATERAL FLATTEN(input => t."col") f` and read elements as
   `f.value:"key"::TYPE` (e.g. f.value:"name"::STRING). Do NOT use BigQuery
   UNNEST.
2. NEVER put a LATERAL FLATTEN inside a correlated scalar subquery that
   references the outer row (Snowflake raises "Unsupported subquery type cannot
   be evaluated"). Instead pre-aggregate in a CTE: flatten + GROUP BY the key,
   then JOIN that CTE back to the main table.
3. Do NOT combine `CROSS JOIN LATERAL FLATTEN(...)` with an OUTER JOIN. Use a
   plain comma lateral `, LATERAL FLATTEN(input => x) f`, or
   `LATERAL FLATTEN(input => x, OUTER => TRUE)` when you need to keep rows with
   empty arrays.
4. Integer date columns stored as YYYYMMDD (e.g. "publication_date",
   "filing_date") often use 0 as a missing sentinel. Guard before parsing:
   `TO_DATE(TO_VARCHAR(NULLIF(x, 0)), 'YYYYMMDD')`, and filter `x > 0` (or
   `BETWEEN` a real range) before any date math. Never TO_DATE a raw 0.
5. Prefer JOINs / window functions over correlated subqueries. Replace
   `(SELECT COUNT(*) ... WHERE inner.k = outer.k)` with a GROUP BY CTE + JOIN.
6. Use Snowflake functions: DATEADD/DATEDIFF, DATE_TRUNC('MONTH', d),
   ARRAY_SIZE(arr), LISTAGG, IFF, TO_VARCHAR/TO_DATE. Avoid BigQuery-only names
   (SAFE_CAST, PARSE_DATE, GENERATE_DATE_ARRAY, APPROX_*).
7. Keep double-quoted, case-sensitive column identifiers exactly as shown."""
