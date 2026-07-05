-- Step 1: Compute customer-level RFM metrics and total spend/orders for delivered orders
WITH customer_metrics AS (
    SELECT 
        c.customer_unique_id,
        -- Recency: days since last purchase (using latest order_purchase_timestamp)
        JULIANDAY('2018-10-17') - JULIANDAY(MAX(o.order_purchase_timestamp)) AS recency_days,
        -- Frequency: total number of delivered orders
        COUNT(DISTINCT o.order_id) AS frequency,
        -- Monetary: total spend (sum of payment_value for delivered orders)
        SUM(op.payment_value) AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
-- Step 2: Assign RFM segments based on quintile-like thresholds (common e-commerce approach)
rfm_segments AS (
    SELECT 
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        -- Recency score: 1 (most recent) to 4 (least recent)
        CASE 
            WHEN recency_days <= 30 THEN 4
            WHEN recency_days <= 90 THEN 3
            WHEN recency_days <= 180 THEN 2
            ELSE 1
        END AS r_score,
        -- Frequency score: 1 (low) to 4 (high)
        CASE 
            WHEN frequency >= 10 THEN 4
            WHEN frequency >= 5 THEN 3
            WHEN frequency >= 2 THEN 2
            ELSE 1
        END AS f_score,
        -- Monetary score: 1 (low) to 4 (high)
        CASE 
            WHEN monetary >= 1000 THEN 4
            WHEN monetary >= 500 THEN 3
            WHEN monetary >= 200 THEN 2
            ELSE 1
        END AS m_score
    FROM customer_metrics
),
-- Step 3: Create RFM segments (concatenated scores)
rfm_combined AS (
    SELECT 
        customer_unique_id,
        CAST(r_score AS TEXT) || CAST(f_score AS TEXT) || CAST(m_score AS TEXT) AS rfm_segment,
        monetary,
        frequency
    FROM rfm_segments
)
-- Step 4: Calculate average sales per order per segment
SELECT 
    rfm_segment,
    SUM(monetary) / SUM(frequency) AS avg_sales_per_order
FROM rfm_combined
GROUP BY rfm_segment
ORDER BY avg_sales_per_order DESC