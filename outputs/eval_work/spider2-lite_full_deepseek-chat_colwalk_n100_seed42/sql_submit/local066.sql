-- We need to sum the quantity of each ingredient used in delivered pizzas.
-- The pizza_recipes table lists toppings for each pizza_id as comma-separated values.
-- We need to unnest those toppings, count occurrences, and join with pizza_toppings for names.
-- Only delivered orders: those not cancelled (cancellation IS NULL or empty).
-- Join customer_orders with runner_orders on order_id to filter delivered orders.

WITH delivered_orders AS (
    SELECT co.*
    FROM pizza_clean_customer_orders co
    JOIN pizza_clean_runner_orders ro ON co.order_id = ro.order_id
    WHERE (ro.cancellation IS NULL OR ro.cancellation = '')
),
topping_counts AS (
    SELECT do.pizza_id, do.order_id, do.exclusions, do.extras,
           TRIM(value) AS topping_id
    FROM delivered_orders do
    CROSS JOIN json_each('[' || REPLACE(
        (SELECT toppings FROM pizza_recipes pr WHERE pr.pizza_id = do.pizza_id),
        ',', '","') || ']') 
    -- Note: This approach uses json_each to split comma-separated toppings.
    -- But SQLite's json_each expects a JSON array. We'll use a simpler approach:
    -- Actually, we can use a recursive CTE to split the toppings string.
),
-- Simpler approach: use a recursive CTE to split toppings
split_toppings AS (
    SELECT do.pizza_id, do.order_id, do.exclusions, do.extras,
           TRIM(SUBSTR(pr.toppings, 1, INSTR(pr.toppings || ',', ',') - 1)) AS topping_id,
           SUBSTR(pr.toppings, INSTR(pr.toppings || ',', ',') + 1) AS remaining
    FROM delivered_orders do
    JOIN pizza_recipes pr ON do.pizza_id = pr.pizza_id
    UNION ALL
    SELECT pizza_id, order_id, exclusions, extras,
           TRIM(SUBSTR(remaining, 1, INSTR(remaining || ',', ',') - 1)),
           SUBSTR(remaining, INSTR(remaining || ',', ',') + 1)
    FROM split_toppings
    WHERE remaining != ''
),
all_toppings AS (
    SELECT topping_id
    FROM split_toppings
    WHERE topping_id != ''
)
SELECT pt.topping_name AS name,
       COUNT(*) AS quantity
FROM all_toppings at
JOIN pizza_toppings pt ON CAST(at.topping_id AS INTEGER) = pt.topping_id
GROUP BY pt.topping_name
ORDER BY quantity DESC