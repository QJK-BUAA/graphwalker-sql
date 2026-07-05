-- Step 1: Identify the two most common causes (PCF violation categories) per year
-- Step 2: Compare across years to find the year where the top 2 differ from all others
WITH yearly_top2 AS (
  SELECT 
    strftime('%Y', collision_date) AS year,
    pcf_violation_category,
    COUNT(*) AS cnt,
    ROW_NUMBER() OVER (PARTITION BY strftime('%Y', collision_date) ORDER BY COUNT(*) DESC) AS rn
  FROM collisions
  WHERE pcf_violation_category IS NOT NULL
  GROUP BY year, pcf_violation_category
),
yearly_top2_list AS (
  SELECT year, GROUP_CONCAT(pcf_violation_category ORDER BY rn) AS top2_causes
  FROM yearly_top2
  WHERE rn <= 2
  GROUP BY year
),
common_top2 AS (
  SELECT top2_causes, COUNT(*) AS year_count
  FROM yearly_top2_list
  GROUP BY top2_causes
  HAVING COUNT(*) > 1
)
SELECT ytl.year
FROM yearly_top2_list ytl
WHERE ytl.top2_causes NOT IN (SELECT top2_causes FROM common_top2)