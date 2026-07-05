-- Count actors whose active career has no gap of 4+ consecutive years without a film credit
WITH actor_years AS (
    SELECT DISTINCT
        p.PID,
        CAST(SUBSTR(mc.MID, 1, 4) AS INTEGER) AS year
    FROM Person p
    JOIN M_Cast mc ON p.PID = mc.PID
    WHERE mc.MID LIKE 'tt%' AND SUBSTR(mc.MID, 1, 4) GLOB '[0-9][0-9][0-9][0-9]'
),
actor_career AS (
    SELECT
        PID,
        MIN(year) AS first_year,
        MAX(year) AS last_year
    FROM actor_years
    GROUP BY PID
),
actor_gaps AS (
    SELECT
        a.PID,
        a.year,
        LEAD(a.year) OVER (PARTITION BY a.PID ORDER BY a.year) AS next_year
    FROM actor_years a
),
gap_lengths AS (
    SELECT
        PID,
        next_year - year AS gap_years
    FROM actor_gaps
    WHERE next_year IS NOT NULL
),
actors_with_long_gap AS (
    SELECT DISTINCT PID
    FROM gap_lengths
    WHERE gap_years >= 4
)
SELECT COUNT(*) AS actor_count
FROM actor_career ac
WHERE ac.PID NOT IN (SELECT PID FROM actors_with_long_gap)