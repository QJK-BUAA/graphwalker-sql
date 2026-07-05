-- First, we need to get the delivered orders (not cancelled)
-- Then join with customer orders to get the pizzas ordered
-- Then join with recipes to get the toppings for each pizza
-- Then join with toppings to get the ingredient names
-- Finally, sum up the quantities per ingredient

WITH delivered_orders AS (
    SELECT order_id
    FROM pizza_clean_runner_orders
    WHERE cancellation IS NULL OR cancellation = ''
),
pizza_ingredients AS (
    SELECT 
        co.order_id,
        co.pizza_id,
        CAST(SUBSTR(pr.toppings, value) AS INTEGER) AS topping_id
    FROM pizza_clean_customer_orders co
    JOIN delivered_orders do ON co.order_id = do.order_id
    JOIN pizza_recipes pr ON co.pizza_id = pr.pizza_id
    -- Split the comma-separated toppings list
    JOIN json_each('[' || pr.toppings || ']') 
)
SELECT 
    pt.topping_name AS name,
    COUNT(*) AS quantity
FROM pizza_ingredients pi
JOIN pizza_toppings pt ON pi.topping_id = pt.topping_id
GROUP BY pt.topping_name
ORDER BY pt.topping_name