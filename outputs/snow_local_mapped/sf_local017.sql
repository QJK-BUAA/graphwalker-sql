-- Step 1: Identify the two most common causes (PCF violation categories) per year
-- Step 2: Compare across years to find the year where the top 2 differ from all others
WITH yearly_causes AS (
    SELECT 
        strftime('%Y', collision_date) AS year,
        pcf_violation_category,
        COUNT(*) AS cnt
    FROM collisions
    WHERE pcf_violation_category IS NOT NULL
    GROUP BY year, pcf_violation_category
),
ranked_causes AS (
    SELECT 
        year,
        pcf_violation_category,
        cnt,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY cnt DESC) AS rn
    FROM yearly_causes
),
top2_per_year AS (
    SELECT year, pcf_violation_category, rn
    FROM ranked_causes
    WHERE rn <= 2
),
-- Get the set of top-2 causes for each year as a concatenated string
year_top2 AS (
    SELECT 
        year,
        GROUP_CONCAT(pcf_violation_category ORDER BY rn) AS top2_causes
    FROM top2_per_year
    GROUP BY year
),
-- Find the most common top2 pattern (excluding the year we're looking for)
common_pattern AS (
    SELECT top2_causes, COUNT(*) AS freq
    FROM year_top2
    GROUP BY top2_causes
    ORDER BY freq DESC
    LIMIT 1
)
-- Return the year(s) whose top2 causes differ from the most common pattern
SELECT yt.year
FROM year_top2 yt
WHERE yt.top2_causes NOT IN (SELECT top2_causes FROM common_pattern)