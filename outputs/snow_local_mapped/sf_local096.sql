WITH 
-- Extract year from Movie.year (last 4 characters)
movie_years AS (
    SELECT 
        MID,
        CAST(SUBSTR(year, -4) AS INTEGER) AS year_num
    FROM Movie
),
-- Identify movies that have at least one non-female actor (Male or None)
movies_with_non_female AS (
    SELECT DISTINCT mc.MID
    FROM M_Cast mc
    JOIN Person p ON mc.PID = p.PID
    WHERE p.Gender IN ('Male', 'None')
),
-- Identify movies that have exclusively female actors
exclusive_female_movies AS (
    SELECT my.MID, my.year_num
    FROM movie_years my
    WHERE my.MID NOT IN (SELECT MID FROM movies_with_non_female)
)
-- Final aggregation
SELECT 
    my.year_num AS year,
    COUNT(DISTINCT my.MID) AS total_movies,
    ROUND(
        CAST(COUNT(DISTINCT efm.MID) AS REAL) / NULLIF(COUNT(DISTINCT my.MID), 0) * 100, 
        4
    ) AS percentage_exclusive_female
FROM movie_years my
LEFT JOIN exclusive_female_movies efm ON my.MID = efm.MID AND my.year_num = efm.year_num
GROUP BY my.year_num
ORDER BY my.year_num