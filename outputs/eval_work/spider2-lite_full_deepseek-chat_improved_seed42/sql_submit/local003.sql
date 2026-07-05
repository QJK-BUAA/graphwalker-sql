-- Step 1: Compute customer-level metrics: total spend, order count, recency (days since last purchase)
WITH customer_metrics AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(oi.price + oi.freight_value) AS total_spend,
        -- Recency: days between the latest purchase timestamp and the overall latest purchase timestamp in the dataset
        JULIANDAY(MAX(o.order_purchase_timestamp)) - JULIANDAY(MAX(o.order_purchase_timestamp)) AS recency_days
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
-- Step 2: Compute overall max purchase timestamp for recency calculation
global_max AS (
    SELECT MAX(order_purchase_timestamp) AS max_ts FROM orders WHERE order_status = 'delivered'
),
-- Step 3: Compute recency as days from last purchase to global max
customer_recency AS (
    SELECT
        cm.customer_id,
        cm.order_count,
        cm.total_spend,
        JULIANDAY(gm.max_ts) - JULIANDAY(MAX(o.order_purchase_timestamp)) AS recency_days
    FROM customer_metrics cm
    JOIN orders o ON o.customer_id = cm.customer_id AND o.order_status = 'delivered'
    CROSS JOIN global_max gm
    GROUP BY cm.customer_id, cm.order_count, cm.total_spend, gm.max_ts
),
-- Step 4: Compute RFM scores (using quintiles or simple thresholds based on distribution)
rfm_scores AS (
    SELECT
        customer_id,
        order_count,
        total_spend,
        recency_days,
        -- Recency score: lower recency is better (1-5)
        CASE
            WHEN recency_days <= 30 THEN 5
            WHEN recency_days <= 60 THEN 4
            WHEN recency_days <= 90 THEN 3
            WHEN recency_days <= 180 THEN 2
            ELSE 1
        END AS recency_score,
        -- Frequency score: higher order count is better (1-5)
        CASE
            WHEN order_count >= 10 THEN 5
            WHEN order_count >= 5 THEN 4
            WHEN order_count >= 3 THEN 3
            WHEN order_count >= 2 THEN 2
            ELSE 1
        END AS frequency_score,
        -- Monetary score: higher total spend is better (1-5)
        CASE
            WHEN total_spend >= 1000 THEN 5
            WHEN total_spend >= 500 THEN 4
            WHEN total_spend >= 200 THEN 3
            WHEN total_spend >= 100 THEN 2
            ELSE 1
        END AS monetary_score
    FROM customer_recency
),
-- Step 5: Combine scores into RFM segments
rfm_segments AS (
    SELECT
        customer_id,
        order_count,
        total_spend,
        recency_days,
        recency_score,
        frequency_score,
        monetary_score,
        -- Concatenate scores to form segment label
        CAST(recency_score AS TEXT) || CAST(frequency_score AS TEXT) || CAST(monetary_score AS TEXT) AS rfm_segment,
        -- Also create high-level segments
        CASE
            WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
            WHEN recency_score >= 4 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
            WHEN recency_score >= 4 AND frequency_score >= 1 AND monetary_score >= 1 THEN 'Recent Customers'
            WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Potential Loyalists'
            WHEN recency_score >= 3 AND frequency_score >= 1 AND monetary_score >= 1 THEN 'Promising'
            WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'At Risk'
            WHEN recency_score <= 2 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Need Attention'
            WHEN recency_score <= 2 AND frequency_score >= 1 AND monetary_score >= 1 THEN 'About to Sleep'
            WHEN recency_score <= 1 AND frequency_score >= 1 AND monetary_score >= 1 THEN 'Lost'
            ELSE 'Other'
        END AS rfm_segment_name
    FROM rfm_scores
)
-- Step 6: Calculate average sales per order per segment
SELECT
    rfm_segment_name AS rfm_segment,
    COUNT(DISTINCT customer_id) AS customer_count,
    ROUND(SUM(total_spend) / CAST(SUM(order_count) AS REAL), 4) AS avg_sales_per_order
FROM rfm_segments
GROUP BY rfm_segment_name
ORDER BY avg_sales_per_order DESC