-- Step 1: Extract year and month from insert_date, filter for April (4), May (5), June (6) and years 2021-2023
-- Step 2: Count cities per year and month
-- Step 3: Compute running total per month across years using window function
-- Step 4: Compute year-over-year growth percentages for monthly count and running total
-- Step 5: Filter to show only 2022 and 2023

WITH monthly_counts AS (
  SELECT 
    CAST(strftime('%Y', insert_date) AS INTEGER) AS year,
    strftime('%m', insert_date) AS month_num,
    CASE strftime('%m', insert_date)
      WHEN '04' THEN 'April'
      WHEN '05' THEN 'May'
      WHEN '06' THEN 'June'
    END AS month,
    COUNT(*) AS monthly_total
  FROM cities
  WHERE strftime('%m', insert_date) IN ('04', '05', '06')
    AND CAST(strftime('%Y', insert_date) AS INTEGER) BETWEEN 2021 AND 2023
  GROUP BY year, month_num
),
running_totals AS (
  SELECT 
    year,
    month,
    monthly_total,
    SUM(monthly_total) OVER (PARTITION BY month ORDER BY year) AS running_total
  FROM monthly_counts
),
with_growth AS (
  SELECT 
    year,
    month,
    monthly_total,
    running_total,
    LAG(monthly_total) OVER (PARTITION BY month ORDER BY year) AS prev_monthly_total,
    LAG(running_total) OVER (PARTITION BY month ORDER BY year) AS prev_running_total
  FROM running_totals
)
SELECT 
  year,
  month,
  monthly_total,
  running_total,
  ROUND(CAST((monthly_total - prev_monthly_total) AS REAL) / prev_monthly_total * 100, 4) AS monthly_yoy_growth_pct,
  ROUND(CAST((running_total - prev_running_total) AS REAL) / prev_running_total * 100, 4) AS running_total_yoy_growth_pct
FROM with_growth
WHERE year IN (2022, 2023)
ORDER BY month, year