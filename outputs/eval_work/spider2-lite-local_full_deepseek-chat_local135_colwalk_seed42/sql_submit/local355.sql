-- Step 1: Identify all races per year per driver, ordered by round
-- Step 2: Find gaps (missed races) by comparing consecutive rounds
-- Step 3: For each gap, get the race before and after the gap, check constructor change
-- Step 4: Filter drivers with <3 missed races in a year
-- Step 5: Compute overall average first_round and last_round of missed races

WITH driver_races AS (
    SELECT 
        r.year,
        r.race_id,
        r.round,
        dr.driver_id,
        dr.forename || ' ' || dr.surname AS driver_name,
        res.constructor_id
    FROM races r
    JOIN results res ON r.race_id = res.race_id
    JOIN drivers dr ON res.driver_id = dr.driver_id
),
-- For each driver, find all rounds they participated in per year
driver_rounds AS (
    SELECT 
        year,
        driver_id,
        driver_name,
        round,
        race_id,
        constructor_id,
        LAG(round) OVER (PARTITION BY year, driver_id ORDER BY round) AS prev_round,
        LEAD(round) OVER (PARTITION BY year, driver_id ORDER BY round) AS next_round,
        LAG(constructor_id) OVER (PARTITION BY year, driver_id ORDER BY round) AS prev_constructor,
        LEAD(constructor_id) OVER (PARTITION BY year, driver_id ORDER BY round) AS next_constructor
    FROM driver_races
),
-- Identify gaps (missed races) where there is a jump in round numbers
gaps AS (
    SELECT 
        year,
        driver_id,
        driver_name,
        prev_round + 1 AS first_missed_round,
        round - 1 AS last_missed_round,
        prev_constructor AS constructor_before,
        constructor_id AS constructor_after,
        (round - prev_round - 1) AS races_missed
    FROM driver_rounds
    WHERE prev_round IS NOT NULL 
      AND round - prev_round > 1
),
-- Count total missed races per driver per year
missed_counts AS (
    SELECT 
        year,
        driver_id,
        driver_name,
        SUM(races_missed) AS total_missed
    FROM gaps
    GROUP BY year, driver_id, driver_name
),
-- Filter drivers with fewer than 3 missed races in a year
eligible_drivers AS (
    SELECT 
        year,
        driver_id,
        driver_name
    FROM missed_counts
    WHERE total_missed < 3
),
-- For eligible drivers, get gaps where constructor changed
eligible_gaps AS (
    SELECT 
        g.year,
        g.driver_id,
        g.driver_name,
        g.first_missed_round,
        g.last_missed_round,
        g.races_missed
    FROM gaps g
    JOIN eligible_drivers e 
      ON g.year = e.year 
     AND g.driver_id = e.driver_id
    WHERE g.constructor_before IS NOT NULL 
      AND g.constructor_after IS NOT NULL
      AND g.constructor_before != g.constructor_after
)
-- Overall averages
SELECT 
    AVG(CAST(first_missed_round AS REAL)) AS avg_first_round,
    AVG(CAST(last_missed_round AS REAL)) AS avg_last_round
FROM eligible_gaps