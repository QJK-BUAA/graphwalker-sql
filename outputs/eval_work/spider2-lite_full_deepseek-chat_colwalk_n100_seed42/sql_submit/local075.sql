SELECT 
    ph.page_name AS product,
    SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS page_views,
    SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS added_to_cart,
    SUM(CASE WHEN e.event_type = 3 THEN 1 ELSE 0 END) AS left_in_cart,
    SUM(CASE WHEN e.event_type = 4 THEN 1 ELSE 0 END) AS purchases
FROM shopping_cart_events e
JOIN shopping_cart_page_hierarchy ph ON e.page_id = ph.page_id
JOIN shopping_cart_event_identifier ei ON e.event_type = ei.event_type
WHERE ph.page_id NOT IN (1, 2, 12, 13)
GROUP BY ph.page_name
ORDER BY ph.page_name