SELECT 
    c.name AS category_name,
    SUM(CAST(EXTRACT(EPOCH FROM (r.return_date - r.rental_date)) AS REAL) / 3600.0) AS total_rental_hours
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
JOIN store s ON i.store_id = s.store_id
JOIN address a ON s.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
WHERE (ci.city LIKE 'A%' OR ci.city LIKE '%-%')
  AND r.return_date IS NOT NULL
GROUP BY c.category_id, c.name
ORDER BY total_rental_hours DESC
LIMIT 1