WITH customer_metrics AS (
    SELECT 
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price + oi.freight_value) AS total_spend,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        (SELECT MAX(order_purchase_timestamp) FROM orders WHERE order_status = 'delivered') AS max_date
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
rfm_scores AS (
    SELECT 
        customer_id,
        total_orders,
        total_spend,
        total_spend / total_orders AS avg_sales_per_order,
        -- Recency: days since last purchase
        CAST(julianday(max_date) - julianday(last_purchase_date) AS INTEGER) AS recency_days,
        -- Frequency: total orders
        total_orders AS frequency,
        -- Monetary: total spend
        total_spend AS monetary
    FROM customer_metrics
),
rfm_segments AS (
    SELECT 
        customer_id,
        avg_sales_per_order,
        recency_days,
        frequency,
        monetary,
        CASE 
            WHEN recency_days <= 30 AND frequency >= 5 AND monetary >= 500 THEN 'Champions'
            WHEN recency_days <= 30 AND frequency >= 3 AND monetary >= 300 THEN 'Loyal Customers'
            WHEN recency_days <= 30 AND frequency >= 1 AND monetary >= 100 THEN 'Potential Loyalists'
            WHEN recency_days <= 90 AND frequency >= 3 AND monetary >= 200 THEN 'Promising'
            WHEN recency_days <= 90 AND frequency >= 1 AND monetary >= 100 THEN 'New Customers'
            WHEN recency_days <= 180 AND frequency >= 2 AND monetary >= 150 THEN 'Need Attention'
            WHEN recency_days <= 180 AND frequency >= 1 AND monetary >= 50 THEN 'About to Sleep'
            WHEN recency_days <= 365 AND frequency >= 1 AND monetary >= 50 THEN 'At Risk'
            WHEN recency_days <= 365 AND frequency >= 1 THEN 'Cannot Lose Them'
            WHEN recency_days > 365 AND frequency >= 1 THEN 'Hibernating'
            ELSE 'Lost'
        END AS rfm_segment
    FROM rfm_scores
)
SELECT 
    rfm_segment,
    ROUND(AVG(avg_sales_per_order), 4) AS avg_sales_per_order
FROM rfm_segments
GROUP BY rfm_segment
ORDER BY avg_sales_per_order DESC