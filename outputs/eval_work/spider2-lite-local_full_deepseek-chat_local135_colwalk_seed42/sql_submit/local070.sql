-- Step 1: Get all distinct dates for Chinese cities in July 2021
WITH chinese_dates AS (
    SELECT DISTINCT c.city_name, ld.date
    FROM cities c
    JOIN legislation_date_dim ld ON c.insert_date = ld.date
    WHERE c.country_code_2 = 'cn'
      AND ld.date >= '2021-07-01' AND ld.date < '2021-08-01'
),
-- Step 2: Assign row numbers to identify consecutive groups
numbered_dates AS (
    SELECT city_name, date,
           ROW_NUMBER() OVER (ORDER BY date) AS rn,
           julianday(date) - ROW_NUMBER() OVER (ORDER BY date) AS grp
    FROM chinese_dates
),
-- Step 3: Compute streak lengths
streak_lengths AS (
    SELECT grp, COUNT(*) AS streak_len,
           MIN(date) AS start_date, MAX(date) AS end_date
    FROM numbered_dates
    GROUP BY grp
),
-- Step 4: Find shortest and longest streak lengths
min_max_streaks AS (
    SELECT MIN(streak_len) AS min_len, MAX(streak_len) AS max_len
    FROM streak_lengths
),
-- Step 5: Get the grp values for shortest and longest streaks
target_streaks AS (
    SELECT grp, streak_len
    FROM streak_lengths
    WHERE streak_len = (SELECT min_len FROM min_max_streaks)
       OR streak_len = (SELECT max_len FROM min_max_streaks)
)
-- Step 6: Return dates and city names for those streaks
SELECT DISTINCT nd.date,
       UPPER(SUBSTR(nd.city_name, 1, 1)) || LOWER(SUBSTR(nd.city_name, 2)) AS city_name
FROM numbered_dates nd
JOIN target_streaks ts ON nd.grp = ts.grp
ORDER BY nd.date