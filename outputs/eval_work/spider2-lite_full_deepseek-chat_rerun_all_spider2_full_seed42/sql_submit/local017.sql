WITH cause_counts AS (
    SELECT 
        strftime('%Y', collision_date) AS year,
        pcf_violation_category AS cause,
        COUNT(*) AS cnt
    FROM collisions
    WHERE pcf_violation_category IS NOT NULL
    GROUP BY year, cause
),
ranked_causes AS (
    SELECT 
        year,
        cause,
        cnt,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY cnt DESC) AS rn
    FROM cause_counts
),
top_two_per_year AS (
    SELECT 
        year,
        GROUP_CONCAT(cause, ', ' ORDER BY rn) AS top_two_causes
    FROM ranked_causes
    WHERE rn <= 2
    GROUP BY year
)
SELECT 
    t1.year
FROM top_two_per_year t1
WHERE t1.top_two_causes NOT IN (
    SELECT t2.top_two_causes
    FROM top_two_per_year t2
    WHERE t2.year != t1.year
)
LIMIT 1