-- Calculate total income from Meat Lovers ($12) and Vegetarian ($10) pizzas, plus $1 per extra topping, excluding canceled orders
SELECT 
    SUM(
        CASE 
            WHEN pizza_names.pizza_name = 'Meat Lovers' THEN 12
            WHEN pizza_names.pizza_name = 'Vegetarian' THEN 10
            ELSE 0
        END
        + COALESCE((
            SELECT SUM(pizza_get_extras.extras_count * 1)
            FROM pizza_get_extras
            WHERE pizza_get_extras.order_id = pizza_clean_customer_orders.order_id
              AND pizza_get_extras.extras IS NOT NULL
        ), 0)
    ) AS total_earned
FROM pizza_clean_customer_orders
JOIN pizza_names ON pizza_clean_customer_orders.pizza_id = pizza_names.pizza_id
WHERE pizza_names.pizza_name IN ('Meat Lovers', 'Vegetarian')
  AND pizza_clean_customer_orders.order_id NOT IN (
      SELECT order_id FROM pizza_clean_customer_orders WHERE order_time IS NULL
  )