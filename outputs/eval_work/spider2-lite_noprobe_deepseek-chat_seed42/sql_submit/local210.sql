SELECT h.hub_name
FROM hubs h
JOIN stores s ON h.hub_id = s.hub_id
JOIN orders o ON s.store_id = o.store_id
WHERE o.order_status = 'finished'
  AND o.order_moment_finished IS NOT NULL
  AND (
    (o.order_created_month = 2 AND o.order_created_year = 2017)
    OR (o.order_created_month = 3 AND o.order_created_year = 2017)
  )
GROUP BY h.hub_id, h.hub_name
HAVING 
  (SUM(CASE WHEN o.order_created_month = 3 THEN 1 ELSE 0 END) * 1.0 / 
   NULLIF(SUM(CASE WHEN o.order_created_month = 2 THEN 1 ELSE 0 END), 0) - 1) > 0.2