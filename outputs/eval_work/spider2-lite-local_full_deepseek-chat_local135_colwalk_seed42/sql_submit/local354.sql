SELECT DISTINCT d.driver_id, d.forename, d.surname
FROM drivers d
JOIN results r ON d.driver_id = r.driver_id
JOIN races ra ON r.race_id = ra.race_id
WHERE ra.year BETWEEN 1950 AND 1959
GROUP BY d.driver_id, ra.year
HAVING COUNT(DISTINCT ra.round) >= 2
   AND MIN(ra.round) = (SELECT MIN(ra2.round) FROM results r2 JOIN races ra2 ON r2.race_id = ra2.race_id WHERE r2.driver_id = d.driver_id AND ra2.year = ra.year)
   AND MAX(ra.round) = (SELECT MAX(ra3.round) FROM results r3 JOIN races ra3 ON r3.race_id = ra3.race_id WHERE r3.driver_id = d.driver_id AND ra3.year = ra.year)
   AND (SELECT r4.constructor_id FROM results r4 JOIN races ra4 ON r4.race_id = ra4.race_id WHERE r4.driver_id = d.driver_id AND ra4.year = ra.year ORDER BY ra4.round ASC LIMIT 1) = 
       (SELECT r5.constructor_id FROM results r5 JOIN races ra5 ON r5.race_id = ra5.race_id WHERE r5.driver_id = d.driver_id AND ra5.year = ra.year ORDER BY ra5.round DESC LIMIT 1)