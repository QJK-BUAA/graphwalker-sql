WITH first_terms AS (
    SELECT 
        lt.id_bioguide,
        MIN(lt.term_start) AS first_term_start
    FROM legislators_terms lt
    JOIN legislators l ON lt.id_bioguide = l.id_bioguide
    WHERE l.full_name = 'male' 
      AND (l.id_wikipedia = 'Louisiana' OR l.id_ballotpedia = 'Louisiana')
    GROUP BY lt.id_bioguide
),
years_series AS (
    SELECT DISTINCT CAST(strftime('%Y', date) AS INTEGER) AS year_num
    FROM legislation_date_dim
    WHERE date IS NOT NULL
),
eligible_years AS (
    SELECT 
        ft.id_bioguide,
        ys.year_num,
        CAST(julianday(CAST(ys.year_num || '-12-31' AS TEXT)) - julianday(ft.first_term_start) AS INTEGER) AS days_elapsed,
        ROUND((CAST(julianday(CAST(ys.year_num || '-12-31' AS TEXT)) - julianday(ft.first_term_start) AS REAL) / 365.25), 0) AS years_elapsed
    FROM first_terms ft
    CROSS JOIN years_series ys
    WHERE CAST(julianday(CAST(ys.year_num || '-12-31' AS TEXT)) - julianday(ft.first_term_start) AS REAL) / 365.25 > 30
      AND CAST(julianday(CAST(ys.year_num || '-12-31' AS TEXT)) - julianday(ft.first_term_start) AS REAL) / 365.25 < 50
),
active_legislators AS (
    SELECT 
        e.id_bioguide,
        e.years_elapsed
    FROM eligible_years e
    JOIN legislators_terms lt ON e.id_bioguide = lt.id_bioguide
    WHERE lt.term_start <= CAST(e.year_num || '-12-31' AS TEXT)
      AND lt.term_end >= CAST(e.year_num || '-12-31' AS TEXT)
)
SELECT 
    years_elapsed,
    COUNT(DISTINCT id_bioguide) AS legislator_count
FROM active_legislators
GROUP BY years_elapsed
ORDER BY years_elapsed