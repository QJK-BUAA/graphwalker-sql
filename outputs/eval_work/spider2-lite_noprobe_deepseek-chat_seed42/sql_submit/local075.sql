SELECT 
    h.page_name AS product,
    SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS page_views,
    SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_adds,
    SUM(CASE WHEN e.event_type = 2 AND NOT EXISTS (
        SELECT 1 FROM shopping_cart_events e2 
        WHERE e2.cookie_id = e.cookie_id 
        AND e2.event_type = 3 
        AND e2.event_time > e.event_time
    ) THEN 1 ELSE 0 END) AS abandoned_in_cart,
    SUM(CASE WHEN e.event_type = 3 THEN 1 ELSE 0 END) AS purchases
FROM shopping_cart_page_hierarchy h
JOIN shopping_cart_events e ON h.page_id = e.page_id
JOIN shopping_cart_event_identifier ei ON e.event_type = ei.event_type
WHERE h.page_id NOT IN (1, 2, 12, 13)
GROUP BY h.page_id, h.page_name
ORDER BY h.page_name