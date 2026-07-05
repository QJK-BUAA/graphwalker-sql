-- We need to compute unique product counts per segment for 2020 and 2021,
-- then calculate percentage increase from 2020 to 2021, and order by that increase descending.
-- Since only hardware_dim_product is provided, we assume product_code is the key.
-- The question asks for segments and their unique product counts for 2020,
-- but also requires ordering by percentage increase from 2020 to 2021.
-- This implies we need data from both years, but the output only shows 2020 counts.
-- We'll compute counts per segment for each year, then join and compute increase.

WITH counts_2020 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT p.product_code) AS product_count_2020
    FROM hardware_dim_product p
    WHERE p.product_code LIKE '%2020%'  -- filter for 2020 products
    GROUP BY p.segment
),
counts_2021 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT p.product_code) AS product_count_2021
    FROM hardware_dim_product p
    WHERE p.product_code LIKE '%2021%'  -- filter for 2021 products
    GROUP BY p.segment
)
SELECT 
    c20.segment,
    c20.product_count_2020
FROM counts_2020 c20
LEFT JOIN counts_2021 c21 ON c20.segment = c21.segment
ORDER BY 
    (COALESCE(c21.product_count_2021, 0) - c20.product_count_2020) * 1.0 / NULLIF(c20.product_count_2020, 0) DESC