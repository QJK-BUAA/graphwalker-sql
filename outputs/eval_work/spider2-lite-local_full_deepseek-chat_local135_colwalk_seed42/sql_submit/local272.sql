-- For order 423, we need to pick quantities from inventory locations in warehouse 1
-- respecting order line sequence and cumulative quantities, prioritizing earlier purchases and smaller quantities

WITH order_lines AS (
    -- Get order lines for order 423 with sequence
    SELECT 
        ol.id,
        ol.product_id,
        ol.qty,
        ol.amount,
        ROW_NUMBER() OVER (ORDER BY ol.id) as line_seq
    FROM orderlines ol
    WHERE ol.order_id = 423
),
cumulative_order AS (
    -- Calculate cumulative quantities needed per product across order lines
    SELECT 
        product_id,
        qty,
        line_seq,
        SUM(qty) OVER (PARTITION BY product_id ORDER BY line_seq) as cum_qty
    FROM order_lines
),
inventory_available AS (
    -- Get available inventory in warehouse 1 with purchase info for prioritization
    SELECT 
        i.id as inv_id,
        i.product_id,
        i.qty,
        i.location_id,
        l.aisle,
        l.position,
        p.ordered as purchase_date,
        ROW_NUMBER() OVER (PARTITION BY i.product_id ORDER BY p.ordered ASC, i.qty ASC) as inv_priority
    FROM inventory i
    JOIN locations l ON i.location_id = l.id
    JOIN purchases p ON i.purchase_id = p.id
    WHERE l.warehouse = 1
    AND i.qty > 0
),
picking_plan AS (
    -- For each product, allocate inventory to meet cumulative order quantities
    SELECT 
        co.product_id,
        co.line_seq,
        co.cum_qty,
        ia.inv_id,
        ia.location_id,
        ia.aisle,
        ia.position,
        ia.qty as inv_qty,
        ia.purchase_date,
        ia.inv_priority,
        -- Running total of inventory allocated per product
        SUM(ia.qty) OVER (PARTITION BY ia.product_id ORDER BY ia.inv_priority) as running_inv
    FROM cumulative_order co
    JOIN inventory_available ia ON co.product_id = ia.product_id
    WHERE ia.inv_priority <= (
        -- Find how many inventory entries we need to cover the max cumulative qty
        SELECT MIN(inv_priority) 
        FROM inventory_available ia2 
        WHERE ia2.product_id = co.product_id
        AND (
            SELECT SUM(ia3.qty) 
            FROM inventory_available ia3 
            WHERE ia3.product_id = ia2.product_id 
            AND ia3.inv_priority <= ia2.inv_priority
        ) >= (SELECT MAX(cum_qty) FROM cumulative_order co2 WHERE co2.product_id = ia2.product_id)
    )
),
final_pick AS (
    -- Calculate exact quantities to pick from each location for each order line
    SELECT 
        pp.product_id,
        pp.aisle,
        pp.position,
        pp.line_seq,
        pp.cum_qty,
        pp.inv_qty,
        pp.running_inv,
        -- Determine how much to take from this inventory for this order line
        CASE 
            WHEN pp.running_inv - pp.inv_qty < pp.cum_qty - pp.inv_qty 
            THEN LEAST(pp.inv_qty, pp.cum_qty - GREATEST(0, pp.running_inv - pp.inv_qty))
            ELSE 0
        END as pick_qty
    FROM picking_plan pp
)
SELECT 
    product_id,
    aisle,
    position,
    SUM(pick_qty) as quantity_to_pick
FROM final_pick
WHERE pick_qty > 0
GROUP BY product_id, aisle, position
ORDER BY product_id, aisle, position