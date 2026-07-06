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

Planned Query Skeleton (MUST follow unless contradicted by schema evidence):
{skeleton}

Question:
{question}

Instructions:
- Follow the Planned Query Skeleton: if it requires INTERSECT/UNION/EXCEPT, nested query, \
GROUP BY/HAVING, ORDER BY/LIMIT, aggregation, or a specific SELECT arity, reflect that \
structure in the SQL.
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
- Use the exact fully qualified table names shown in the DDL/context.
- For BigQuery, use backticks around fully qualified table names. For sharded tables \
such as events_YYYYMMDD, prefer wildcard tables like `project.dataset.events_*` with \
_TABLE_SUFFIX filters when the question refers to a date range.
- For Snowflake, use DATABASE.SCHEMA.TABLE names when shown. If the DDL shows quoted \
lowercase column names such as "publication_date", you MUST use the exact quoted \
identifier in SQL; unquoted PUBLICATION_DATE is a different identifier and may fail. \
Use LATERAL FLATTEN for VARIANT arrays/objects when needed.
- Apply external knowledge literally, including formulas, mappings, date ranges, and \
domain-specific definitions.
- Return only the requested columns. Do not add helper columns.
- If the question asks for top/most/highest/lowest, use ORDER BY and LIMIT unless a \
subquery is clearly required.
- If the question asks for both A and B as separate membership conditions, consider \
INTERSECT or grouped HAVING.

SQL:"""
