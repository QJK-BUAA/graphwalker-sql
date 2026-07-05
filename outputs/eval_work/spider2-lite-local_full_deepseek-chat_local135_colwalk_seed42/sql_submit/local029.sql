SELECT 
    c.customer_unique_id,
    AVG(p.payment_value) AS avg_payment_value,
    c.customer_city,
    c.customer_state
FROM olist_customers c
JOIN olist_orders o ON c.customer_id = o.customer_id
JOIN olist_order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id, c.customer_city, c.customer_state
ORDER BY COUNT(DISTINCT o.order_id) DESC
LIMIT 3