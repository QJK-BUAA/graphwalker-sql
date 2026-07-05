-- Step 1: Compute daily running balance per customer
WITH daily_balance AS (
  SELECT 
    customer_id,
    txn_date,
    SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END) AS daily_net
  FROM customer_transactions
  GROUP BY customer_id, txn_date
),
running_balance AS (
  SELECT 
    customer_id,
    txn_date,
    SUM(daily_net) OVER (PARTITION BY customer_id ORDER BY txn_date ROWS UNBOUNDED PRECEDING) AS balance
  FROM daily_balance
),
-- Step 2: For each customer and day, compute 30-day rolling average balance
rolling_avg AS (
  SELECT 
    customer_id,
    txn_date,
    AVG(balance) OVER (
      PARTITION BY customer_id 
      ORDER BY txn_date 
      ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS avg_30day
  FROM running_balance
),
-- Step 3: Only keep rows after having 30 days of data, treat negative averages as zero
valid_avg AS (
  SELECT 
    customer_id,
    txn_date,
    CASE 
      WHEN ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY txn_date) >= 30 
      THEN MAX(0.0, avg_30day)
      ELSE NULL 
    END AS avg_30day_clean
  FROM rolling_avg
),
-- Step 4: Extract year-month and find each customer's max avg per month
monthly_max AS (
  SELECT 
    customer_id,
    strftime('%Y-%m', txn_date) AS month,
    MAX(avg_30day_clean) AS max_avg
  FROM valid_avg
  WHERE avg_30day_clean IS NOT NULL
  GROUP BY customer_id, month
),
-- Step 5: Identify each customer's first month (baseline)
first_month AS (
  SELECT 
    customer_id,
    MIN(strftime('%Y-%m', txn_date)) AS first_month
  FROM customer_transactions
  GROUP BY customer_id
),
-- Step 6: Exclude baseline months, sum max values across customers per month
final AS (
  SELECT 
    m.month,
    SUM(m.max_avg) AS total_max_avg
  FROM monthly_max m
  LEFT JOIN first_month f ON m.customer_id = f.customer_id
  WHERE m.month != f.first_month
  GROUP BY m.month
)
SELECT * FROM final
ORDER BY month