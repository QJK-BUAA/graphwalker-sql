-- For order 421, we need to find products picked and their average units using FIFO.
-- FIFO means we consider the earliest orders first. Since we only have one order (421), 
-- we just compute the average qty per product for that order.
SELECT 
    p.name AS product_name,
    AVG(pl.qty) AS avg_units_picked
FROM picking_line pl
JOIN products p ON pl.product_id = p.id
JOIN orders o ON pl.order_id = o.id
WHERE pl.order_id = 421
GROUP BY p.id, p.name
ORDER BY MIN(o.ordered) ASC;  -- FIFO: order by earliest order date