-- We need to sum the quantity of each ingredient used in delivered pizzas.
-- First, we need to identify delivered orders (not cancelled) from pizza_clean_runner_orders.
-- Then join with pizza_clean_customer_orders to get the pizza_id for each delivered order.
-- Then join with pizza_recipes to get the toppings (ingredients) for each pizza.
-- The toppings column in pizza_recipes is a comma-separated list of topping_ids.
-- We need to unroll that list and count each topping_id.
-- Finally, join with pizza_toppings to get the topping_name.

WITH delivered_orders AS (
    SELECT order_id
    FROM pizza_clean_runner_orders
    WHERE cancellation IS NULL OR cancellation = ''
),
pizza_ingredients AS (
    SELECT c.pizza_id, r.toppings
    FROM pizza_clean_customer_orders c
    JOIN delivered_orders d ON c.order_id = d.order_id
    JOIN pizza_recipes r ON c.pizza_id = r.pizza_id
),
topping_counts AS (
    SELECT TRIM(value) AS topping_id
    FROM pizza_ingredients,
         json_each('[' || REPLACE(toppings, ',', '","') || ']')
    WHERE toppings IS NOT NULL AND toppings != ''
)
SELECT t.topping_name AS name, COUNT(*) AS quantity
FROM topping_counts tc
JOIN pizza_toppings t ON CAST(tc.topping_id AS INTEGER) = t.topping_id
GROUP BY t.topping_name
ORDER BY quantity DESC