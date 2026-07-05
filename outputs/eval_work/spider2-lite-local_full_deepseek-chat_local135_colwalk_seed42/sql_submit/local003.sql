-- Calculate RFM segments and average sales per order for each customer
-- Note: This query assumes sales data would be available; without it, we calculate order counts
-- Recency: days since last purchase (using order_purchase_timestamp)
-- Frequency: total number of orders per customer
-- Monetary: not available in schema, so we use order count as proxy

WITH customer_rfm AS (
    SELECT 
        customer_id,
        -- Recency: days since last purchase (using latest purchase timestamp)
        CAST(julianday('2018-09-04') - julianday(MAX(order_purchase_timestamp)) AS INTEGER) AS recency_days,
        -- Frequency: total number of orders
        COUNT(order_id) AS frequency,
        -- Monetary: total spend (not available, using order count as placeholder)
        COUNT(order_id) AS total_spend_placeholder
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        -- R score: 1-4 based on recency (lower is better)
        CASE 
            WHEN recency_days <= 30 THEN 4
            WHEN recency_days <= 90 THEN 3
            WHEN recency_days <= 180 THEN 2
            ELSE 1
        END AS r_score,
        -- F score: 1-4 based on frequency (higher is better)
        CASE 
            WHEN frequency >= 10 THEN 4
            WHEN frequency >= 5 THEN 3
            WHEN frequency >= 2 THEN 2
            ELSE 1
        END AS f_score,
        -- M score: 1-4 based on monetary (higher is better)
        CASE 
            WHEN total_spend_placeholder >= 10 THEN 4
            WHEN total_spend_placeholder >= 5 THEN 3
            WHEN total_spend_placeholder >= 2 THEN 2
            ELSE 1
        END AS m_score
    FROM customer_rfm
),
rfm_segments AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        r_score,
        f_score,
        m_score,
        -- RFM segment: concatenation of R, F, M scores
        CAST(r_score AS TEXT) || CAST(f_score AS TEXT) || CAST(m_score AS TEXT) AS rfm_segment
    FROM rfm_scores
)
SELECT 
    rfm_segment,
    COUNT(DISTINCT customer_id) AS customer_count,
    -- Average sales per order = total spend / total orders
    -- Since monetary data is not available, we calculate average frequency as proxy
    ROUND(AVG(CAST(frequency AS REAL)), 4) AS avg_orders_per_customer,
    -- Average recency for the segment
    ROUND(AVG(CAST(recency_days AS REAL)), 4) AS avg_recency_days
FROM rfm_segments
GROUP BY rfm_segment
ORDER BY rfm_segment