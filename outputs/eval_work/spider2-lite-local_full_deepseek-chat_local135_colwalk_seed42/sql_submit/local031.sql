-- Step 1: Compute annual delivered orders volume for each year (2016, 2017, 2018)
-- Step 2: Identify the year with the lowest annual volume
-- Step 3: For that year, compute monthly delivered orders volume
-- Step 4: Return the maximum monthly volume

WITH annual_volumes AS (
  SELECT 
    CAST(strftime('%Y', olist_orders.order_delivered_customer_date) AS INTEGER) AS year,
    COUNT(DISTINCT olist_orders.order_id) AS annual_volume
  FROM olist_orders
  WHERE olist_orders.order_delivered_customer_date IS NOT NULL
    AND CAST(strftime('%Y', olist_orders.order_delivered_customer_date) AS INTEGER) IN (2016, 2017, 2018)
  GROUP BY year
),
lowest_year AS (
  SELECT year
  FROM annual_volumes
  ORDER BY annual_volume ASC
  LIMIT 1
),
monthly_volumes AS (
  SELECT 
    CAST(strftime('%m', olist_orders.order_delivered_customer_date) AS INTEGER) AS month,
    COUNT(DISTINCT olist_orders.order_id) AS monthly_volume
  FROM olist_orders
  WHERE olist_orders.order_delivered_customer_date IS NOT NULL
    AND CAST(strftime('%Y', olist_orders.order_delivered_customer_date) AS INTEGER) = (SELECT year FROM lowest_year)
  GROUP BY month
)
SELECT MAX(monthly_volume) AS highest_monthly_delivered_orders
FROM monthly_volumes