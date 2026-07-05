WITH RECURSIVE
-- Step 1: Get each customer's date range
customer_date_range AS (
    SELECT 
        customer_id,
        MIN(txn_date) AS min_date,
        MAX(txn_date) AS max_date
    FROM customer_transactions
    GROUP BY customer_id
),
-- Step 2: Generate all dates for each customer between min and max
customer_dates AS (
    SELECT 
        customer_id,
        min_date AS date
    FROM customer_date_range
    UNION ALL
    SELECT 
        cd.customer_id,
        DATE(cd.date, '+1 day')
    FROM customer_dates cd
    JOIN customer_date_range cdr ON cd.customer_id = cdr.customer_id
    WHERE cd.date < cdr.max_date
),
-- Step 3: Get daily net transaction amounts (positive or negative)
daily_net AS (
    SELECT 
        customer_id,
        txn_date,
        SUM(txn_amount) AS net_amount
    FROM customer_transactions
    GROUP BY customer_id, txn_date
),
-- Step 4: Combine dates with transactions, compute running balance
daily_balance AS (
    SELECT 
        cd.customer_id,
        cd.date,
        COALESCE(dn.net_amount, 0) AS net_amount,
        SUM(COALESCE(dn.net_amount, 0)) OVER (
            PARTITION BY cd.customer_id 
            ORDER BY cd.date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS raw_balance
    FROM customer_dates cd
    LEFT JOIN daily_net dn ON cd.customer_id = dn.customer_id AND cd.date = dn.txn_date
),
-- Step 5: Apply zero floor to negative balances
daily_balance_zeroed AS (
    SELECT 
        customer_id,
        date,
        CASE WHEN raw_balance < 0 THEN 0 ELSE raw_balance END AS balance
    FROM daily_balance
),
-- Step 6: For each customer and month, get max daily balance
monthly_max_per_customer AS (
    SELECT 
        customer_id,
        strftime('%Y-%m', date) AS month,
        MAX(balance) AS max_balance
    FROM daily_balance_zeroed
    GROUP BY customer_id, strftime('%Y-%m', date)
)
-- Step 7: Sum across customers per month
SELECT 
    month,
    SUM(max_balance) AS monthly_total
FROM monthly_max_per_customer
GROUP BY month
ORDER BY month