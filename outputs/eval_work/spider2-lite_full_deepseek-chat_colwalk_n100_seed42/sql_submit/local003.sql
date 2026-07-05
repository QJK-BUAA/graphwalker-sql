-- Calculate RFM metrics for each customer based on delivered orders
WITH customer_rfm AS (
    SELECT 
        o.customer_id,
        -- Recency: days since last purchase (using latest order_purchase_timestamp)
        CAST(julianday('2018-09-04') - julianday(MAX(o.order_purchase_timestamp)) AS INTEGER) AS recency,
        -- Frequency: total number of orders
        COUNT(DISTINCT o.order_id) AS frequency,
        -- Monetary: total spend (sum of payment_value)
        SUM(op.payment_value) AS monetary
    FROM orders o
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
-- Assign RFM scores (1-4) based on quintiles or logical breaks
rfm_scores AS (
    SELECT 
        customer_id,
        recency,
        frequency,
        monetary,
        -- Recency score: lower recency is better (more recent)
        CASE 
            WHEN recency <= 30 THEN 4
            WHEN recency <= 90 THEN 3
            WHEN recency <= 180 THEN 2
            ELSE 1
        END AS r_score,
        -- Frequency score: higher frequency is better
        CASE 
            WHEN frequency >= 10 THEN 4
            WHEN frequency >= 5 THEN 3
            WHEN frequency >= 2 THEN 2
            ELSE 1
        END AS f_score,
        -- Monetary score: higher monetary is better
        CASE 
            WHEN monetary >= 1000 THEN 4
            WHEN monetary >= 500 THEN 3
            WHEN monetary >= 200 THEN 2
            ELSE 1
        END AS m_score
    FROM customer_rfm
),
-- Combine scores into RFM segments
rfm_segments AS (
    SELECT 
        customer_id,
        recency,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        -- Concatenate scores to form segment (e.g., '4-4-4')
        CAST(r_score AS TEXT) || '-' || CAST(f_score AS TEXT) || '-' || CAST(m_score AS TEXT) AS rfm_segment
    FROM rfm_scores
)
-- Calculate average sales per order for each RFM segment
SELECT 
    rfm_segment,
    COUNT(DISTINCT customer_id) AS customer_count,
    ROUND(SUM(monetary) / CAST(SUM(frequency) AS REAL), 4) AS avg_sales_per_order
FROM rfm_segments
GROUP BY rfm_segment
ORDER BY rfm_segment