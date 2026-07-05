WITH product_totals AS (
    SELECT 
        p.division,
        p.product_code,
        SUM(s.sold_quantity) AS total_quantity
    FROM hardware_dim_product p
    JOIN hardware_fact_sales_monthly s ON p.product_code = s.product_code
    WHERE s.date >= '2021-01-01' AND s.date < '2022-01-01'
    GROUP BY p.division, p.product_code
),
ranked_products AS (
    SELECT 
        division,
        product_code,
        total_quantity,
        ROW_NUMBER() OVER (PARTITION BY division ORDER BY total_quantity DESC) AS rn
    FROM product_totals
),
top3_per_division AS (
    SELECT division, product_code
    FROM ranked_products
    WHERE rn <= 3
)
SELECT 
    AVG(CAST(s.sold_quantity AS REAL)) AS overall_avg_quantity_sold
FROM hardware_fact_sales_monthly s
JOIN top3_per_division t ON s.product_code = t.product_code
WHERE s.date >= '2021-01-01' AND s.date < '2022-01-01'