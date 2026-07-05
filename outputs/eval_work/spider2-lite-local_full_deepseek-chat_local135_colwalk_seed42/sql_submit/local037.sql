-- Step 1: For each product category and payment type, count the number of payments (orders)
-- Step 2: For each product category, find the payment type with the highest count (most commonly used)
-- Step 3: Rank categories by that highest count, take top 3
-- Step 4: Output category, payment type, and count

WITH category_payment_counts AS (
    SELECT 
        p.product_category_name,
        pp.payment_type,
        COUNT(DISTINCT o.order_id) AS payment_count
    FROM olist_orders o
    JOIN olist_order_items oi ON o.order_id = oi.order_id
    JOIN olist_products p ON oi.product_id = p.product_id
    JOIN olist_order_payments pp ON o.order_id = pp.order_id
    GROUP BY p.product_category_name, pp.payment_type
),
ranked_categories AS (
    SELECT 
        product_category_name,
        payment_type,
        payment_count,
        ROW_NUMBER() OVER (PARTITION BY product_category_name ORDER BY payment_count DESC) AS rn
    FROM category_payment_counts
),
top_payment_per_category AS (
    SELECT 
        product_category_name,
        payment_type,
        payment_count
    FROM ranked_categories
    WHERE rn = 1
)
SELECT 
    product_category_name,
    payment_type,
    payment_count
FROM top_payment_per_category
ORDER BY payment_count DESC
LIMIT 3