WITH first_rental AS (
    SELECT 
        c.customer_id,
        f.rating,
        f.film_id,
        MIN(p.payment_date) AS first_payment_date
    FROM customer c
    JOIN payment p ON c.customer_id = p.customer_id
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    GROUP BY c.customer_id
),
customer_stats AS (
    SELECT 
        c.customer_id,
        fr.rating,
        SUM(p.amount) AS total_spent,
        COUNT(DISTINCT r.rental_id) AS total_rentals
    FROM customer c
    JOIN payment p ON c.customer_id = p.customer_id
    JOIN rental r ON c.customer_id = r.customer_id
    JOIN first_rental fr ON c.customer_id = fr.customer_id
    GROUP BY c.customer_id, fr.rating
)
SELECT 
    rating,
    AVG(total_spent) AS avg_total_spent_per_customer,
    AVG(CAST(total_rentals - 1 AS REAL)) AS avg_subsequent_rentals
FROM customer_stats
GROUP BY rating
ORDER BY rating