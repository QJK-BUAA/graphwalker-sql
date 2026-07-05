WITH 
-- Step 1: Identify the cohort: legislators who began their first term between 1917-01-01 and 1999-12-31
cohort AS (
    SELECT lt.id_bioguide, lt.term_start AS first_term_start
    FROM legislators_terms lt
    WHERE lt.term_number = 0
      AND lt.term_start >= '1917-01-01'
      AND lt.term_start <= '1999-12-31'
),
-- Step 2: For each cohort member, determine if they were still in office on Dec 31 of each year from year 0 to year 19 after their first term start
-- We generate a series of 20 years (0 to 19) for each cohort member
years AS (
    SELECT 0 AS year_offset
    UNION ALL SELECT 1
    UNION ALL SELECT 2
    UNION ALL SELECT 3
    UNION ALL SELECT 4
    UNION ALL SELECT 5
    UNION ALL SELECT 6
    UNION ALL SELECT 7
    UNION ALL SELECT 8
    UNION ALL SELECT 9
    UNION ALL SELECT 10
    UNION ALL SELECT 11
    UNION ALL SELECT 12
    UNION ALL SELECT 13
    UNION ALL SELECT 14
    UNION ALL SELECT 15
    UNION ALL SELECT 16
    UNION ALL SELECT 17
    UNION ALL SELECT 18
    UNION ALL SELECT 19
),
-- Cross join cohort with years to get all combinations
cohort_years AS (
    SELECT c.id_bioguide, c.first_term_start, y.year_offset,
           date(c.first_term_start, '+' || y.year_offset || ' years') AS target_date
    FROM cohort c
    CROSS JOIN years y
),
-- Check if the legislator had a term covering Dec 31 of the target year
-- A term covers Dec 31 of target year if term_start <= target_date AND term_end >= target_date
-- Note: target_date is Dec 31 of the year that is year_offset years after first_term_start
-- We need to compute Dec 31 of that year
retention_check AS (
    SELECT cy.id_bioguide, cy.first_term_start, cy.year_offset,
           -- Compute Dec 31 of the year containing target_date
           date(cy.target_date, 'start of year', '+11 months', '+30 days') AS dec31_date,
           -- Check if any term covers this Dec 31
           MAX(CASE WHEN lt.term_start <= date(cy.target_date, 'start of year', '+11 months', '+30 days')
                     AND lt.term_end >= date(cy.target_date, 'start of year', '+11 months', '+30 days')
                THEN 1 ELSE 0 END) AS retained
    FROM cohort_years cy
    LEFT JOIN legislators_terms lt ON cy.id_bioguide = lt.id_bioguide
    GROUP BY cy.id_bioguide, cy.first_term_start, cy.year_offset
)
-- Step 3: Compute retention rate per year_offset
SELECT 
    rc.year_offset + 1 AS period_number,
    CAST(SUM(rc.retained) AS REAL) / COUNT(*) AS retention_rate
FROM retention_check rc
GROUP BY rc.year_offset
ORDER BY rc.year_offset