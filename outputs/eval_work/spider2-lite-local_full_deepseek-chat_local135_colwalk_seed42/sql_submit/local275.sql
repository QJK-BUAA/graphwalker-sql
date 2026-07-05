-- Compute centered moving average (12-month CMA) for each product and month
-- Then compute seasonality-adjusted ratio = qty / CMA
-- Filter for months in 2017 where ratio > 2
-- Return products where ALL months in 2017 have ratio > 2
WITH monthly_with_cma AS (
    SELECT 
        ms.product_id,
        ms.mth,
        ms.qty,
        AVG(ms.qty) OVER (
            PARTITION BY ms.product_id 
            ORDER BY ms.mth 
            ROWS BETWEEN 5 PRECEDING AND 6 FOLLOWING
        ) AS cma
    FROM monthly_sales ms
    WHERE ms.mth >= '2016-01-01'
),
ratio_2017 AS (
    SELECT 
        product_id,
        mth,
        CAST(qty AS REAL) / cma AS seasonality_adjusted_ratio
    FROM monthly_with_cma
    WHERE mth >= '2017-01-01' AND mth < '2018-01-01'
      AND cma IS NOT NULL AND cma > 0
),
products_all_above_2 AS (
    SELECT product_id
    FROM ratio_2017
    GROUP BY product_id
    HAVING MIN(seasonality_adjusted_ratio) > 2
       AND COUNT(*) = 12  -- all 12 months present
)
SELECT p.name
FROM products p
JOIN products_all_above_2 pa ON p.id = pa.product_id
ORDER BY p.name