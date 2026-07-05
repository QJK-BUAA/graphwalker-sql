WITH 
inventory_fifo AS (
    SELECT 
        i.id,
        i.product_id,
        i.location_id,
        i.qty AS inv_qty,
        ROW_NUMBER() OVER (
            PARTITION BY i.product_id 
            ORDER BY i.purchase_id ASC, i.qty ASC
        ) AS fifo_rank
    FROM inventory i
),
order_requirements AS (
    SELECT 
        ol.order_id,
        ol.product_id,
        ol.qty AS req_qty,
        SUM(ol.qty) OVER (
            PARTITION BY ol.order_id, ol.product_id 
            ORDER BY ol.id
        ) AS cum_req_qty
    FROM orderlines ol
),
picking AS (
    SELECT 
        pl.order_id,
        pl.product_id,
        pl.qty AS picked_qty
    FROM picking_line pl
),
order_picked AS (
    SELECT 
        order_id,
        product_id,
        SUM(picked_qty) AS total_picked
    FROM picking
    GROUP BY order_id, product_id
),
order_required AS (
    SELECT 
        order_id,
        product_id,
        SUM(req_qty) AS total_required
    FROM order_requirements
    GROUP BY order_id, product_id
),
order_pick_pct AS (
    SELECT 
        op.order_id,
        op.product_id,
        CASE 
            WHEN op.total_required > 0 
            THEN CAST(MIN(opk.total_picked, op.total_required) AS REAL) / op.total_required
            ELSE 0
        END AS pick_pct
    FROM order_required op
    JOIN order_picked opk ON op.order_id = opk.order_id AND op.product_id = opk.product_id
)
SELECT 
    p.name AS product_name,
    AVG(opp.pick_pct) AS avg_pick_percentage
FROM order_pick_pct opp
JOIN products p ON opp.product_id = p.id
GROUP BY p.name
ORDER BY p.name