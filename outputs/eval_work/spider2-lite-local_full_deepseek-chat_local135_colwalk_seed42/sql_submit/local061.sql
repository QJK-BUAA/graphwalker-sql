-- Step 1: Compute monthly sales per product for 2019 and 2020, filtered by promo_total_id=1 and channel_total_id=1
WITH sales_2019 AS (
    SELECT 
        s.prod_id,
        CAST(strftime('%m', s.time_id) AS INTEGER) AS month,
        SUM(s.amount_sold) AS total_sales
    FROM sales s
    JOIN promotions p ON s.promo_id = p.promo_id
    JOIN channels c ON s.channel_id = c.channel_id
    WHERE p.promo_total_id = 1
      AND c.channel_total_id = 1
      AND strftime('%Y', s.time_id) = '2019'
    GROUP BY s.prod_id, month
),
sales_2020 AS (
    SELECT 
        s.prod_id,
        CAST(strftime('%m', s.time_id) AS INTEGER) AS month,
        SUM(s.amount_sold) AS total_sales
    FROM sales s
    JOIN promotions p ON s.promo_id = p.promo_id
    JOIN channels c ON s.channel_id = c.channel_id
    WHERE p.promo_total_id = 1
      AND c.channel_total_id = 1
      AND strftime('%Y', s.time_id) = '2020'
    GROUP BY s.prod_id, month
),
-- Step 2: Calculate growth rate from 2019 to 2020 per product and month
growth_rates AS (
    SELECT 
        s19.prod_id,
        s19.month,
        CASE 
            WHEN s19.total_sales = 0 THEN NULL
            ELSE (s20.total_sales - s19.total_sales) / CAST(s19.total_sales AS REAL)
        END AS growth_rate
    FROM sales_2019 s19
    JOIN sales_2020 s20 ON s19.prod_id = s20.prod_id AND s19.month = s20.month
),
-- Step 3: Project 2021 monthly sales using growth rate
projected_2021 AS (
    SELECT 
        s20.prod_id,
        s20.month,
        s20.total_sales * (1 + COALESCE(g.growth_rate, 0)) AS projected_sales
    FROM sales_2020 s20
    LEFT JOIN growth_rates g ON s20.prod_id = g.prod_id AND s20.month = g.month
),
-- Step 4: Convert to USD using 2021 exchange rates for France
converted_sales AS (
    SELECT 
        p.month,
        p.projected_sales * c.to_us AS projected_usd
    FROM projected_2021 p
    CROSS JOIN currency c
    WHERE c.country = 'France'
      AND c.year = 2021
      AND c.month = p.month
)
-- Step 5: Average projected monthly sales and list by month
SELECT 
    month,
    AVG(projected_usd) AS avg_projected_monthly_sales_usd
FROM converted_sales
GROUP BY month
ORDER BY month