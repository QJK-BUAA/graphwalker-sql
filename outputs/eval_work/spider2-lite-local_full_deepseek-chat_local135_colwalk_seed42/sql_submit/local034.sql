-- Step 1: Count payments per product category and payment type
WITH payment_counts AS (
    SELECT 
        pct.product_category_name_english AS category,
        opp.payment_type,
        COUNT(*) AS payment_count
    FROM olist_order_items oi
    JOIN olist_orders o ON oi.order_id = o.order_id
    JOIN olist_products p ON oi.product_id = p.product_id
    JOIN product_category_name_translation pct ON p.product_category_name = pct.product_category_name
    JOIN olist_order_payments opp ON o.order_id = opp.order_id
    GROUP BY pct.product_category_name_english, opp.payment_type
),
-- Step 2: For each category, find the most preferred payment method (highest count)
ranked_payments AS (
    SELECT 
        category,
        payment_type,
        payment_count,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY payment_count DESC) AS rn
    FROM payment_counts
),
-- Step 3: Filter to only the most preferred payment method per category
most_preferred AS (
    SELECT 
        category,
        payment_type,
        payment_count
    FROM ranked_payments
    WHERE rn = 1
)
-- Step 4: Calculate the average of those payment counts across all categories
SELECT 
    AVG(CAST(payment_count AS REAL)) AS avg_payments_most_preferred_method
FROM most_preferred