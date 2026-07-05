WITH 
-- First, parse volume: convert K/M suffixes to numeric, treat '-' as 0
volume_parsed AS (
  SELECT 
    ticker,
    market_date,
    CASE 
      WHEN volume = '-' THEN 0.0
      WHEN volume LIKE '%K' THEN CAST(REPLACE(volume, 'K', '') AS REAL) * 1000
      WHEN volume LIKE '%M' THEN CAST(REPLACE(volume, 'M', '') AS REAL) * 1000000
      ELSE CAST(volume AS REAL)
    END AS volume_numeric
  FROM bitcoin_prices
  WHERE market_date >= '2021-08-01' AND market_date <= '2021-08-10'
),
-- Filter to only non-zero volumes for previous day calculation
valid_volumes AS (
  SELECT 
    ticker,
    market_date,
    volume_numeric
  FROM volume_parsed
  WHERE volume_numeric > 0
),
-- Get previous day's volume using LAG
volume_with_prev AS (
  SELECT 
    ticker,
    market_date,
    volume_numeric,
    LAG(volume_numeric) OVER (PARTITION BY ticker ORDER BY market_date) AS prev_volume
  FROM valid_volumes
)
-- Calculate daily percentage change
SELECT 
  ticker,
  market_date,
  ROUND(
    CASE 
      WHEN prev_volume IS NOT NULL AND prev_volume > 0 
      THEN ((volume_numeric - prev_volume) / prev_volume) * 100.0
      ELSE NULL 
    END, 
    4
  ) AS daily_volume_change_pct
FROM volume_with_prev
WHERE prev_volume IS NOT NULL
ORDER BY ticker, market_date