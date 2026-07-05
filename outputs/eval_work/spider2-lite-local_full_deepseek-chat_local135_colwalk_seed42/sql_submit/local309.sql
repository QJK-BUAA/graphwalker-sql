WITH driver_points_per_year AS (
    SELECT 
        r.year,
        d.driver_id,
        d.full_name,
        SUM(ds.points) AS total_points
    FROM driver_standings ds
    JOIN races r ON ds.race_id = r.race_id
    JOIN drivers d ON ds.driver_id = d.driver_id
    GROUP BY r.year, d.driver_id, d.full_name
),
constructor_points_per_year AS (
    SELECT 
        r.year,
        c.constructor_id,
        c.name AS constructor_name,
        SUM(cr.points) AS total_points
    FROM constructor_results cr
    JOIN races r ON cr.race_id = r.race_id
    JOIN constructors c ON cr.constructor_id = c.constructor_id
    GROUP BY r.year, c.constructor_id, c.name
),
top_driver_per_year AS (
    SELECT 
        year,
        full_name AS driver_name,
        total_points AS driver_points
    FROM driver_points_per_year
    WHERE (year, total_points) IN (
        SELECT year, MAX(total_points)
        FROM driver_points_per_year
        GROUP BY year
    )
),
top_constructor_per_year AS (
    SELECT 
        year,
        constructor_name,
        total_points AS constructor_points
    FROM constructor_points_per_year
    WHERE (year, total_points) IN (
        SELECT year, MAX(total_points)
        FROM constructor_points_per_year
        GROUP BY year
    )
)
SELECT 
    tdp.year,
    tdp.driver_name,
    tcp.constructor_name
FROM top_driver_per_year tdp
JOIN top_constructor_per_year tcp ON tdp.year = tcp.year
ORDER BY tdp.year