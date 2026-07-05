-- Compute the distance of the longest route where Abakan is either the departure or destination city
-- Using the Haversine formula with coordinates stored as point (x,y) = (longitude, latitude)
-- Coordinates are in degrees, need to convert to radians
-- Earth radius = 6371 km

WITH abakan_airports AS (
    SELECT airport_code
    FROM airports_data
    WHERE city LIKE '%"Abakan"%' OR airport_name LIKE '%"Abakan"%'
),
route_distances AS (
    SELECT 
        f.flight_id,
        -- Haversine distance in km
        6371.0 * 2.0 * ASIN(
            SQRT(
                POWER(SIN(RADIANS((CAST(SUBSTR(a2.coordinates, 2, INSTR(a2.coordinates, ',') - 2) AS REAL) - CAST(SUBSTR(a1.coordinates, 2, INSTR(a1.coordinates, ',') - 2) AS REAL)) / 2.0)), 2) +
                COS(RADIANS(CAST(SUBSTR(a1.coordinates, 2, INSTR(a1.coordinates, ',') - 2) AS REAL))) *
                COS(RADIANS(CAST(SUBSTR(a2.coordinates, 2, INSTR(a2.coordinates, ',') - 2) AS REAL))) *
                POWER(SIN(RADIANS((CAST(SUBSTR(a2.coordinates, INSTR(a2.coordinates, ',') + 1, LENGTH(a2.coordinates) - INSTR(a2.coordinates, ',') - 1) AS REAL) - CAST(SUBSTR(a1.coordinates, INSTR(a1.coordinates, ',') + 1, LENGTH(a1.coordinates) - INSTR(a1.coordinates, ',') - 1) AS REAL)) / 2.0)), 2)
            )
        ) AS distance_km
    FROM flights f
    JOIN airports_data a1 ON f.departure_airport = a1.airport_code
    JOIN airports_data a2 ON f.arrival_airport = a2.airport_code
    WHERE (f.departure_airport IN (SELECT airport_code FROM abakan_airports) 
           OR f.arrival_airport IN (SELECT airport_code FROM abakan_airports))
)
SELECT MAX(distance_km) AS longest_route_km
FROM route_distances