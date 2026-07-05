-- Step 1: Find the country that has data inserted on exactly 9 distinct days in January 2022
WITH country_days AS (
    SELECT 
        country_code_2,
        COUNT(DISTINCT insert_date) AS num_days
    FROM cities
    WHERE insert_date >= '2022-01-01' AND insert_date < '2022-02-01'
    GROUP BY country_code_2
    HAVING num_days = 9
),
-- Step 2: For that country, find all insertion dates in January 2022
country_inserts AS (
    SELECT 
        c.country_code_2,
        c.insert_date,
        c.capital
    FROM cities c
    JOIN country_days cd ON c.country_code_2 = cd.country_code_2
    WHERE c.insert_date >= '2022-01-01' AND c.insert_date < '2022-02-01'
),
-- Step 3: Find consecutive periods (gaps of 1 day or more break consecutiveness)
consecutive_periods AS (
    SELECT 
        country_code_2,
        insert_date,
        insert_date - ROW_NUMBER() OVER (PARTITION BY country_code_2 ORDER BY insert_date) AS grp
    FROM (SELECT DISTINCT country_code_2, insert_date FROM country_inserts)
),
period_lengths AS (
    SELECT 
        country_code_2,
        grp,
        COUNT(*) AS period_length,
        MIN(insert_date) AS start_date,
        MAX(insert_date) AS end_date
    FROM consecutive_periods
    GROUP BY country_code_2, grp
),
-- Step 4: Get the longest consecutive period
longest_period AS (
    SELECT 
        country_code_2,
        start_date,
        end_date,
        period_length
    FROM period_lengths
    ORDER BY period_length DESC
    LIMIT 1
)
-- Step 5: Calculate proportion of capital entries within that period
SELECT 
    CAST(SUM(CASE WHEN ci.capital = 1 THEN 1 ELSE 0 END) AS REAL) / COUNT(*) AS proportion_capital
FROM country_inserts ci
JOIN longest_period lp ON ci.country_code_2 = lp.country_code_2
WHERE ci.insert_date BETWEEN lp.start_date AND lp.end_date