-- Count actors who have more films with Yash Chopra than with any other director
WITH actor_director_counts AS (
    SELECT 
        mc.PID AS actor_id,
        md.PID AS director_id,
        COUNT(DISTINCT mc.MID) AS film_count
    FROM M_Cast mc
    JOIN M_Director md ON mc.MID = md.MID
    GROUP BY mc.PID, md.PID
),
actor_yash_counts AS (
    SELECT 
        adc.actor_id,
        adc.film_count AS yash_count
    FROM actor_director_counts adc
    JOIN Person p ON adc.director_id = p.PID
    WHERE p.Name = 'Yash Chopra'
),
actor_other_max AS (
    SELECT 
        adc.actor_id,
        MAX(adc.film_count) AS other_max_count
    FROM actor_director_counts adc
    JOIN Person p ON adc.director_id = p.PID
    WHERE p.Name != 'Yash Chopra'
    GROUP BY adc.actor_id
)
SELECT COUNT(DISTINCT ayc.actor_id) AS actor_count
FROM actor_yash_counts ayc
LEFT JOIN actor_other_max aom ON ayc.actor_id = aom.actor_id
WHERE ayc.yash_count > COALESCE(aom.other_max_count, 0)