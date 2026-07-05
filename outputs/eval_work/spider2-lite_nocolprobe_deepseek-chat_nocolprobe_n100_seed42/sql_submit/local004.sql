WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS num_orders,
        AVG(p.payment_value) AS avg_payment_per_order,
        MIN(o.order_purchase_timestamp) AS first_purchase,
        MAX(o.order_purchase_timestamp) AS last_purchase
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    GROUP BY c.customer_id, c.customer_unique_id
),
customer_lifespan AS (
    SELECT 
        customer_id,
        customer_unique_id,
        num_orders,
        avg_payment_per_order,
        CASE 
            WHEN (julianday(last_purchase) - julianday(first_purchase)) / 7.0 < 1.0 THEN 1.0
            ELSE (julianday(last_purchase) - julianday(first_purchase)) / 7.0
        END AS lifespan_weeks
    FROM customer_metrics
)
SELECT 
    num_orders,
    avg_payment_per_order,
    lifespan_weeks
FROM customer_lifespan
ORDER BY avg_payment_per_order DESC
LIMIT 3