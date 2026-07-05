-- For each year, find the top 2 most common primary collision factors (causes)
-- Then find the year(s) where the set of top 2 causes is unique compared to all other years
WITH yearly_top_causes AS (
    SELECT 
        strftime('%Y', collisions.collision_date) AS year,
        collisions.primary_collision_factor AS cause,
        COUNT(*) AS cnt,
        ROW_NUMBER() OVER (PARTITION BY strftime('%Y', collisions.collision_date) ORDER BY COUNT(*) DESC) AS rn
    FROM collisions
    WHERE collisions.primary_collision_factor IS NOT NULL
    GROUP BY year, cause
),
top2_per_year AS (
    SELECT year, cause
    FROM yearly_top_causes
    WHERE rn <= 2
),
years_with_unique_top2 AS (
    SELECT t1.year
    FROM top2_per_year t1
    WHERE NOT EXISTS (
        SELECT 1
        FROM top2_per_year t2
        WHERE t2.year != t1.year
        AND (
            SELECT COUNT(DISTINCT t3.cause)
            FROM top2_per_year t3
            WHERE t3.year = t1.year
            AND t3.cause IN (SELECT t4.cause FROM top2_per_year t4 WHERE t4.year = t2.year)
        ) = 2
    )
)
SELECT year
FROM years_with_unique_top2