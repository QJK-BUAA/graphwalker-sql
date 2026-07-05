SELECT 
    r.year,
    d.full_name AS driver_name,
    c.name AS constructor_name
FROM (
    SELECT 
        race_id,
        driver_id,
        points,
        ROW_NUMBER() OVER (PARTITION BY race_id ORDER BY points DESC) AS rn
    FROM driver_standings
) ds
JOIN races r ON ds.race_id = r.race_id
JOIN drivers d ON ds.driver_id = d.driver_id
JOIN (
    SELECT 
        race_id,
        constructor_id,
        points,
        ROW_NUMBER() OVER (PARTITION BY race_id ORDER BY points DESC) AS rn
    FROM constructor_standings
) cs ON ds.race_id = cs.race_id AND cs.rn = 1
JOIN constructors c ON cs.constructor_id = c.constructor_id
WHERE ds.rn = 1
ORDER BY r.year