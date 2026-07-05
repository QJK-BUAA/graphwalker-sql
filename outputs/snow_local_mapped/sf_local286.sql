SELECT 
    s.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_sales,
    AVG(oi.price) AS average_item_price,
    AVG(oi.price * oi.order_item_id) / NULLIF(COUNT(oi.order_item_id), 0) AS average_review_scores,
    AVG(CAST(julianday(o.order_delivered_carrier_date) - julianday(o.order_purchase_timestamp) AS REAL)) AS packing_times,
    pct.product_category_name_english
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation pct ON p.product_category_name = pct.product_category_name
GROUP BY s.seller_id, pct.product_category_name_english
HAVING COUNT(oi.order_item_id) > 100
ORDER BY COUNT(oi.order_item_id) DESC