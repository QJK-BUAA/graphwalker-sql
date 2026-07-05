SELECT 
    SUM(
        CASE 
            WHEN pn.pizza_name = 'Meat Lovers' THEN 12
            WHEN pn.pizza_name = 'Vegetarian' THEN 10
            ELSE 0
        END
        + COALESCE(ge.extras_count, 0) * 1
    ) AS total_income
FROM pizza_clean_customer_orders cco
JOIN pizza_names pn ON cco.pizza_id = pn.pizza_id
JOIN pizza_clean_runner_orders ro ON cco.order_id = ro.order_id
LEFT JOIN pizza_get_extras ge ON cco.order_id = ge.order_id AND cco.extras = ge.extras
WHERE ro.cancellation IS NULL
  AND pn.pizza_name IN ('Meat Lovers', 'Vegetarian')