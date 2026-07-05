-- Step 1: Identify top 5 actors by number of rentals
-- Step 2: Count distinct customers who rented films with those actors
-- Step 3: Divide by total distinct customers and multiply by 100
SELECT 
    CAST(COUNT(DISTINCT c.customer_id) AS REAL) * 100.0 / (SELECT COUNT(*) FROM customer) AS percentage
FROM customer c
WHERE c.customer_id IN (
    SELECT DISTINCT r.customer_id
    FROM rental r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film_actor fa ON i.film_id = fa.film_id
    WHERE fa.actor_id IN (
        SELECT fa2.actor_id
        FROM rental r2
        JOIN inventory i2 ON r2.inventory_id = i2.inventory_id
        JOIN film_actor fa2 ON i2.film_id = fa2.film_id
        GROUP BY fa2.actor_id
        ORDER BY COUNT(*) DESC
        LIMIT 5
    )
)