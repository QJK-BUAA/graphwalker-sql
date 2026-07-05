-- Step 1: Identify the two most common causes (PCF violation categories) per year
-- Step 2: Compare across years to find the year where the top 2 differ from all other years
WITH yearly_top_causes AS (
    SELECT 
        strftime('%Y', collision_date) AS year,
        pcf_violation_category,
        COUNT(*) AS cause_count,
        ROW_NUMBER() OVER (PARTITION BY strftime('%Y', collision_date) ORDER BY COUNT(*) DESC) AS rn
    FROM collisions
    WHERE pcf_violation_category IS NOT NULL AND pcf_violation_category != ''
    GROUP BY year, pcf_violation_category
),
yearly_top2 AS (
    SELECT year, pcf_violation_category, rn
    FROM yearly_top_causes
    WHERE rn <= 2
),
-- Get the set of top-2 causes for all years except the candidate
other_years_top2 AS (
    SELECT DISTINCT pcf_violation_category
    FROM yearly_top2
    WHERE year != (SELECT DISTINCT year FROM yearly_top2 GROUP BY year HAVING COUNT(*) = 2)
),
-- For each year, check if its top-2 causes are different from all other years
year_comparison AS (
    SELECT 
        yt.year,
        GROUP_CONCAT(yt.pcf_violation_category ORDER BY yt.rn) AS causes,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM other_years_top2 oy 
                WHERE oy.pcf_violation_category NOT IN (
                    SELECT pcf_violation_category FROM yearly_top2 yt2 WHERE yt2.year = yt.year
                )
            ) THEN 0
            ELSE 1
        END AS is_different
    FROM yearly_top2 yt
    GROUP BY yt.year
)
SELECT year
FROM year_comparison
WHERE is_different = 1
ORDER BY year