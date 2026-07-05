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
top_customers AS (
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
monthly_with_prev AS (
    SELECT 
        cm.customer_id,
        cm.first_name,
        cm.last_name,
        cm.month,
        cm.total_amount,
        LAG(cm.total_amount) OVER (PARTITION BY cm.customer_id ORDER BY cm.month) AS prev_month_amount
    FROM customer_monthly cm
    WHERE cm.customer_id IN (SELECT customer_id FROM top_customers)
),
differences AS (
    SELECT 
        customer_id,
        first_name,
        last_name,
        month,
        ROUND(ABS(total_amount - prev_month_amount), 2) AS month_diff
    FROM monthly_with_prev
    WHERE prev_month_amount IS NOT NULL
)
SELECT 
    customer_id,
    first_name,
    last_name,
    month,
    month_diff
FROM differences
ORDER BY month_diff DESC
LIMIT 1