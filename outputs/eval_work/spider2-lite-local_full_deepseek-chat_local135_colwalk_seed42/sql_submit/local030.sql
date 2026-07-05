SELECT 
    AVG(total_payment) AS avg_total_payment,
    AVG(total_orders) AS avg_total_orders
FROM (
    SELECT 
        c.customer_city,
        SUM(p.payment_value) AS total_payment,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM olist_orders o
    JOIN olist_customers c ON o.customer_id = c.customer_id
    JOIN olist_order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_city
    ORDER BY total_payment ASC
    LIMIT 5
) AS top5_cities