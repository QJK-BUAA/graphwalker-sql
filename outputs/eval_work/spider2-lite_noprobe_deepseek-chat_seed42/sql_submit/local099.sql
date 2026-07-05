-- Count actors who have more films with Yash Chopra than with any other director
WITH actor_film_counts AS (
    SELECT 
        mc.PID,
        md.PID AS director_PID,
        COUNT(DISTINCT mc.MID) AS film_count
    FROM M_Cast mc
    JOIN M_Director md ON mc.MID = md.MID
    GROUP BY mc.PID, md.PID
),
yash_chopra_films AS (
    SELECT 
        mc.PID,
        COUNT(DISTINCT mc.MID) AS yash_films
    FROM M_Cast mc
    JOIN M_Director md ON mc.MID = md.MID
    JOIN Person p ON md.PID = p.PID
    WHERE p.Name = 'Yash Chopra'
    GROUP BY mc.PID
),
other_director_max AS (
    SELECT 
        afc.PID,
        MAX(afc.film_count) AS max_other_films
    FROM actor_film_counts afc
    JOIN Person p ON afc.director_PID = p.PID
    WHERE p.Name != 'Yash Chopra'
    GROUP BY afc.PID
)
SELECT COUNT(DISTINCT ycf.PID) AS actor_count
FROM yash_chopra_films ycf
LEFT JOIN other_director_max odm ON ycf.PID = odm.PID
WHERE ycf.yash_films > COALESCE(odm.max_other_films, 0)