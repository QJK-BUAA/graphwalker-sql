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
    SELECT c.PID, d.PID AS director_pid, COUNT(DISTINCT c.MID) AS other_count
    FROM M_Cast c
    JOIN M_Director d ON c.MID = d.MID
    WHERE d.PID != (SELECT PID FROM Person WHERE Name = 'Yash Chopra')
    GROUP BY c.PID, d.PID
),
actors_with_more_yash AS (
    -- Find actors where yash_count > max other_count
    SELECT a.PID
    FROM actor_yash_counts a
    WHERE a.yash_count > COALESCE(
        (SELECT MAX(other_count) FROM actor_other_counts o WHERE o.PID = a.PID),
        0
    )
)
-- Count distinct actors
SELECT COUNT(DISTINCT PID) AS actor_count
FROM actors_with_more_yash