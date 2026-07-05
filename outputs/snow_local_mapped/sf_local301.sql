WITH before_june15 AS (
    SELECT 
        calendar_year,
        SUM(sales) AS total_sales_before
    FROM cleaned_weekly_sales
    WHERE 
        calendar_year IN (2018, 2019, 2020)
        AND week_date_formatted >= (CAST(calendar_year AS TEXT) || '-5-18')
        AND week_date_formatted < (CAST(calendar_year AS TEXT) || '-6-15')
    GROUP BY calendar_year
),
after_june15 AS (
    SELECT 
        calendar_year,
        SUM(sales) AS total_sales_after
    FROM cleaned_weekly_sales
    WHERE 
        calendar_year IN (2018, 2019, 2020)
        AND week_date_formatted >= (CAST(calendar_year AS TEXT) || '-6-15')
        AND week_date_formatted < (CAST(calendar_year AS TEXT) || '-7-13')
    GROUP BY calendar_year
)
SELECT 
    b.calendar_year,
    ROUND(
        (CAST(a.total_sales_after AS REAL) - b.total_sales_before) / b.total_sales_before * 100, 
        4
    ) AS percentage_change
FROM before_june15 b
JOIN after_june15 a ON b.calendar_year = a.calendar_year
ORDER BY b.calendar_year