-- Breakdown of product interactions: views, adds to cart, left in cart (not purchased), and purchases
-- Filtering out products with page_id in (1, 2, 12, 13)

WITH product_views AS (
    SELECT 
        ph.page_id,
        ph.page_name,
        COUNT(*) AS view_count
    FROM shopping_cart_events e
    JOIN shopping_cart_page_hierarchy ph ON e.page_id = ph.page_id
    WHERE e.event_type = 1  -- event_type 1 = page view (based on event_identifier mapping)
      AND ph.page_id NOT IN (1, 2, 12, 13)
    GROUP BY ph.page_id, ph.page_name
),
product_add_to_cart AS (
    SELECT 
        ph.page_id,
        ph.page_name,
        COUNT(*) AS add_to_cart_count
    FROM shopping_cart_events e
    JOIN shopping_cart_page_hierarchy ph ON e.page_id = ph.page_id
    WHERE e.event_type = 2  -- event_type 2 = add to cart (based on event_identifier mapping)
      AND ph.page_id NOT IN (1, 2, 12, 13)
    GROUP BY ph.page_id, ph.page_name
),
product_purchases AS (
    SELECT 
        ph.page_id,
        ph.page_name,
        COUNT(*) AS purchase_count
    FROM shopping_cart_events e
    JOIN shopping_cart_page_hierarchy ph ON e.page_id = ph.page_id
    WHERE e.event_type = 3  -- event_type 3 = purchase (based on event_identifier mapping)
      AND ph.page_id NOT IN (1, 2, 12, 13)
    GROUP BY ph.page_id, ph.page_name
)
SELECT 
    COALESCE(v.page_id, a.page_id, p.page_id) AS page_id,
    COALESCE(v.page_name, a.page_name, p.page_name) AS product_name,
    COALESCE(v.view_count, 0) AS views,
    COALESCE(a.add_to_cart_count, 0) AS added_to_cart,
    COALESCE(a.add_to_cart_count, 0) - COALESCE(p.purchase_count, 0) AS left_in_cart,
    COALESCE(p.purchase_count, 0) AS purchases
FROM product_views v
FULL OUTER JOIN product_add_to_cart a ON v.page_id = a.page_id
FULL OUTER JOIN product_purchases p ON COALESCE(v.page_id, a.page_id) = p.page_id
ORDER BY page_id