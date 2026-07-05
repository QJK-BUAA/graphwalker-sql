-- Step 1: Find the store with the highest total number of orders
-- Step 2: For that store, compute ratio of orders with a matching delivery having 'DELIVERED' status to total orders
WITH store_order_counts AS (
    SELECT 
        s.store_id,
        s.store_name,
        COUNT(o.order_id) AS total_orders
    FROM stores s
    JOIN orders o ON s.store_id = o.store_id
    GROUP BY s.store_id, s.store_name
),
top_store AS (
    SELECT store_id, store_name, total_orders
    FROM store_order_counts
    ORDER BY total_orders DESC
    LIMIT 1
),
delivered_orders AS (
    SELECT 
        o.store_id,
        COUNT(DISTINCT o.order_id) AS delivered_count
    FROM orders o
    JOIN deliveries d ON o.delivery_order_id = d.delivery_order_id
    WHERE d.delivery_status = 'DELIVERED'
    GROUP BY o.store_id
)
SELECT 
    t.store_name,
    CAST(COALESCE(d.delivered_count, 0) AS REAL) / t.total_orders AS ratio_delivered_to_total
FROM top_store t
LEFT JOIN delivered_orders d ON t.store_id = d.store_id