WITH customer_monthly AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        strftime('%Y-%m', p.payment_date) AS month,
        SUM(p.amount) AS total_amount
    FROM customer c
    JOIN payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, month
),
top10_customers AS (
    SELECT 
        customer_id,
        first_name,
        last_name,
        SUM(total_amount) AS lifetime_total
    FROM customer_monthly
    GROUP BY customer_id
    ORDER BY lifetime_total DESC
    LIMIT 10
),
monthly_with_lag AS (
    SELECT 
        cm.customer_id,
        cm.first_name,
        cm.last_name,
        cm.month,
        cm.total_amount,
        LAG(cm.total_amount) OVER (PARTITION BY cm.customer_id ORDER BY cm.month) AS prev_total
    FROM customer_monthly cm
    JOIN top10_customers t ON cm.customer_id = t.customer_id
),
differences AS (
    SELECT 
        customer_id,
        first_name,
        last_name,
        month,
        ROUND(ABS(total_amount - COALESCE(prev_total, 0)), 2) AS diff
    FROM monthly_with_lag
    WHERE prev_total IS NOT NULL
)
SELECT 
    customer_id,
    first_name,
    last_name,
    month,
    diff
FROM differences
ORDER BY diff DESC
LIMIT 1