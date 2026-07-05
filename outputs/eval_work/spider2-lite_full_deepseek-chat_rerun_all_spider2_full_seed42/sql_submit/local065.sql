-- Calculate total income from Meat Lovers (pizza_id=1, $12) and Vegetarian (pizza_id=2, $10) pizzas,
-- plus $1 per extra topping (count of extras, ignoring empty/null), excluding canceled orders.
-- Canceled orders are those with exclusions or extras containing 'cancel' (case-insensitive).
SELECT 
    SUM(
        CASE 
            WHEN pizza_id = 1 THEN 12  -- Meat Lovers
            WHEN pizza_id = 2 THEN 10  -- Vegetarian
            ELSE 0
        END
        + 
        -- Count extras: each non-empty, non-null extra costs $1
        CASE 
            WHEN extras IS NOT NULL AND extras != '' AND LOWER(extras) NOT LIKE '%cancel%' 
            THEN (LENGTH(extras) - LENGTH(REPLACE(extras, ',', '')) + 1)
            ELSE 0
        END
    ) AS total_income
FROM pizza_clean_customer_orders
WHERE pizza_id IN (1, 2)
  AND (exclusions IS NULL OR exclusions = '' OR LOWER(exclusions) NOT LIKE '%cancel%')
  AND (extras IS NULL OR extras = '' OR LOWER(extras) NOT LIKE '%cancel%')