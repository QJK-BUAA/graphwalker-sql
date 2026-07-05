WITH monthly_nets AS (
    -- Step 1: Group deposits and withdrawals by customer and first day of month
    SELECT 
        customer_id,
        DATE(txn_date, 'start of month') AS month_start,
        SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END) AS monthly_net
    FROM customer_transactions
    GROUP BY customer_id, DATE(txn_date, 'start of month')
),
closing_balances AS (
    -- Step 2: Calculate cumulative sum of monthly nets for each customer
    SELECT 
        customer_id,
        month_start,
        SUM(monthly_net) OVER (PARTITION BY customer_id ORDER BY month_start ROWS UNBOUNDED PRECEDING) AS closing_balance
    FROM monthly_nets
),
ranked_months AS (
    -- Step 3: Rank months per customer to identify most recent and prior month
    SELECT 
        customer_id,
        month_start,
        closing_balance,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY month_start DESC) AS rn
    FROM closing_balances
),
growth_rates AS (
    -- Step 4: Calculate growth rate for most recent month
    SELECT 
        curr.customer_id,
        curr.closing_balance AS current_balance,
        prev.closing_balance AS previous_balance,
        CASE 
            WHEN prev.closing_balance = 0 THEN curr.closing_balance * 100.0
            ELSE (curr.closing_balance - prev.closing_balance) * 100.0 / CAST(prev.closing_balance AS REAL)
        END AS growth_rate
    FROM ranked_months curr
    LEFT JOIN ranked_months prev 
        ON curr.customer_id = prev.customer_id 
        AND prev.rn = 2
    WHERE curr.rn = 1
)
-- Step 5: Compute percentage of customers with growth rate > 5%
SELECT 
    CAST(SUM(CASE WHEN growth_rate > 5 THEN 1 ELSE 0 END) AS REAL) * 100.0 / COUNT(*) AS percentage
FROM growth_rates