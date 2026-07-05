WITH yearly_counts AS (
    SELECT 
        p.segment,
        p.product_code,
        COUNT(DISTINCT p.product_code) AS dummy
    FROM hardware_dim_product p
    WHERE p.product_code IN ('2020', '2021')
    GROUP BY p.segment, p.product_code
),
segment_counts AS (
    SELECT 
        p.segment,
        SUM(CASE WHEN p.product_code = '2020' THEN 1 ELSE 0 END) as count_2020,
        SUM(CASE WHEN p.product_code = '2021' THEN 1 ELSE 0 END) as count_2021
    FROM hardware_dim_product p
    WHERE p.product_code IN ('2020', '2021')
    GROUP BY p.segment
)
SELECT 
    sc.segment,
    sc.count_2020 as unique_product_count_2020
FROM segment_counts sc
ORDER BY 
    (sc.count_2021 - sc.count_2020) * 1.0 / NULLIF(sc.count_2020, 0) DESC