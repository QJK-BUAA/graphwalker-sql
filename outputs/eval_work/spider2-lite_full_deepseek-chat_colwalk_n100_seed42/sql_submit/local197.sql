WITH customer_monthly AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        strftime('%Y-%m', p.payment_date) AS month,
        SUM(p.amount) AS total_amount
    FROM customer c
    JOIN payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, strftime('%Y-%m', p.payment_date)
),
top10_customers AS (
    SELECT 
        customer_id,
        first_name,
        last_name
    FROM customer_monthly
    GROUP BY customer_id
    ORDER BY SUM(total_amount) DESC
    LIMIT 10
),
monthly_with_lag AS (
    SELECT 
        cm.customer_id,
        cm.first_name,
        cm.last_name,
        cm.month,
        cm.total_amount,
        LAG(cm.total_amount) OVER (PARTITION BY cm.customer_id ORDER BY cm.month) AS prev_month_amount
    FROM customer_monthly cm
    WHERE cm.customer_id IN (SELECT customer_id FROM top10_customers)
),
monthly_diff AS (
    SELECT 
        customer_id,
        first_name,
        last_name,
        month,
        ROUND(ABS(total_amount - COALESCE(prev_month_amount, 0)), 2) AS month_over_month_diff
    FROM monthly_with_lag
    WHERE prev_month_amount IS NOT NULL
)
SELECT 
    customer_id,
    first_name,
    last_name,
    month,
    month_over_month_diff
FROM monthly_diff
ORDER BY month_over_month_diff DESC
LIMIT 1