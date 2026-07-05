-- Count actors who have more films with Yash Chopra than with any other director
WITH yash_chopra_movies AS (
    -- Get all movies directed by Yash Chopra
    SELECT DISTINCT d.MID
    FROM M_Director d
    JOIN Person p ON d.PID = p.PID
    WHERE p.Name = 'Yash Chopra'
),
actor_yash_counts AS (
    -- Count films each actor made with Yash Chopra
    SELECT c.PID, COUNT(DISTINCT c.MID) AS yash_count
    FROM M_Cast c
    WHERE c.MID IN (SELECT MID FROM yash_chopra_movies)
    GROUP BY c.PID
),
actor_other_counts AS (
    -- For each actor, count films with every other director
    SELECT c.PID, d.PID AS director_PID, COUNT(DISTINCT c.MID) AS other_count
    FROM M_Cast c
    JOIN M_Director d ON c.MID = d.MID
    WHERE d.PID != (SELECT PID FROM Person WHERE Name = 'Yash Chopra')
    GROUP BY c.PID, d.PID
),
actor_max_other AS (
    -- Get the maximum count with any other director for each actor
    SELECT PID, MAX(other_count) AS max_other
    FROM actor_other_counts
    GROUP BY PID
)
-- Count actors where yash_count > max_other (or max_other is NULL meaning no other director)
SELECT COUNT(*) AS actor_count
FROM actor_yash_counts ayc
LEFT JOIN actor_max_other amo ON ayc.PID = amo.PID
WHERE ayc.yash_count > COALESCE(amo.max_other, 0)