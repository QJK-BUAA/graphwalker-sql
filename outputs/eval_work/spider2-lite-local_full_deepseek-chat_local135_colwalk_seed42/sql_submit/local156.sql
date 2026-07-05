WITH 
-- First, compute total spent and total quantity per region per year for purchase transactions
region_year_data AS (
    SELECT 
        cr.region_name,
        strftime('%Y', bt.txn_date) AS year,
        SUM(bt.quantity * bt.percentage_fee) AS total_spent,
        SUM(bt.quantity) AS total_quantity
    FROM bitcoin_transactions bt
    JOIN customer_regions cr ON bt.member_id = cr.region_id
    WHERE bt.txn_type = 'purchase'
    GROUP BY cr.region_name, strftime('%Y', bt.txn_date)
),
-- Find the first year for each region
first_year_per_region AS (
    SELECT 
        region_name,
        MIN(year) AS first_year
    FROM region_year_data
    GROUP BY region_name
),
-- Exclude first year data
filtered_data AS (
    SELECT 
        ryd.region_name,
        ryd.year,
        ryd.total_spent,
        ryd.total_quantity
    FROM region_year_data ryd
    JOIN first_year_per_region fyr ON ryd.region_name = fyr.region_name
    WHERE ryd.year > fyr.first_year
),
-- Calculate average purchase price per Bitcoin
avg_price_data AS (
    SELECT 
        region_name,
        year,
        CAST(total_spent AS REAL) / total_quantity AS avg_purchase_price
    FROM filtered_data
    WHERE total_quantity > 0
),
-- Rank regions by average purchase price per year
ranked_data AS (
    SELECT 
        region_name,
        year,
        avg_purchase_price,
        RANK() OVER (PARTITION BY year ORDER BY avg_purchase_price DESC) AS price_rank
    FROM avg_price_data
),
-- Calculate previous year's average price for each region
prev_year_data AS (
    SELECT 
        region_name,
        year,
        avg_purchase_price,
        LAG(avg_purchase_price) OVER (PARTITION BY region_name ORDER BY year) AS prev_avg_price
    FROM avg_price_data
)
-- Final output: rank and percentage change
SELECT 
    rd.region_name,
    rd.year,
    rd.avg_purchase_price,
    rd.price_rank,
    CASE 
        WHEN pyd.prev_avg_price IS NOT NULL AND pyd.prev_avg_price > 0 
        THEN ROUND(((rd.avg_purchase_price - pyd.prev_avg_price) / pyd.prev_avg_price) * 100, 4)
        ELSE NULL 
    END AS annual_pct_change
FROM ranked_data rd
JOIN prev_year_data pyd ON rd.region_name = pyd.region_name AND rd.year = pyd.year
ORDER BY rd.year, rd.price_rank