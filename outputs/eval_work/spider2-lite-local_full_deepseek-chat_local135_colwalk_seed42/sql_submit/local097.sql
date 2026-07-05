-- Identify the ten-year period (start year to start year + 9) with the most movies
SELECT 
    CAST(Movie.year AS INTEGER) AS start_year,
    COUNT(*) AS total_count
FROM Movie
GROUP BY start_year
ORDER BY total_count DESC
LIMIT 1