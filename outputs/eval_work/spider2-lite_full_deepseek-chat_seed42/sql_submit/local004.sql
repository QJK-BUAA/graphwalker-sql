WITH customer_metrics AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS num_orders,
        AVG(p.payment_value) AS avg_payment_per_order,
        (JULIANDAY(MAX(o.order_purchase_timestamp)) - JULIANDAY(MIN(o.order_purchase_timestamp))) / 7.0 AS raw_lifespan_weeks
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    GROUP BY c.customer_unique_id
),
ranked_customers AS (
    SELECT 
        num_orders,
        avg_payment_per_order,
        CASE 
            WHEN raw_lifespan_weeks < 1.0 THEN 1.0
            ELSE raw_lifespan_weeks
        END AS customer_lifespan_weeks
    FROM customer_metrics
    ORDER BY avg_payment_per_order DESC
    LIMIT 3
)
SELECT 
    num_orders,
    ROUND(avg_payment_per_order, 4) AS avg_payment_per_order,
    ROUND(customer_lifespan_weeks, 4) AS customer_lifespan_weeks
FROM ranked_customers