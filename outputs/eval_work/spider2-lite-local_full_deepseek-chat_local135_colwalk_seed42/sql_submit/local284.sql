-- Compute average and standard deviation of loss rates, then count items in each category
WITH stats AS (
  SELECT 
    AVG(loss_rate_%) AS avg_loss,
    STDEV(loss_rate_%) AS std_loss
  FROM veg_loss_rate_df
),
categories AS (
  SELECT 
    CASE 
      WHEN loss_rate_% < (SELECT avg_loss - std_loss FROM stats) THEN 'below'
      WHEN loss_rate_% > (SELECT avg_loss + std_loss FROM stats) THEN 'above'
      ELSE 'within'
    END AS category
  FROM veg_loss_rate_df
)
SELECT 
  (SELECT avg_loss FROM stats) AS average_loss_rate,
  SUM(CASE WHEN category = 'below' THEN 1 ELSE 0 END) AS below_1std,
  SUM(CASE WHEN category = 'above' THEN 1 ELSE 0 END) AS above_1std,
  SUM(CASE WHEN category = 'within' THEN 1 ELSE 0 END) AS within_1std
FROM categories