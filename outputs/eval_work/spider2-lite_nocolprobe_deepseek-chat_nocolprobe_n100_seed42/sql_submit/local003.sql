WITH customer_rfm AS (
    SELECT 
        o.customer_id,
        CAST(julianday('now') - julianday(MAX(o.order_purchase_timestamp)) AS INTEGER) AS recency,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(op.payment_value) AS monetary
    FROM orders o
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
rfm_scores AS (
    SELECT 
        customer_id,
        recency,
        frequency,
        monetary,
        CASE 
            WHEN recency <= (SELECT recency FROM customer_rfm ORDER BY recency LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.25 AS INTEGER) FROM customer_rfm)) THEN 4
            WHEN recency <= (SELECT recency FROM customer_rfm ORDER BY recency LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.50 AS INTEGER) FROM customer_rfm)) THEN 3
            WHEN recency <= (SELECT recency FROM customer_rfm ORDER BY recency LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.75 AS INTEGER) FROM customer_rfm)) THEN 2
            ELSE 1
        END AS r_score,
        CASE 
            WHEN frequency >= (SELECT frequency FROM customer_rfm ORDER BY frequency DESC LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.25 AS INTEGER) FROM customer_rfm)) THEN 4
            WHEN frequency >= (SELECT frequency FROM customer_rfm ORDER BY frequency DESC LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.50 AS INTEGER) FROM customer_rfm)) THEN 3
            WHEN frequency >= (SELECT frequency FROM customer_rfm ORDER BY frequency DESC LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.75 AS INTEGER) FROM customer_rfm)) THEN 2
            ELSE 1
        END AS f_score,
        CASE 
            WHEN monetary >= (SELECT monetary FROM customer_rfm ORDER BY monetary DESC LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.25 AS INTEGER) FROM customer_rfm)) THEN 4
            WHEN monetary >= (SELECT monetary FROM customer_rfm ORDER BY monetary DESC LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.50 AS INTEGER) FROM customer_rfm)) THEN 3
            WHEN monetary >= (SELECT monetary FROM customer_rfm ORDER BY monetary DESC LIMIT 1 OFFSET (SELECT CAST(COUNT(*) * 0.75 AS INTEGER) FROM customer_rfm)) THEN 2
            ELSE 1
        END AS m_score
    FROM customer_rfm
),
rfm_segments AS (
    SELECT 
        customer_id,
        recency,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        CASE 
            WHEN (r_score >= 3 AND f_score >= 3 AND m_score >= 3) THEN 'Champions'
            WHEN (r_score >= 3 AND f_score >= 1 AND m_score >= 1) THEN 'Loyal Customers'
            WHEN (r_score >= 3 AND f_score >= 1 AND m_score <= 2) THEN 'Potential Loyalists'
            WHEN (r_score >= 3 AND f_score <= 2 AND m_score >= 3) THEN 'Big Spenders'
            WHEN (r_score >= 3 AND f_score <= 2 AND m_score <= 2) THEN 'Recent Customers'
            WHEN (r_score <= 2 AND f_score >= 3 AND m_score >= 3) THEN 'At Risk Champions'
            WHEN (r_score <= 2 AND f_score >= 3 AND m_score <= 2) THEN 'At Risk'
            WHEN (r_score <= 2 AND f_score <= 2 AND m_score >= 3) THEN 'Hibernating Big Spenders'
            WHEN (r_score <= 2 AND f_score <= 2 AND m_score <= 2) THEN 'Lost'
            ELSE 'Other'
        END AS rfm_segment
    FROM rfm_scores
)
SELECT 
    rfm_segment,
    COUNT(DISTINCT customer_id) AS customer_count,
    ROUND(SUM(monetary) / CAST(SUM(frequency) AS REAL), 4) AS avg_sales_per_order
FROM rfm_segments
GROUP BY rfm_segment
ORDER BY avg_sales_per_order DESC