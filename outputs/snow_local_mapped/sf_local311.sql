SELECT 
    c.name AS constructor,
    r.year,
    MAX(dr.points) AS best_driver_points,
    cs.points AS constructor_points,
    MAX(dr.points) + cs.points AS combined_points
FROM constructors c
JOIN constructor_standings cs ON c.constructor_id = cs.constructor_id
JOIN races r ON cs.race_id = r.race_id
JOIN results dr ON dr.constructor_id = c.constructor_id AND dr.race_id = r.race_id
JOIN drivers d ON dr.driver_id = d.driver_id
GROUP BY c.constructor_id, c.name, r.year, cs.points
ORDER BY combined_points DESC
LIMIT 3