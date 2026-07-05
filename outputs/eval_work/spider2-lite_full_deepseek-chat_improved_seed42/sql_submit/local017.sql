-- Step 1: Identify the two most common causes (PCF violation categories) per year
-- Step 2: Compare across years to find the year where the top 2 differ from all others
WITH yearly_top_causes AS (
    SELECT 
        strftime('%Y', collision_date) AS year,
        pcf_violation_category,
        COUNT(*) AS cnt,
        ROW_NUMBER() OVER (PARTITION BY strftime('%Y', collision_date) ORDER BY COUNT(*) DESC) AS rn
    FROM collisions
    WHERE pcf_violation_category IS NOT NULL
    GROUP BY year, pcf_violation_category
),
yearly_top2 AS (
    SELECT year, pcf_violation_category, rn
    FROM yearly_top_causes
    WHERE rn <= 2
),
-- Get the set of top-2 causes for each year as a concatenated string
yearly_top2_set AS (
    SELECT year,
           GROUP_CONCAT(pcf_violation_category ORDER BY pcf_violation_category) AS top2_set
    FROM yearly_top2
    GROUP BY year
),
-- Find the most common top2_set across years
common_set AS (
    SELECT top2_set, COUNT(*) AS cnt
    FROM yearly_top2_set
    GROUP BY top2_set
    ORDER BY cnt DESC
    LIMIT 1
)
-- Find the year(s) whose top2_set is different from the most common one
SELECT y.year
FROM yearly_top2_set y
WHERE y.top2_set != (SELECT top2_set FROM common_set)