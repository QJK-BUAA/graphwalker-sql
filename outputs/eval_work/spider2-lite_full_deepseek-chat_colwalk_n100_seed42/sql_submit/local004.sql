WITH customer_metrics AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS num_orders,
        AVG(op.payment_value) AS avg_payment_per_order,
        (JULIANDAY(MAX(o.order_purchase_timestamp)) - JULIANDAY(MIN(o.order_purchase_timestamp))) AS lifespan_days
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id
),
ranked_customers AS (
    SELECT 
        customer_unique_id,
        num_orders,
        avg_payment_per_order,
        CASE 
            WHEN lifespan_days / 7.0 < 1.0 THEN 1.0
            ELSE lifespan_days / 7.0
        END AS customer_lifespan_weeks
    FROM customer_metrics
    ORDER BY avg_payment_per_order DESC
    LIMIT 3
)
SELECT 
    num_orders,
    avg_payment_per_order,
    customer_lifespan_weeks
FROM ranked_customers