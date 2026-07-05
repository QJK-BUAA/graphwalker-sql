-- Generate monthly closing balances, changes, and cumulative balances for each customer
-- Include months with no activity by generating all months for each customer

WITH RECURSIVE
-- Get date range for each customer
customer_dates AS (
    SELECT 
        customer_id,
        MIN(txn_date) AS min_date,
        MAX(txn_date) AS max_date
    FROM customer_transactions
    GROUP BY customer_id
),
-- Generate all months between min and max date for each customer
customer_months AS (
    SELECT 
        customer_id,
        strftime('%Y-%m-01', min_date) AS month_start,
        strftime('%Y-%m-01', max_date) AS max_month
    FROM customer_dates
    UNION ALL
    SELECT 
        customer_id,
        date(month_start, '+1 month') AS month_start,
        max_month
    FROM customer_months
    WHERE date(month_start, '+1 month') <= max_month
),
-- Calculate net activity per month per customer
monthly_activity AS (
    SELECT 
        cm.customer_id,
        cm.month_start,
        COALESCE(SUM(
            CASE 
                WHEN ct.txn_type = 'deposit' THEN ct.txn_amount
                WHEN ct.txn_type = 'withdrawal' THEN -ct.txn_amount
                ELSE 0
            END
        ), 0) AS net_change
    FROM customer_months cm
    LEFT JOIN customer_transactions ct 
        ON cm.customer_id = ct.customer_id 
        AND strftime('%Y-%m', ct.txn_date) = strftime('%Y-%m', cm.month_start)
    GROUP BY cm.customer_id, cm.month_start
),
-- Calculate cumulative balance and closing balance
monthly_balances AS (
    SELECT 
        customer_id,
        month_start,
        net_change,
        SUM(net_change) OVER (
            PARTITION BY customer_id 
            ORDER BY month_start 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_balance
    FROM monthly_activity
)
SELECT 
    customer_id,
    strftime('%Y-%m', month_start) AS month,
    cumulative_balance AS closing_balance,
    net_change AS monthly_change,
    cumulative_balance AS monthly_cumulative_balance
FROM monthly_balances
ORDER BY customer_id, month_start