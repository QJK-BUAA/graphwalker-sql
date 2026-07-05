SELECT 
    co.rowid AS row_id,
    co.order_id,
    co.customer_id,
    CASE 
        WHEN co.pizza_id = 1 THEN 'Meatlovers'
        ELSE 'Other'
    END AS pizza_name,
    CASE 
        WHEN co.pizza_id = 1 THEN 'Meatlovers: '
        ELSE 'Other: '
    END || 
    COALESCE(
        (SELECT GROUP_CONCAT(DISTINCT e.extras ORDER BY e.extras) 
         FROM pizza_get_extras e 
         WHERE e.order_id = co.order_id),
        ''
    ) AS final_ingredients
FROM pizza_clean_customer_orders co
GROUP BY co.rowid, co.order_id, 
         CASE WHEN co.pizza_id = 1 THEN 'Meatlovers' ELSE 'Other' END,
         co.order_time
ORDER BY co.rowid ASC