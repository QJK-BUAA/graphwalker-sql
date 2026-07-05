-- Count actors who have collaborated more with Yash Chopra than with any other director
WITH actor_director_counts AS (
    SELECT 
        mc.PID AS actor_id,
        md.PID AS director_id,
        COUNT(DISTINCT mc.MID) AS film_count
    FROM M_Cast mc
    JOIN M_Director md ON mc.MID = md.MID
    GROUP BY mc.PID, md.PID
),
yash_chopra_counts AS (
    SELECT 
        actor_id,
        film_count AS yash_count
    FROM actor_director_counts
    WHERE director_id = (SELECT PID FROM Person WHERE Name = 'Yash Chopra' LIMIT 1)
),
other_director_max AS (
    SELECT 
        adc.actor_id,
        MAX(adc.film_count) AS max_other_count
    FROM actor_director_counts adc
    WHERE adc.director_id != (SELECT PID FROM Person WHERE Name = 'Yash Chopra' LIMIT 1)
    GROUP BY adc.actor_id
)
SELECT COUNT(DISTINCT yc.actor_id) AS actor_count
FROM yash_chopra_counts yc
LEFT JOIN other_director_max odm ON yc.actor_id = odm.actor_id
WHERE yc.yash_count > COALESCE(odm.max_other_count, 0)