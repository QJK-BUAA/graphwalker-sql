-- Step 1: Filter orders and order_items for the date range and join with products for toy category
-- Step 2: Aggregate daily sales (sum of price) for each day in the training period
-- Step 3: Compute linear regression coefficients (slope and intercept) using daily sales data
-- Step 4: Predict sales for Dec 5-8, 2018 using the regression model
-- Step 5: Compute 5-day symmetric moving average for each of those 4 days
-- Step 6: Sum the four moving averages

WITH daily_sales AS (
    SELECT 
        DATE(o.order_purchase_timestamp) AS sale_date,
        SUM(oi.price) AS total_sales
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE p.product_category_name = 'toys'
      AND DATE(o.order_purchase_timestamp) >= '2017-01-01'
      AND DATE(o.order_purchase_timestamp) <= '2018-08-29'
    GROUP BY DATE(o.order_purchase_timestamp)
),
stats AS (
    SELECT 
        COUNT(*) AS n,
        SUM(CAST(julianday(sale_date) AS REAL)) AS sum_x,
        SUM(total_sales) AS sum_y,
        SUM(CAST(julianday(sale_date) AS REAL) * total_sales) AS sum_xy,
        SUM(CAST(julianday(sale_date) AS REAL) * CAST(julianday(sale_date) AS REAL)) AS sum_x2
    FROM daily_sales
),
regression AS (
    SELECT 
        (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x) AS slope,
        (sum_y - ((n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)) * sum_x) / n AS intercept
    FROM stats
),
predicted_sales AS (
    SELECT 
        target_date,
        intercept + slope * CAST(julianday(target_date) AS REAL) AS predicted_sale
    FROM regression,
    (VALUES 
        ('2018-12-05'),
        ('2018-12-06'),
        ('2018-12-07'),
        ('2018-12-08')
    ) AS dates(target_date)
),
moving_avg AS (
    SELECT 
        target_date,
        predicted_sale,
        AVG(predicted_sale) OVER (
            ORDER BY julianday(target_date)
            ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
        ) AS symmetric_ma
    FROM predicted_sales
)
SELECT SUM(symmetric_ma) AS sum_of_moving_averages
FROM moving_avg