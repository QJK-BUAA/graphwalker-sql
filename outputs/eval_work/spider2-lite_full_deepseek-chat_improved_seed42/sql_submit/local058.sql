WITH 
-- Count unique products sold in 2020 per segment
sales_2020 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT s.product_code) AS unique_products_2020
    FROM hardware_dim_product p
    JOIN hardware_fact_sales_monthly s ON p.product_code = s.product_code
    WHERE s.fiscal_year = 2020
    GROUP BY p.segment
),
-- Count unique products sold in 2021 per segment
sales_2021 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT s.product_code) AS unique_products_2021
    FROM hardware_dim_product p
    JOIN hardware_fact_sales_monthly s ON p.product_code = s.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.segment
)
-- Combine and calculate percentage increase
SELECT 
    COALESCE(a.segment, b.segment) AS segment,
    COALESCE(a.unique_products_2020, 0) AS unique_products_2020,
    COALESCE(b.unique_products_2021, 0) AS unique_products_2021,
    CASE 
        WHEN COALESCE(a.unique_products_2020, 0) = 0 THEN NULL
        ELSE ROUND((CAST(COALESCE(b.unique_products_2021, 0) AS REAL) - COALESCE(a.unique_products_2020, 0)) / CAST(COALESCE(a.unique_products_2020, 0) AS REAL) * 100, 4)
    END AS percentage_increase
FROM sales_2020 a
FULL OUTER JOIN sales_2021 b ON a.segment = b.segment
ORDER BY percentage_increase DESC