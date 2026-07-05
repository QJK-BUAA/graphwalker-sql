-- Calculate total income from Meat Lovers ($12) and Vegetarian ($10) pizzas, plus $1 per extra topping, excluding canceled orders
SELECT 
    SUM(
        CASE 
            WHEN pc.pizza_id = 1 THEN 12  -- Meat Lovers
            WHEN pc.pizza_id = 2 THEN 10  -- Vegetarian
        END
        + COALESCE(
            (LENGTH(pc.extras) - LENGTH(REPLACE(pc.extras, ',', '')) + 1) 
            * CASE WHEN pc.extras IS NOT NULL AND pc.extras != '' THEN 1 ELSE 0 END,
            0
        )
    ) AS total_earned
FROM pizza_clean_customer_orders pc
JOIN pizza_clean_runner_orders ro ON pc.order_id = ro.order_id
WHERE ro.cancellation IS NULL OR ro.cancellation = ''
  AND pc.pizza_id IN (1, 2)