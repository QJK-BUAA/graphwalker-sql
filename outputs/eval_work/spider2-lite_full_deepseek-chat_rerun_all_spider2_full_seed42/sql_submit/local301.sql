WITH weeks_before AS (
    SELECT 
        calendar_year,
        SUM(sales) AS sales_before
    FROM cleaned_weekly_sales
    WHERE 
        calendar_year IN (2018, 2019, 2020)
        AND week_date_formatted >= date(printf('%d-06-15', calendar_year), '-28 days')
        AND week_date_formatted < date(printf('%d-06-15', calendar_year))
    GROUP BY calendar_year
),
weeks_after AS (
    SELECT 
        calendar_year,
        SUM(sales) AS sales_after
    FROM cleaned_weekly_sales
    WHERE 
        calendar_year IN (2018, 2019, 2020)
        AND week_date_formatted > date(printf('%d-06-15', calendar_year))
        AND week_date_formatted <= date(printf('%d-06-15', calendar_year), '+28 days')
    GROUP BY calendar_year
)
SELECT 
    b.calendar_year,
    ROUND(
        (CAST(a.sales_after AS REAL) - b.sales_before) / b.sales_before * 100, 
        4
    ) AS percentage_change
FROM weeks_before b
JOIN weeks_after a ON b.calendar_year = a.calendar_year
ORDER BY b.calendar_year