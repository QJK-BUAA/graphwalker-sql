-- Calculate average number of new unicorn companies per year in the top industry from 2019 to 2021
WITH top_industry AS (
    SELECT industry
    FROM companies_industries
    GROUP BY industry
    ORDER BY COUNT(DISTINCT companies_industries.company_id) DESC
    LIMIT 1
),
yearly_counts AS (
    SELECT 
        CAST(SUBSTR(d.date_joined, 1, 4) AS INTEGER) AS year,
        COUNT(DISTINCT d.company_id) AS cnt
    FROM companies_dates d
    JOIN companies_industries i ON d.company_id = i.company_id
    WHERE i.industry = (SELECT industry FROM top_industry)
      AND CAST(SUBSTR(d.date_joined, 1, 4) AS INTEGER) BETWEEN 2019 AND 2021
    GROUP BY year
)
SELECT ROUND(AVG(CAST(cnt AS REAL)), 4) AS avg_new_unicorns_per_year
FROM yearly_counts