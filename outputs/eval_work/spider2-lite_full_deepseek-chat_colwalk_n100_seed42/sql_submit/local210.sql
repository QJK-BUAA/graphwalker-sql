-- Identify hubs with >20% increase in finished orders from February to March
WITH feb_orders AS (
    SELECT 
        h.hub_id,
        h.hub_name,
        COUNT(o.order_id) AS feb_count
    FROM hubs h
    LEFT JOIN orders o ON h.hub_id = o.store_id
    WHERE o.order_moment_finished IS NOT NULL
      AND o.order_created_month = 2
    GROUP BY h.hub_id, h.hub_name
),
mar_orders AS (
    SELECT 
        h.hub_id,
        h.hub_name,
        COUNT(o.order_id) AS mar_count
    FROM hubs h
    LEFT JOIN orders o ON h.hub_id = o.store_id
    WHERE o.order_moment_finished IS NOT NULL
      AND o.order_created_month = 3
    GROUP BY h.hub_id, h.hub_name
)
SELECT 
    f.hub_id,
    f.hub_name,
    f.feb_count,
    m.mar_count,
    ROUND((CAST(m.mar_count AS REAL) - f.feb_count) / NULLIF(f.feb_count, 0) * 100, 4) AS pct_increase
FROM feb_orders f
JOIN mar_orders m ON f.hub_id = m.hub_id
WHERE f.feb_count > 0
  AND (CAST(m.mar_count AS REAL) - f.feb_count) / f.feb_count > 0.2
ORDER BY pct_increase DESC