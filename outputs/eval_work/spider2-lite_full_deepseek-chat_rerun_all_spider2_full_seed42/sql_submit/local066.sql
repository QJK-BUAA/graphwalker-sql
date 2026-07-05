SELECT 
    pt.topping_name AS ingredient_name,
    COUNT(pt.topping_id) AS total_quantity
FROM pizza_recipes pr
JOIN pizza_names pn ON pr.pizza_id = pn.pizza_id
JOIN pizza_toppings pt ON ',' || pr.toppings || ',' LIKE '%,' || pt.topping_id || ',%'
GROUP BY pt.topping_name
ORDER BY total_quantity DESC