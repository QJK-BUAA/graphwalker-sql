-- Compute average distance per city pair using haversine formula, then count pairs per distance range, and find the minimum count
WITH city_pairs AS (
    SELECT 
        f1.departure_airport AS city1_code,
        f1.arrival_airport AS city2_code,
        AVG(
            2 * 6371 * ASIN(SQRT(
                POWER(SIN((CAST(SUBSTR(a2.coordinates, 2, INSTR(a2.coordinates, ',')-2) AS REAL) - CAST(SUBSTR(a1.coordinates, 2, INSTR(a1.coordinates, ',')-2) AS REAL)) * 3.141592653589793 / 180 / 2), 2) +
                COS(CAST(SUBSTR(a1.coordinates, 2, INSTR(a1.coordinates, ',')-2) AS REAL) * 3.141592653589793 / 180) *
                COS(CAST(SUBSTR(a2.coordinates, 2, INSTR(a2.coordinates, ',')-2) AS REAL) * 3.141592653589793 / 180) *
                POWER(SIN((CAST(SUBSTR(a2.coordinates, INSTR(a2.coordinates, ',')+1, LENGTH(a2.coordinates)-INSTR(a2.coordinates, ',')-1) AS REAL) - CAST(SUBSTR(a1.coordinates, INSTR(a1.coordinates, ',')+1, LENGTH(a1.coordinates)-INSTR(a1.coordinates, ',')-1) AS REAL)) * 3.141592653589793 / 180 / 2), 2)
            ))
        ) AS avg_distance
    FROM flights f1
    JOIN airports_data a1 ON f1.departure_airport = a1.airport_code
    JOIN airports_data a2 ON f1.arrival_airport = a2.airport_code
    GROUP BY f1.departure_airport, f1.arrival_airport
),
distance_ranges AS (
    SELECT 
        CASE 
            WHEN avg_distance < 1000 THEN '0-1000'
            WHEN avg_distance < 2000 THEN '1000-2000'
            WHEN avg_distance < 3000 THEN '2000-3000'
            WHEN avg_distance < 4000 THEN '3000-4000'
            WHEN avg_distance < 5000 THEN '4000-5000'
            WHEN avg_distance < 6000 THEN '5000-6000'
            ELSE '6000+'
        END AS range_label,
        COUNT(*) AS pair_count
    FROM city_pairs
    GROUP BY range_label
)
SELECT MIN(pair_count) AS fewest_pairs_count
FROM distance_ranges