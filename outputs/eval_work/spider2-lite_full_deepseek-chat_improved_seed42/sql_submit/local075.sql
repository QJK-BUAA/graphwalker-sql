SELECT 
    ph.page_name AS product,
    SUM(CASE WHEN ei.event_name = 'Page View' THEN 1 ELSE 0 END) AS view_count,
    SUM(CASE WHEN ei.event_name = 'Add to Cart' THEN 1 ELSE 0 END) AS add_to_cart_count,
    SUM(CASE WHEN ei.event_name = 'Add to Cart' AND NOT EXISTS (
        SELECT 1 FROM shopping_cart_events e2
        JOIN shopping_cart_event_identifier ei2 ON e2.event_type = ei2.event_type
        WHERE e2.visit_id = e.visit_id AND e2.cookie_id = e.cookie_id AND ei2.event_name = 'Purchase'
    ) THEN 1 ELSE 0 END) AS left_in_cart_count,
    SUM(CASE WHEN ei.event_name = 'Purchase' THEN 1 ELSE 0 END) AS purchase_count
FROM shopping_cart_events e
JOIN shopping_cart_page_hierarchy ph ON e.page_id = ph.page_id
JOIN shopping_cart_event_identifier ei ON e.event_type = ei.event_type
WHERE ph.page_id NOT IN (1, 2, 12, 13)
GROUP BY ph.page_name
ORDER BY ph.page_name