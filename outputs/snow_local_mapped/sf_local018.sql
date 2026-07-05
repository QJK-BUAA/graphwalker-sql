-- Step 1: Find the most common pcf_violation_category in 2021
WITH category_counts AS (
    SELECT 
        pcf_violation_category,
        COUNT(*) AS cnt_2021
    FROM collisions
    WHERE strftime('%Y', collision_date) = '2021'
        AND pcf_violation_category IS NOT NULL
    GROUP BY pcf_violation_category
    ORDER BY cnt_2021 DESC
    LIMIT 1
),
-- Step 2: Get total collisions in 2021 and 2011
totals AS (
    SELECT 
        (SELECT COUNT(*) FROM collisions WHERE strftime('%Y', collision_date) = '2021') AS total_2021,
        (SELECT COUNT(*) FROM collisions WHERE strftime('%Y', collision_date) = '2011') AS total_2011
),
-- Step 3: Get count for the top category in 2011
top_category AS (
    SELECT pcf_violation_category FROM category_counts
),
category_2011 AS (
    SELECT 
        COUNT(*) AS cnt_2011
    FROM collisions
    WHERE strftime('%Y', collision_date) = '2011'
        AND pcf_violation_category = (SELECT pcf_violation_category FROM top_category)
)
-- Step 4: Compute percentage point decrease
SELECT 
    ROUND(
        (CAST((SELECT cnt_2021 FROM category_counts) AS REAL) / (SELECT total_2021 FROM totals) * 100) -
        (CAST((SELECT cnt_2011 FROM category_2011) AS REAL) / (SELECT total_2011 FROM totals) * 100),
        4
    ) AS percentage_point_decrease
FROM totals