-- We need to count overtakes (position improvements) and being overtaken (position drops) for each driver
-- Excluding: lap 1, pit stops (pit entry/exit), retirements
-- Overtake: driver gains positions (position decreases) from one lap to next
-- Being overtaken: driver loses positions (position increases) from one lap to next
-- We use lap_positions which has position per lap per driver per race

WITH driver_lap_positions AS (
  SELECT 
    lp.race_id,
    lp.driver_id,
    d.full_name,
    lp.lap,
    lp.position,
    lp.lap_type
  FROM lap_positions lp
  JOIN drivers d ON lp.driver_id = d.driver_id
  WHERE lp.lap > 1  -- exclude first lap
    AND (lp.lap_type IS NULL OR lp.lap_type NOT IN ('P', 'R'))  -- exclude pit stops and retirements
),
position_changes AS (
  SELECT 
    a.race_id,
    a.driver_id,
    a.full_name,
    a.lap AS current_lap,
    a.position AS current_pos,
    b.position AS prev_pos,
    CASE 
      WHEN a.position < b.position THEN 1  -- overtook someone (position number decreased = gained positions)
      ELSE 0 
    END AS overtook,
    CASE 
      WHEN a.position > b.position THEN 1  -- was overtaken (position number increased = lost positions)
      ELSE 0 
    END AS was_overtaken
  FROM driver_lap_positions a
  JOIN driver_lap_positions b 
    ON a.race_id = b.race_id 
    AND a.driver_id = b.driver_id 
    AND a.lap = b.lap + 1
),
driver_stats AS (
  SELECT 
    driver_id,
    full_name,
    SUM(overtook) AS total_overtook,
    SUM(was_overtaken) AS total_was_overtaken
  FROM position_changes
  GROUP BY driver_id, full_name
)
SELECT full_name
FROM driver_stats
WHERE total_was_overtaken > total_overtook
ORDER BY full_name