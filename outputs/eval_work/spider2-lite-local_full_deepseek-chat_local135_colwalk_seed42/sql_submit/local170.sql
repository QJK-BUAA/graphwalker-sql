WITH 
-- First, get each legislator's first term start date and gender
first_terms AS (
    SELECT 
        lt.id_bioguide,
        l.gender,
        lt.state,
        MIN(lt.term_start) AS first_term_start
    FROM legislators_terms lt
    JOIN legislators l ON lt.id_bioguide = l.id_bioguide
    WHERE l.gender IN ('M', 'F')
    GROUP BY lt.id_bioguide, l.gender, lt.state
),
-- Generate the six time points (0, 2, 4, 6, 8, 10 years after first term start)
time_points AS (
    SELECT 
        id_bioguide,
        gender,
        state,
        first_term_start,
        0 AS years_offset,
        DATE(first_term_start, '+' || 0 || ' years') AS target_date
    FROM first_terms
    UNION ALL
    SELECT 
        id_bioguide,
        gender,
        state,
        first_term_start,
        2 AS years_offset,
        DATE(first_term_start, '+' || 2 || ' years') AS target_date
    FROM first_terms
    UNION ALL
    SELECT 
        id_bioguide,
        gender,
        state,
        first_term_start,
        4 AS years_offset,
        DATE(first_term_start, '+' || 4 || ' years') AS target_date
    FROM first_terms
    UNION ALL
    SELECT 
        id_bioguide,
        gender,
        state,
        first_term_start,
        6 AS years_offset,
        DATE(first_term_start, '+' || 6 || ' years') AS target_date
    FROM first_terms
    UNION ALL
    SELECT 
        id_bioguide,
        gender,
        state,
        first_term_start,
        8 AS years_offset,
        DATE(first_term_start, '+' || 8 || ' years') AS target_date
    FROM first_terms
    UNION ALL
    SELECT 
        id_bioguide,
        gender,
        state,
        first_term_start,
        10 AS years_offset,
        DATE(first_term_start, '+' || 10 || ' years') AS target_date
    FROM first_terms
),
-- Determine if each legislator is retained on Dec 31 of the target year
retention_check AS (
    SELECT 
        tp.id_bioguide,
        tp.gender,
        tp.state,
        tp.years_offset,
        tp.target_date,
        -- Check if there is any term covering Dec 31 of the target year
        CASE WHEN EXISTS (
            SELECT 1 
            FROM legislators_terms lt2
            WHERE lt2.id_bioguide = tp.id_bioguide
              AND DATE(lt2.term_start) <= DATE(tp.target_date, 'start of year', '+11 months', '+30 days')
              AND DATE(lt2.term_end) >= DATE(tp.target_date, 'start of year', '+11 months', '+30 days')
        ) THEN 1 ELSE 0 END AS retained
    FROM time_points tp
),
-- Aggregate by state, gender, and years_offset
state_gender_retention AS (
    SELECT 
        state,
        gender,
        years_offset,
        COUNT(*) AS total_legislators,
        SUM(retained) AS retained_count,
        CAST(SUM(retained) AS REAL) / COUNT(*) AS retention_rate
    FROM retention_check
    GROUP BY state, gender, years_offset
),
-- Check for each state and gender if all six time points have retention_rate > 0
state_gender_all_positive AS (
    SELECT 
        state,
        gender,
        MIN(retention_rate) AS min_retention_rate
    FROM state_gender_retention
    GROUP BY state, gender
    HAVING MIN(retention_rate) > 0
),
-- Find states where both genders have all positive retention rates
states_both_genders AS (
    SELECT 
        state
    FROM state_gender_all_positive
    GROUP BY state
    HAVING COUNT(DISTINCT gender) = 2
)
SELECT state
FROM states_both_genders
ORDER BY state