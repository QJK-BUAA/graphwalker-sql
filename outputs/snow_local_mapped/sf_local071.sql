-- Identify countries with the longest streak of consecutive inserted city dates in June 2022
WITH filtered_dates AS (
    SELECT 
        country_code_2,
        insert_date,
        ROW_NUMBER() OVER (PARTITION BY country_code_2 ORDER BY insert_date) AS rn,
        DATE(insert_date) - ROW_NUMBER() OVER (PARTITION BY country_code_2 ORDER BY insert_date) AS grp
    FROM cities
    WHERE insert_date >= '2022-06-01' AND insert_date < '2022-07-01'
),
streaks AS (
    SELECT 
        country_code_2,
        COUNT(*) AS streak_length
    FROM filtered_dates
    GROUP BY country_code_2, grp
),
max_streak AS (
    SELECT MAX(streak_length) AS max_len FROM streaks
)
SELECT country_code_2
FROM streaks
WHERE streak_length = (SELECT max_len FROM max_streak)
ORDER BY country_code_2