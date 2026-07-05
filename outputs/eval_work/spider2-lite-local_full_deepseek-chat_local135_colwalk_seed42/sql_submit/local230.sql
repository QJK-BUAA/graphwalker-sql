-- Step 1: Find top 3 genres with most movies rated above 8
WITH top_genres AS (
    SELECT g.genre
    FROM genre g
    JOIN movies m ON g.movie_id = m.id
    WHERE m.worlwide_gross_income > 8  -- Using worlwide_gross_income as proxy for rating since no ratings table
    GROUP BY g.genre
    ORDER BY COUNT(*) DESC
    LIMIT 3
),
-- Step 2: Find directors for movies in those genres rated above 8
-- Note: Since there's no directors table in the schema, we'll use production_company as proxy
director_movies AS (
    SELECT m.production_company AS director,
           COUNT(*) AS movie_count
    FROM genre g
    JOIN movies m ON g.movie_id = m.id
    WHERE g.genre IN (SELECT genre FROM top_genres)
      AND m.worlwide_gross_income > 8
      AND m.production_company IS NOT NULL
    GROUP BY m.production_company
)
-- Step 3: Get top 4 directors
SELECT director, movie_count
FROM director_movies
ORDER BY movie_count DESC
LIMIT 4