WITH 
-- Define the reference date
ref_date AS (
  SELECT '2020-06-15' AS ref_date
),
-- Get the week containing June 15, 2020
ref_week AS (
  SELECT week_date_formatted, week_number, month_number, calendar_year
  FROM cleaned_weekly_sales
  WHERE week_date_formatted = (SELECT ref_date FROM ref_date)
  LIMIT 1
),
-- Get 12 weeks before (weeks -12 to -1 relative to ref week)
before_weeks AS (
  SELECT week_date_formatted, week_number, month_number, calendar_year
  FROM cleaned_weekly_sales
  WHERE calendar_year = (SELECT calendar_year FROM ref_week)
    AND week_number < (SELECT week_number FROM ref_week)
    AND week_number >= (SELECT week_number FROM ref_week) - 12
  UNION
  SELECT week_date_formatted, week_number, month_number, calendar_year
  FROM cleaned_weekly_sales
  WHERE calendar_year = (SELECT calendar_year FROM ref_week) - 1
    AND week_number >= 52 - (12 - (SELECT week_number FROM ref_week))
    AND (SELECT week_number FROM ref_week) < 12
),
-- Get 12 weeks after (weeks +1 to +12 relative to ref week)
after_weeks AS (
  SELECT week_date_formatted, week_number, month_number, calendar_year
  FROM cleaned_weekly_sales
  WHERE calendar_year = (SELECT calendar_year FROM ref_week)
    AND week_number > (SELECT week_number FROM ref_week)
    AND week_number <= (SELECT week_number FROM ref_week) + 12
  UNION
  SELECT week_date_formatted, week_number, month_number, calendar_year
  FROM cleaned_weekly_sales
  WHERE calendar_year = (SELECT calendar_year FROM ref_week) + 1
    AND week_number <= 12 - (52 - (SELECT week_number FROM ref_week))
    AND (SELECT week_number FROM ref_week) > 40
),
-- Aggregate sales before for each attribute value
before_sales AS (
  SELECT 
    'region' AS attr_type, region AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM before_weeks)
  GROUP BY region
  UNION ALL
  SELECT 
    'platform' AS attr_type, platform AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM before_weeks)
  GROUP BY platform
  UNION ALL
  SELECT 
    'age_band' AS attr_type, age_band AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM before_weeks)
  GROUP BY age_band
  UNION ALL
  SELECT 
    'demographic' AS attr_type, demographic AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM before_weeks)
  GROUP BY demographic
  UNION ALL
  SELECT 
    'customer_type' AS attr_type, customer_type AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM before_weeks)
  GROUP BY customer_type
),
-- Aggregate sales after for each attribute value
after_sales AS (
  SELECT 
    'region' AS attr_type, region AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM after_weeks)
  GROUP BY region
  UNION ALL
  SELECT 
    'platform' AS attr_type, platform AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM after_weeks)
  GROUP BY platform
  UNION ALL
  SELECT 
    'age_band' AS attr_type, age_band AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM after_weeks)
  GROUP BY age_band
  UNION ALL
  SELECT 
    'demographic' AS attr_type, demographic AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM after_weeks)
  GROUP BY demographic
  UNION ALL
  SELECT 
    'customer_type' AS attr_type, customer_type AS attr_value, SUM(CAST(sales AS REAL)) AS total_sales
  FROM cleaned_weekly_sales
  WHERE (week_date_formatted, week_number, month_number, calendar_year) IN (SELECT * FROM after_weeks)
  GROUP BY customer_type
),
-- Calculate percentage change for each attribute value
pct_change AS (
  SELECT 
    b.attr_type,
    b.attr_value,
    CASE 
      WHEN b.total_sales = 0 THEN NULL
      ELSE ((a.total_sales - b.total_sales) / b.total_sales) * 100.0
    END AS pct_change
  FROM before_sales b
  JOIN after_sales a ON b.attr_type = a.attr_type AND b.attr_value = a.attr_value
),
-- Average percentage change per attribute type
avg_pct_change AS (
  SELECT 
    attr_type,
    AVG(pct_change) AS avg_pct_change
  FROM pct_change
  GROUP BY attr_type
)
-- Identify the attribute type with highest negative impact (lowest avg_pct_change)
SELECT 
  attr_type,
  ROUND(avg_pct_change, 4) AS avg_pct_change
FROM avg_pct_change
ORDER BY avg_pct_change ASC
LIMIT 1