-- Seller with highest distinct customer unique IDs
SELECT 'Highest distinct customer unique IDs' AS achievement, s.seller_id, COUNT(DISTINCT c.customer_unique_id) AS value
FROM olist_sellers s
JOIN olist_order_items oi ON s.seller_id = oi.seller_id
JOIN olist_orders o ON oi.order_id = o.order_id
JOIN olist_customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id
ORDER BY value DESC
LIMIT 1

UNION ALL

-- Seller with highest profit (price - freight_value)
SELECT 'Highest profit' AS achievement, s.seller_id, SUM(oi.price - oi.freight_value) AS value
FROM olist_sellers s
JOIN olist_order_items oi ON s.seller_id = oi.seller_id
JOIN olist_orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id
ORDER BY value DESC
LIMIT 1

UNION ALL

-- Seller with highest distinct orders
SELECT 'Highest distinct orders' AS achievement, s.seller_id, COUNT(DISTINCT oi.order_id) AS value
FROM olist_sellers s
JOIN olist_order_items oi ON s.seller_id = oi.seller_id
JOIN olist_orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id
ORDER BY value DESC
LIMIT 1

UNION ALL

-- Seller with most 5-star ratings
SELECT 'Most 5-star ratings' AS achievement, s.seller_id, COUNT(*) AS value
FROM olist_sellers s
JOIN olist_order_items oi ON s.seller_id = oi.seller_id
JOIN olist_orders o ON oi.order_id = o.order_id
JOIN olist_order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered' AND r.review_score = 5
GROUP BY s.seller_id
ORDER BY value DESC
LIMIT 1