WITH daily_sales AS (
    SELECT 
        DATE(o.order_purchase_timestamp) AS sale_date,
        SUM(oi.price) AS total_sales
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE p.product_category_name = 'toys'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-08-30'
    GROUP BY DATE(o.order_purchase_timestamp)
),
regression_data AS (
    SELECT 
        sale_date,
        total_sales,
        julianday(sale_date) - julianday('2017-01-01') AS day_num
    FROM daily_sales
),
regression_params AS (
    SELECT 
        (COUNT(*) * SUM(day_num * total_sales) - SUM(day_num) * SUM(total_sales)) / 
        (COUNT(*) * SUM(day_num * day_num) - SUM(day_num) * SUM(day_num)) AS slope,
        (SUM(total_sales) - ((COUNT(*) * SUM(day_num * total_sales) - SUM(day_num) * SUM(total_sales)) / 
        (COUNT(*) * SUM(day_num * day_num) - SUM(day_num) * SUM(day_num))) * SUM(day_num)) / COUNT(*) AS intercept
    FROM regression_data
),
predicted_sales AS (
    SELECT 
        day_num,
        intercept + slope * day_num AS predicted_sales
    FROM regression_params,
    (SELECT 704 AS day_num UNION ALL SELECT 705 UNION ALL SELECT 706 UNION ALL SELECT 707) AS days
),
moving_averages AS (
    SELECT 
        p1.day_num,
        (p1.predicted_sales + 
         COALESCE((SELECT p2.predicted_sales FROM predicted_sales p2 WHERE p2.day_num = p1.day_num - 1), 0) +
         COALESCE((SELECT p2.predicted_sales FROM predicted_sales p2 WHERE p2.day_num = p1.day_num - 2), 0) +
         COALESCE((SELECT p2.predicted_sales FROM predicted_sales p2 WHERE p2.day_num = p1.day_num + 1), 0) +
         COALESCE((SELECT p2.predicted_sales FROM predicted_sales p2 WHERE p2.day_num = p1.day_num + 2), 0)) / 5.0 AS ma
    FROM predicted_sales p1
)
SELECT SUM(ma) AS sum_of_moving_averages
FROM moving_averages