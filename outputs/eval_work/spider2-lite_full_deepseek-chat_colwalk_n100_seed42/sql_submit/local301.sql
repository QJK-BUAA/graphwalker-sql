WITH pre_june AS (
    SELECT 
        calendar_year,
        SUM(sales) AS pre_sales
    FROM cleaned_weekly_sales
    WHERE 
        calendar_year IN (2018, 2019, 2020)
        AND week_date_formatted >= (CAST(calendar_year AS TEXT) || '-5-18')
        AND week_date_formatted < (CAST(calendar_year AS TEXT) || '-6-15')
    GROUP BY calendar_year
),
post_june AS (
    SELECT 
        calendar_year,
        SUM(sales) AS post_sales
    FROM cleaned_weekly_sales
    WHERE 
        calendar_year IN (2018, 2019, 2020)
        AND week_date_formatted >= (CAST(calendar_year AS TEXT) || '-6-15')
        AND week_date_formatted < (CAST(calendar_year AS TEXT) || '-7-13')
    GROUP BY calendar_year
)
SELECT 
    p.calendar_year,
    ROUND(
        (CAST(p.post_sales AS REAL) - pr.pre_sales) / CAST(pr.pre_sales AS REAL) * 100, 
        4
    ) AS percentage_change
FROM post_june p
JOIN pre_june pr ON p.calendar_year = pr.calendar_year
ORDER BY p.calendar_year