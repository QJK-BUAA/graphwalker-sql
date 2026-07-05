-- Step 1: Get monthly sales data for products 4160 and 7790 from Jan 2016 for 36 months
WITH monthly_data AS (
    SELECT 
        ms.product_id,
        ms.mth,
        ms.qty,
        -- Time step starting from Jan 2016 (month 1 = Jan 2016)
        (CAST(strftime('%Y', ms.mth) AS INTEGER) - 2016) * 12 + CAST(strftime('%m', ms.mth) AS INTEGER) AS time_step
    FROM monthly_sales ms
    WHERE ms.product_id IN (4160, 7790)
      AND ms.mth >= '2016-01-01'
      AND ms.mth < '2019-01-01'  -- First 36 months: Jan 2016 to Dec 2018
),

-- Step 2: Calculate seasonality factors using time steps 7 through 30
seasonality AS (
    SELECT 
        product_id,
        -- Seasonality factor = average qty for time steps 7-30
        AVG(CAST(qty AS REAL)) AS season_factor
    FROM monthly_data
    WHERE time_step BETWEEN 7 AND 30
    GROUP BY product_id
),

-- Step 3: Apply seasonality adjustments and prepare for weighted regression
adjusted_data AS (
    SELECT 
        md.product_id,
        md.time_step,
        md.qty,
        s.season_factor,
        -- Seasonally adjusted sales
        md.qty / s.season_factor AS adjusted_qty
    FROM monthly_data md
    JOIN seasonality s ON md.product_id = s.product_id
),

-- Step 4: Weighted regression to estimate sales for 2018
-- Using time steps 1-36, with weights decreasing for older data
-- Weight = 1/time_step (more recent data gets higher weight)
regression_params AS (
    SELECT 
        product_id,
        -- Calculate weighted regression coefficients
        -- y = a + b*x where y = adjusted_qty, x = time_step
        (SUM(w * x * y) - SUM(w * x) * SUM(w * y) / SUM(w)) / 
        (SUM(w * x * x) - SUM(w * x) * SUM(w * x) / SUM(w)) AS slope,
        (SUM(w * y) - (SUM(w * x * y) - SUM(w * x) * SUM(w * y) / SUM(w)) / 
        (SUM(w * x * x) - SUM(w * x) * SUM(w * x) / SUM(w)) * SUM(w * x)) / SUM(w) AS intercept
    FROM (
        SELECT 
            product_id,
            time_step,
            adjusted_qty,
            1.0 / time_step AS w,  -- Weight inversely proportional to time step
            time_step AS x,
            adjusted_qty AS y
        FROM adjusted_data
    )
    GROUP BY product_id
),

-- Step 5: Forecast 2018 monthly sales (time steps 25-36)
forecast_2018 AS (
    SELECT 
        rp.product_id,
        -- Forecast for each month in 2018 (time steps 25-36)
        SUM(rp.intercept + rp.slope * ts.time_step) * s.season_factor AS forecasted_sales
    FROM regression_params rp
    CROSS JOIN (
        SELECT 25 AS time_step UNION ALL SELECT 26 UNION ALL SELECT 27
        UNION ALL SELECT 28 UNION ALL SELECT 29 UNION ALL SELECT 30
        UNION ALL SELECT 31 UNION ALL SELECT 32 UNION ALL SELECT 33
        UNION ALL SELECT 34 UNION ALL SELECT 35 UNION ALL SELECT 36
    ) ts
    JOIN seasonality s ON rp.product_id = s.product_id
    GROUP BY rp.product_id, s.season_factor
)

-- Step 6: Calculate average forecasted annual sales for 2018
SELECT 
    AVG(forecasted_sales) AS avg_forecasted_annual_sales
FROM forecast_2018