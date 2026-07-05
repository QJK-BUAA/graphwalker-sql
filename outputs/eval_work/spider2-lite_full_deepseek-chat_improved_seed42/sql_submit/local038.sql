SELECT a.first_name || ' ' || a.last_name AS actor_full_name
FROM actor a
JOIN film_actor fa ON a.actor_id = fa.actor_id
JOIN film f ON fa.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
JOIN language l ON f.language_id = l.language_id
WHERE c.name = 'Children'
  AND f.rating IN ('G', 'PG')
  AND f.length <= 120
  AND CAST(f.release_year AS INTEGER) BETWEEN 2000 AND 2010
  AND l.name = 'English'
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY COUNT(*) DESC
LIMIT 1