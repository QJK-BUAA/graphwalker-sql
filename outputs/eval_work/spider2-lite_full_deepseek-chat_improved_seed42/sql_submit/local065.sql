-- Calculate total income from Meat Lovers (pizza_id=1, $12) and Vegetarian (pizza_id=2, $10) pizzas,
-- including $1 per extra topping, excluding canceled orders (exclusions or extras containing 'cancel').
-- Note: The schema does not have a cancellation flag, so we assume no cancellation filtering needed.
-- If cancellation is indicated by exclusions/extras, we filter those out.

SELECT 
    SUM(
        CASE 
            WHEN pizza_id = 1 THEN 12  -- Meat Lovers
            WHEN pizza_id = 2 THEN 10  -- Vegetarian
            ELSE 0
        END
        + 
        CASE 
            WHEN extras IS NOT NULL AND extras != '' AND extras NOT LIKE '%cancel%' 
            THEN (LENGTH(extras) - LENGTH(REPLACE(extras, ',', '')) + 1) * 1
            ELSE 0
        END
    ) AS total_income
FROM pizza_clean_customer_orders
WHERE pizza_id IN (1, 2)
  AND (exclusions IS NULL OR exclusions = '' OR exclusions NOT LIKE '%cancel%')
  AND (extras IS NULL OR extras = '' OR extras NOT LIKE '%cancel%')