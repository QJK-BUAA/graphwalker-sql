-- Calculate total income from Meat Lovers ($12) and Vegetarian ($10) pizzas, plus $1 per extra topping, excluding canceled orders
SELECT 
    SUM(
        CASE 
            WHEN pizza_id = 1 THEN 12  -- Meat Lovers
            WHEN pizza_id = 2 THEN 10  -- Vegetarian
        END
        + 
        CASE 
            WHEN extras IS NOT NULL AND extras != '' AND extras != 'null' 
            THEN (LENGTH(extras) - LENGTH(REPLACE(extras, ',', '')) + 1) * 1
            ELSE 0
        END
    ) AS total_income
FROM pizza_clean_customer_orders
WHERE pizza_id IN (1, 2)
  AND (exclusions IS NULL OR exclusions = '' OR exclusions = 'null' OR exclusions NOT LIKE '%cancel%')