WITH ordered_cities AS (
  SELECT 
    geolocation_state,
    geolocation_city,
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    ROW_NUMBER() OVER (
      ORDER BY 
        geolocation_state, 
        geolocation_city, 
        geolocation_zip_code_prefix, 
        geolocation_lat, 
        geolocation_lng
    ) AS row_num
  FROM olist_geolocation
),
city_distances AS (
  SELECT 
    a.geolocation_state AS state_a,
    a.geolocation_city AS city_a,
    a.geolocation_zip_code_prefix AS zip_a,
    b.geolocation_state AS state_b,
    b.geolocation_city AS city_b,
    b.geolocation_zip_code_prefix AS zip_b,
    6371.0 * 2.0 * ASIN(
      SQRT(
        POWER(SIN((b.geolocation_lat - a.geolocation_lat) * 3.141592653589793 / 360.0), 2) +
        COS(a.geolocation_lat * 3.141592653589793 / 180.0) * 
        COS(b.geolocation_lat * 3.141592653589793 / 180.0) *
        POWER(SIN((b.geolocation_lng - a.geolocation_lng) * 3.141592653589793 / 360.0), 2)
      )
    ) AS distance_km
  FROM ordered_cities a
  JOIN ordered_cities b ON a.row_num = b.row_num - 1
)
SELECT 
  city_a AS city1,
  city_b AS city2,
  ROUND(distance_km, 4) AS distance_km
FROM city_distances
ORDER BY distance_km DESC
LIMIT 1