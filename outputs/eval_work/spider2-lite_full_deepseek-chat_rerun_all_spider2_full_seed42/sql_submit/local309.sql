-- For each year, find the driver with the most points and the constructor with the most points
WITH driver_max AS (
    SELECT 
        r.year,
        d.driver_id,
        d.forename || ' ' || d.surname AS driver_full_name,
        SUM(ds.points) AS total_points
    FROM driver_standings ds
    JOIN races r ON ds.race_id = r.race_id
    JOIN drivers d ON ds.driver_id = d.driver_id
    GROUP BY r.year, d.driver_id, d.forename, d.surname
),
driver_ranked AS (
    SELECT 
        year,
        driver_full_name,
        total_points,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY total_points DESC) AS rn
    FROM driver_max
),
constructor_max AS (
    SELECT 
        r.year,
        c.name AS constructor_name,
        SUM(cs.points) AS total_points
    FROM constructor_standings cs
    JOIN races r ON cs.race_id = r.race_id
    JOIN constructors c ON cs.constructor_id = c.constructor_id
    GROUP BY r.year, c.name
),
constructor_ranked AS (
    SELECT 
        year,
        constructor_name,
        total_points,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY total_points DESC) AS rn
    FROM constructor_max
)
SELECT 
    dr.year,
    dr.driver_full_name,
    cr.constructor_name
FROM driver_ranked dr
JOIN constructor_ranked cr ON dr.year = cr.year
WHERE dr.rn = 1 AND cr.rn = 1
ORDER BY dr.year