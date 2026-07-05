SELECT 
    c.name AS category_name,
    SUM(CAST(f.length AS REAL) / 60.0) AS total_rental_hours
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
JOIN city ci ON ci.city_id = ci.city_id  -- placeholder, need to link city to rental via customer/store
WHERE ci.city LIKE 'A%' OR ci.city LIKE '%-%'
GROUP BY c.category_id, c.name
ORDER BY total_rental_hours DESC
LIMIT 1