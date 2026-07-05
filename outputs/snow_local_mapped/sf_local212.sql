SELECT 
    d.driver_id,
    AVG(daily.delivery_count) AS avg_daily_deliveries
FROM drivers d
JOIN (
    SELECT 
        del.driver_id,
        o.order_created_year,
        o.order_created_month,
        o.order_created_day,
        COUNT(*) AS delivery_count
    FROM deliveries del
    JOIN orders o ON del.delivery_order_id = o.order_id
    WHERE del.driver_id IS NOT NULL
    GROUP BY del.driver_id, o.order_created_year, o.order_created_month, o.order_created_day
) daily ON d.driver_id = daily.driver_id
GROUP BY d.driver_id
ORDER BY avg_daily_deliveries DESC
LIMIT 5