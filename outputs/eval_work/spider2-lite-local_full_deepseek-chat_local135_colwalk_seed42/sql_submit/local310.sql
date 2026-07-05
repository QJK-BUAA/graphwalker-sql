WITH driver_points AS (
    SELECT 
        r.year,
        res.driver_id,
        SUM(res.points) AS total_points
    FROM results res
    JOIN races r ON res.race_id = r.race_id
    GROUP BY r.year, res.driver_id
),
constructor_points AS (
    SELECT 
        r.year,
        res.constructor_id,
        SUM(res.points) AS total_points
    FROM results res
    JOIN races r ON res.race_id = r.race_id
    GROUP BY r.year, res.constructor_id
),
max_driver_points AS (
    SELECT 
        year,
        MAX(total_points) AS max_driver_points
    FROM driver_points
    GROUP BY year
),
max_constructor_points AS (
    SELECT 
        year,
        MAX(total_points) AS max_constructor_points
    FROM constructor_points
    GROUP BY year
),
combined AS (
    SELECT 
        md.year,
        md.max_driver_points + mc.max_constructor_points AS total_sum
    FROM max_driver_points md
    JOIN max_constructor_points mc ON md.year = mc.year
)
SELECT year
FROM combined
ORDER BY total_sum ASC
LIMIT 3