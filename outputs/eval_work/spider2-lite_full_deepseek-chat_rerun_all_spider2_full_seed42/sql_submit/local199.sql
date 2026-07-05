WITH store_rentals AS (
    SELECT 
        s.store_id,
        strftime('%Y', r.rental_date) AS year,
        strftime('%m', r.rental_date) AS month,
        COUNT(*) AS total_rentals
    FROM rental r
    JOIN staff st ON r.staff_id = st.staff_id
    JOIN store s ON st.store_id = s.store_id
    GROUP BY s.store_id, year, month
),
ranked AS (
    SELECT 
        store_id,
        year,
        month,
        total_rentals,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY total_rentals DESC) AS rn
    FROM store_rentals
)
SELECT 
    store_id,
    year,
    month,
    total_rentals
FROM ranked
WHERE rn = 1
ORDER BY store_id