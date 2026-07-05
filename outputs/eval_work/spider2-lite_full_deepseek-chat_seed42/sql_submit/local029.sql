SELECT 
    o.customer_id AS customer_unique_id,
    AVG(p.payment_value) AS avg_payment_value,
    '' AS city,
    '' AS state
FROM olist_orders o
JOIN olist_order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY o.customer_id
ORDER BY COUNT(o.order_id) DESC
LIMIT 3