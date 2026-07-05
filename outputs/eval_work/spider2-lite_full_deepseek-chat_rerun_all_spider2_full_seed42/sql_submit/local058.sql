WITH 
sales_2020 AS (
    SELECT 
        dp.segment,
        COUNT(DISTINCT dp.product_code) AS unique_products_2020
    FROM hardware_dim_product dp
    INNER JOIN hardware_fact_sales_monthly s ON dp.product_code = s.product_code
    WHERE s.fiscal_year = 2020
    GROUP BY dp.segment
),
sales_2021 AS (
    SELECT 
        dp.segment,
        COUNT(DISTINCT dp.product_code) AS unique_products_2021
    FROM hardware_dim_product dp
    INNER JOIN hardware_fact_sales_monthly s ON dp.product_code = s.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY dp.segment
)
SELECT 
    COALESCE(s20.segment, s21.segment) AS segment,
    COALESCE(s20.unique_products_2020, 0) AS unique_products_2020,
    COALESCE(s21.unique_products_2021, 0) AS unique_products_2021,
    CASE 
        WHEN COALESCE(s20.unique_products_2020, 0) = 0 THEN NULL
        ELSE ROUND((CAST(COALESCE(s21.unique_products_2021, 0) AS REAL) - COALESCE(s20.unique_products_2020, 0)) / CAST(COALESCE(s20.unique_products_2020, 0) AS REAL) * 100, 4)
    END AS percentage_increase
FROM sales_2020 s20
FULL OUTER JOIN sales_2021 s21 ON s20.segment = s21.segment
ORDER BY percentage_increase DESC