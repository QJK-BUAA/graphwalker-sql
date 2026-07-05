WITH actor_director_counts AS (
    SELECT 
        mc.PID AS actor_id,
        md.PID AS director_id,
        COUNT(*) AS film_count
    FROM M_Cast mc
    JOIN M_Director md ON mc.MID = md.MID
    GROUP BY mc.PID, md.PID
),
yash_chopra_id AS (
    SELECT PID FROM Person WHERE Name = 'Yash Chopra'
),
actor_yash_count AS (
    SELECT 
        adc.actor_id,
        adc.film_count AS yash_films
    FROM actor_director_counts adc
    JOIN yash_chopra_id yc ON adc.director_id = yc.PID
),
actor_other_max AS (
    SELECT 
        adc.actor_id,
        MAX(adc.film_count) AS other_max_films
    FROM actor_director_counts adc
    WHERE adc.director_id NOT IN (SELECT PID FROM yash_chopra_id)
    GROUP BY adc.actor_id
)
SELECT COUNT(*) AS actor_count
FROM actor_yash_count ayc
LEFT JOIN actor_other_max aom ON ayc.actor_id = aom.actor_id
WHERE ayc.yash_films > COALESCE(aom.other_max_films, 0)