-- Step 1: Count unique products per segment for 2020
-- Step 2: Count unique products per segment for 2021
-- Step 3: Compute percentage increase from 2020 to 2021
-- Step 4: Order by percentage increase descending

WITH 
counts_2020 AS (
    SELECT 
        hdp.segment,
        COUNT(DISTINCT hdp.product_code) AS unique_products_2020
    FROM hardware_dim_product hdp
    WHERE hdp.product_code LIKE '%2020%'
    GROUP BY hdp.segment
),
counts_2021 AS (
    SELECT 
        hdp.segment,
        COUNT(DISTINCT hdp.product_code) AS unique_products_2021
    FROM hardware_dim_product hdp
    WHERE hdp.product_code LIKE '%2021%'
    GROUP BY hdp.segment
)
SELECT 
    COALESCE(c20.segment, c21.segment) AS segment,
    COALESCE(c20.unique_products_2020, 0) AS unique_products_2020,
    COALESCE(c21.unique_products_2021, 0) AS unique_products_2021,
    CASE 
        WHEN COALESCE(c20.unique_products_2020, 0) = 0 THEN NULL
        ELSE ROUND((CAST(COALESCE(c21.unique_products_2021, 0) AS REAL) - COALESCE(c20.unique_products_2020, 0)) / CAST(COALESCE(c20.unique_products_2020, 0) AS REAL) * 100, 4)
    END AS percentage_increase
FROM counts_2020 c20
FULL OUTER JOIN counts_2021 c21 ON c20.segment = c21.segment
ORDER BY percentage_increase DESC