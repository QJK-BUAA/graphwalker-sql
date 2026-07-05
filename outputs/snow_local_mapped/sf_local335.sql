-- For each season (year) since 2001, find the total points scored by each constructor's drivers (only considering drivers who scored points in that season).
-- Then, for each season, identify the constructor(s) whose drivers scored the fewest total points among all point-scoring constructors in that season.
-- Finally, count how many seasons each constructor appears as the lowest-scoring constructor, and return the top 5.
WITH driver_points_per_season AS (
    SELECT 
        r.year,
        res.driver_id,
        SUM(res.points) AS total_driver_points
    FROM results res
    JOIN races r ON res.race_id = r.race_id
    WHERE r.year >= 2001
    GROUP BY r.year, res.driver_id
    HAVING SUM(res.points) > 0
),
constructor_points_per_season AS (
    SELECT 
        dps.year,
        res.constructor_id,
        SUM(res.points) AS total_constructor_points
    FROM results res
    JOIN races r ON res.race_id = r.race_id
    JOIN driver_points_per_season dps ON r.year = dps.year AND res.driver_id = dps.driver_id
    WHERE r.year >= 2001
    GROUP BY dps.year, res.constructor_id
),
min_points_per_season AS (
    SELECT 
        year,
        MIN(total_constructor_points) AS min_points
    FROM constructor_points_per_season
    GROUP BY year
),
lowest_constructor_per_season AS (
    SELECT 
        cps.year,
        cps.constructor_id
    FROM constructor_points_per_season cps
    JOIN min_points_per_season mps ON cps.year = mps.year AND cps.total_constructor_points = mps.min_points
)
SELECT 
    c.name AS constructor_name,
    COUNT(*) AS seasons_count
FROM lowest_constructor_per_season lcps
JOIN constructors c ON lcps.constructor_id = c.constructor_id
GROUP BY lcps.constructor_id, c.name
ORDER BY seasons_count DESC, c.name ASC
LIMIT 5