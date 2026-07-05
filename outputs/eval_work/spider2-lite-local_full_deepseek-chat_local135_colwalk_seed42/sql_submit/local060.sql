WITH 
city_sales AS (
    SELECT 
        c.cust_city,
        t.calendar_year,
        SUM(s.amount_sold) AS total_sales
    FROM sales s
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN countries co ON c.country_id = co.country_id
    JOIN times t ON s.time_id = t.time_id
    WHERE co.country_name = 'United States'
        AND t.calendar_quarter_number = 4
        AND t.calendar_year IN (2019, 2020)
        AND s.promo_id = 0
    GROUP BY c.cust_city, t.calendar_year
),
city_sales_pivot AS (
    SELECT 
        cust_city,
        SUM(CASE WHEN calendar_year = 2019 THEN total_sales ELSE 0 END) AS sales_2019,
        SUM(CASE WHEN calendar_year = 2020 THEN total_sales ELSE 0 END) AS sales_2020
    FROM city_sales
    GROUP BY cust_city
),
qualified_cities AS (
    SELECT cust_city
    FROM city_sales_pivot
    WHERE sales_2019 > 0
        AND (sales_2020 - sales_2019) / CAST(sales_2019 AS REAL) >= 0.20
),
product_sales AS (
    SELECT 
        p.prod_id,
        p.prod_name,
        SUM(s.amount_sold) AS total_sales
    FROM sales s
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN countries co ON c.country_id = co.country_id
    JOIN times t ON s.time_id = t.time_id
    JOIN products p ON s.prod_id = p.prod_id
    WHERE co.country_name = 'United States'
        AND t.calendar_quarter_number = 4
        AND t.calendar_year IN (2019, 2020)
        AND s.promo_id = 0
        AND c.cust_city IN (SELECT cust_city FROM qualified_cities)
    GROUP BY p.prod_id, p.prod_name
),
ranked_products AS (
    SELECT 
        prod_id,
        prod_name,
        total_sales,
        ROW_NUMBER() OVER (ORDER BY total_sales DESC) AS rn,
        COUNT(*) OVER () AS total_products
    FROM product_sales
),
top_products AS (
    SELECT prod_id, prod_name
    FROM ranked_products
    WHERE rn <= CAST(CEIL(total_products * 0.20) AS INTEGER)
),
product_year_sales AS (
    SELECT 
        p.prod_id,
        p.prod_name,
        t.calendar_year,
        SUM(s.amount_sold) AS prod_sales,
        SUM(SUM(s.amount_sold)) OVER (PARTITION BY t.calendar_year) AS total_year_sales
    FROM sales s
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN countries co ON c.country_id = co.country_id
    JOIN times t ON s.time_id = t.time_id
    JOIN products p ON s.prod_id = p.prod_id
    WHERE co.country_name = 'United States'
        AND t.calendar_quarter_number = 4
        AND t.calendar_year IN (2019, 2020)
        AND s.promo_id = 0
        AND c.cust_city IN (SELECT cust_city FROM qualified_cities)
        AND p.prod_id IN (SELECT prod_id FROM top_products)
    GROUP BY p.prod_id, p.prod_name, t.calendar_year
),
shares AS (
    SELECT 
        prod_id,
        prod_name,
        MAX(CASE WHEN calendar_year = 2019 THEN prod_sales / CAST(total_year_sales AS REAL) ELSE 0 END) AS share_2019,
        MAX(CASE WHEN calendar_year = 2020 THEN prod_sales / CAST(total_year_sales AS REAL) ELSE 0 END) AS share_2020
    FROM product_year_sales
    GROUP BY prod_id, prod_name
)
SELECT 
    prod_name,
    share_2019,
    share_2020,
    share_2020 - share_2019 AS share_change
FROM shares
ORDER BY share_change DESC