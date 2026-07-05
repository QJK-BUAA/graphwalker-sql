-- Step 1: Compute customer-level RFM metrics from delivered orders
WITH customer_metrics AS (
    SELECT 
        o.customer_id,
        -- Recency: days since last purchase (using latest order_purchase_timestamp)
        JULIANDAY('2024-01-01') - JULIANDAY(MAX(o.order_purchase_timestamp)) AS recency_days,
        -- Frequency: total number of orders
        COUNT(DISTINCT o.order_id) AS frequency,
        -- Monetary: total spend (sum of payment_value)
        SUM(p.payment_value) AS monetary
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
-- Step 2: Assign RFM scores (1-4) using quintile-like thresholds
rfm_scores AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        -- Recency score: lower days = higher score
        CASE 
            WHEN recency_days <= 30 THEN 4
            WHEN recency_days <= 90 THEN 3
            WHEN recency_days <= 180 THEN 2
            ELSE 1
        END AS r_score,
        -- Frequency score: more orders = higher score
        CASE 
            WHEN frequency >= 10 THEN 4
            WHEN frequency >= 5 THEN 3
            WHEN frequency >= 2 THEN 2
            ELSE 1
        END AS f_score,
        -- Monetary score: higher spend = higher score
        CASE 
            WHEN monetary >= 1000 THEN 4
            WHEN monetary >= 500 THEN 3
            WHEN monetary >= 100 THEN 2
            ELSE 1
        END AS m_score
    FROM customer_metrics
),
-- Step 3: Combine scores into RFM segment
rfm_segments AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        -- Concatenate scores to form segment (e.g., '4-4-4')
        CAST(r_score AS TEXT) || '-' || CAST(f_score AS TEXT) || '-' || CAST(m_score AS TEXT) AS rfm_segment
    FROM rfm_scores
)
-- Step 4: Calculate average sales per order for each segment
SELECT 
    rfm_segment,
    -- Average sales per order = total monetary / total orders across customers in segment
    CAST(SUM(monetary) AS REAL) / SUM(frequency) AS avg_sales_per_order
FROM rfm_segments
GROUP BY rfm_segment
ORDER BY avg_sales_per_order DESC