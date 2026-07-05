-- Top-level packaging containers (not contained in any other packaging)
-- that have any item where total quantity across all nested levels > 500
WITH RECURSIVE hierarchy AS (
    -- Base: all packaging items
    SELECT 
        pr.packaging_id AS container_id,
        pr.contains_id AS item_id,
        pr.qty AS quantity,
        1 AS level
    FROM packaging_relations pr
    
    UNION ALL
    
    -- Recursive: nested items
    SELECT 
        h.container_id,
        pr.contains_id,
        h.quantity * pr.qty,
        h.level + 1
    FROM hierarchy h
    JOIN packaging_relations pr ON h.item_id = pr.packaging_id
)
-- Top-level containers: those not contained in any other packaging
, top_level AS (
    SELECT p.id, p.name
    FROM packaging p
    WHERE p.id NOT IN (SELECT DISTINCT contains_id FROM packaging_relations)
)
-- Aggregate total quantities per container and item
, item_totals AS (
    SELECT 
        h.container_id,
        h.item_id,
        SUM(h.quantity) AS total_qty
    FROM hierarchy h
    GROUP BY h.container_id, h.item_id
)
SELECT 
    tl.name AS container_name,
    p.name AS item_name
FROM top_level tl
JOIN item_totals it ON tl.id = it.container_id
JOIN packaging p ON it.item_id = p.id
WHERE it.total_qty > 500
ORDER BY tl.name, p.name