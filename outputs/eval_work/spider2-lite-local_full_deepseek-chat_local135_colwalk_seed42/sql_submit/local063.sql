WITH 
-- Filter sales to only those with promo_id=999 and in the United States
filtered_sales AS (
    SELECT s.*
    FROM sales s
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN countries co ON c.country_id = co.country_id
    WHERE s.promo_id = 999
      AND co.country_name = 'United States'
),

-- Get city-level sales for Q4 2019 and Q4 2020
city_sales AS (
    SELECT 
        c.cust_city,
        SUM(CASE WHEN t.calendar_quarter_id = 1772 THEN s.amount_sold ELSE 0 END) AS sales_q4_2019,
        SUM(CASE WHEN t.calendar_quarter_id = 1776 THEN s.amount_sold ELSE 0 END) AS sales_q4_2020
    FROM filtered_sales s
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN times t ON s.time_id = t.time_id
    WHERE t.calendar_quarter_id IN (1772, 1776)
    GROUP BY c.cust_city
),

-- Cities with at least 20% increase
qualified_cities AS (
    SELECT cust_city
    FROM city_sales
    WHERE sales_q4_2019 > 0
      AND (sales_q4_2020 - sales_q4_2019) / CAST(sales_q4_2019 AS REAL) >= 0.20
),

-- Product-level sales in qualified cities for both quarters
product_quarter_sales AS (
    SELECT 
        p.prod_id,
        p.prod_name,
        SUM(CASE WHEN t.calendar_quarter_id = 1772 THEN s.amount_sold ELSE 0 END) AS prod_sales_q4_2019,
        SUM(CASE WHEN t.calendar_quarter_id = 1776 THEN s.amount_sold ELSE 0 END) AS prod_sales_q4_2020
    FROM filtered_sales s
    JOIN products p ON s.prod_id = p.prod_id
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN times t ON s.time_id = t.time_id
    WHERE c.cust_city IN (SELECT cust_city FROM qualified_cities)
      AND t.calendar_quarter_id IN (1772, 1776)
    GROUP BY p.prod_id, p.prod_name
),

-- Total sales in qualified cities for each quarter
total_quarter_sales AS (
    SELECT 
        SUM(CASE WHEN t.calendar_quarter_id = 1772 THEN s.amount_sold ELSE 0 END) AS total_q4_2019,
        SUM(CASE WHEN t.calendar_quarter_id = 1776 THEN s.amount_sold ELSE 0 END) AS total_q4_2020
    FROM filtered_sales s
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN times t ON s.time_id = t.time_id
    WHERE c.cust_city IN (SELECT cust_city FROM qualified_cities)
      AND t.calendar_quarter_id IN (1772, 1776)
),

-- Product shares and percentage-point change
product_shares AS (
    SELECT 
        pqs.prod_id,
        pqs.prod_name,
        pqs.prod_sales_q4_2019,
        pqs.prod_sales_q4_2020,
        CASE WHEN tqs.total_q4_2019 > 0 
             THEN pqs.prod_sales_q4_2019 / CAST(tqs.total_q4_2019 AS REAL) 
             ELSE 0 END AS share_q4_2019,
        CASE WHEN tqs.total_q4_2020 > 0 
             THEN pqs.prod_sales_q4_2020 / CAST(tqs.total_q4_2020 AS REAL) 
             ELSE 0 END AS share_q4_2020,
        (CASE WHEN tqs.total_q4_2020 > 0 
              THEN pqs.prod_sales_q4_2020 / CAST(tqs.total_q4_2020 AS REAL) 
              ELSE 0 END -
         CASE WHEN tqs.total_q4_2019 > 0 
              THEN pqs.prod_sales_q4_2019 / CAST(tqs.total_q4_2019 AS REAL) 
              ELSE 0 END) AS share_change_pp
    FROM product_quarter_sales pqs
    CROSS JOIN total_quarter_sales tqs
),

-- Rank products by total sales across both quarters
product_ranking AS (
    SELECT 
        prod_id,
        prod_name,
        share_change_pp,
        prod_sales_q4_2019 + prod_sales_q4_2020 AS total_sales,
        NTILE(5) OVER (ORDER BY (prod_sales_q4_2019 + prod_sales_q4_2020) DESC) AS sales_quintile
    FROM product_shares
)

-- Select the product in top 20% (quintile 1) with smallest absolute percentage-point change
SELECT prod_name
FROM product_ranking
WHERE sales_quintile = 1
ORDER BY ABS(share_change_pp) ASC
LIMIT 1