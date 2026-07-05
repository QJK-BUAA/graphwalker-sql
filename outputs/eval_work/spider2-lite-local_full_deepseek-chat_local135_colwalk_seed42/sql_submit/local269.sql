WITH RECURSIVE expand(packaging_id, contains_id, qty, path) AS (
    -- Base: direct leaf items (items that are not themselves packaging)
    SELECT 
        pr.packaging_id,
        pr.contains_id,
        pr.qty,
        CAST(pr.contains_id AS TEXT) AS path
    FROM packaging_relations pr
    WHERE pr.contains_id NOT IN (SELECT DISTINCT packaging_id FROM packaging_relations)
    
    UNION ALL
    
    -- Recursive: expand nested packaging
    SELECT 
        e.packaging_id,
        pr.contains_id,
        e.qty * pr.qty,
        e.path || ',' || CAST(pr.contains_id AS TEXT)
    FROM expand e
    JOIN packaging_relations pr ON e.contains_id = pr.packaging_id
    WHERE pr.contains_id NOT IN (SELECT DISTINCT packaging_id FROM packaging_relations)
),
leaf_combinations AS (
    -- For each top-level packaging, sum quantities of leaf items
    SELECT 
        e.packaging_id,
        SUM(e.qty) AS total_qty
    FROM expand e
    GROUP BY e.packaging_id
)
SELECT AVG(total_qty) AS avg_total_quantity
FROM leaf_combinations