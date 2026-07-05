-- Count actors who have more films with Yash Chopra than with any other director
WITH actor_films AS (
    SELECT 
        mc.PID AS actor_id,
        md.PID AS director_id,
        COUNT(DISTINCT mc.MID) AS film_count
    FROM M_Cast mc
    JOIN M_Director md ON mc.MID = md.MID
    GROUP BY mc.PID, md.PID
),
yash_chopra_films AS (
    SELECT 
        actor_id,
        film_count AS yash_count
    FROM actor_films
    WHERE director_id = (SELECT PID FROM Person WHERE Name = 'Yash Chopra')
),
other_director_max AS (
    SELECT 
        af.actor_id,
        MAX(af.film_count) AS max_other_count
    FROM actor_films af
    WHERE af.director_id != (SELECT PID FROM Person WHERE Name = 'Yash Chopra')
    GROUP BY af.actor_id
)
SELECT COUNT(DISTINCT ycf.actor_id) AS actor_count
FROM yash_chopra_films ycf
LEFT JOIN other_director_max odm ON ycf.actor_id = odm.actor_id
WHERE ycf.yash_count > COALESCE(odm.max_other_count, 0)