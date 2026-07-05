SELECT 
    r.year,
    d.full_name AS driver_full_name,
    c.name AS constructor_name,
    MAX(ds.points) AS driver_points,
    MAX(cr.points) AS constructor_points
FROM races r
JOIN driver_standings ds ON r.race_id = ds.race_id
JOIN drivers d ON ds.driver_id = d.driver_id
JOIN constructor_results cr ON r.race_id = cr.race_id
JOIN constructors c ON cr.constructor_id = c.constructor_id
GROUP BY r.year
ORDER BY r.year