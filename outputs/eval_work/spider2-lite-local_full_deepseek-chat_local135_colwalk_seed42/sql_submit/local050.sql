WITH 
-- Monthly sales for 2019 and 2020, filtered by promo_total_id=1 and channel_total_id=1
monthly_sales AS (
    SELECT 
        t.calendar_month_number AS month_num,
        t.calendar_year AS year,
        SUM(s.amount_sold) AS total_sales
    FROM sales s
    JOIN times t ON s.time_id = t.time_id
    JOIN promotions p ON s.promo_id = p.promo_id
    JOIN channels ch ON s.channel_id = ch.channel_id
    WHERE t.calendar_year IN (2019, 2020)
      AND p.promo_total_id = 1
      AND ch.channel_total_id = 1
    GROUP BY t.calendar_year, t.calendar_month_number
),
-- Growth rate per month from 2019 to 2020
growth_rates AS (
    SELECT 
        a.month_num,
        CASE 
            WHEN a.total_sales > 0 THEN (b.total_sales - a.total_sales) / a.total_sales
            ELSE 0 
        END AS growth_rate
    FROM monthly_sales a
    JOIN monthly_sales b ON a.month_num = b.month_num
    WHERE a.year = 2019 AND b.year = 2020
),
-- Projected 2021 monthly sales in original currency
projected_sales_2021 AS (
    SELECT 
        g.month_num,
        m.total_sales * (1 + g.growth_rate) AS projected_sales
    FROM growth_rates g
    JOIN monthly_sales m ON g.month_num = m.month_num AND m.year = 2020
),
-- Convert to USD using currency table for France (average rate for 2021)
usd_conversion AS (
    SELECT 
        p.month_num,
        p.projected_sales * c.to_us AS projected_sales_usd
    FROM projected_sales_2021 p
    CROSS JOIN (
        SELECT AVG(to_us) AS to_us
        FROM currency
        WHERE country = 'France' AND year = 2021
    ) c
),
-- Average monthly projected sales in USD
avg_monthly_sales AS (
    SELECT 
        month_num,
        AVG(projected_sales_usd) AS avg_sales_usd
    FROM usd_conversion
    GROUP BY month_num
)
-- Median of the average monthly projected sales
SELECT 
    AVG(avg_sales_usd) AS median_avg_monthly_sales_usd
FROM (
    SELECT 
        avg_sales_usd,
        ROW_NUMBER() OVER (ORDER BY avg_sales_usd) AS row_num,
        COUNT(*) OVER () AS total_count
    FROM avg_monthly_sales
) ranked
WHERE row_num IN ((total_count + 1) / 2, (total_count + 2) / 2)