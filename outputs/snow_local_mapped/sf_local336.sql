-- Count overtakes in each category within first 5 laps
-- Overtakes are detected by position changes between consecutive laps for the same driver in the same race
-- Categories: retirements (lap_type='Retirement'), pit stops (via pit_stops table), start-related (lap_type='Starting Position - Grid Drop'), standard on-track (lap_type='Race')

WITH lap_positions_filtered AS (
  SELECT * FROM lap_positions WHERE lap BETWEEN 1 AND 5
),
-- Detect overtakes: position improvement from lap N to N+1
overtakes AS (
  SELECT 
    a.race_id,
    a.driver_id,
    a.lap AS lap_from,
    b.lap AS lap_to,
    a.position AS pos_from,
    b.position AS pos_to,
    a.lap_type AS lap_type_from,
    b.lap_type AS lap_type_to
  FROM lap_positions_filtered a
  JOIN lap_positions_filtered b 
    ON a.race_id = b.race_id 
   AND a.driver_id = b.driver_id 
   AND a.lap + 1 = b.lap
  WHERE b.position < a.position  -- overtake: position number decreases (better position)
),
-- Categorize overtakes
categorized AS (
  SELECT 
    CASE 
      WHEN lap_type_to = 'Retirement (Disqualification)' OR lap_type_from = 'Retirement (Disqualification)' THEN 'retirements'
      WHEN EXISTS (SELECT 1 FROM pit_stops ps 
                   WHERE ps.race_id = overtakes.race_id 
                     AND ps.driver_id = overtakes.driver_id 
                     AND ps.lap = overtakes.lap_to) THEN 'pit_stops'
      WHEN lap_type_from = 'Starting Position - Grid Drop' THEN 'start_related'
      WHEN lap_type_to = 'Race' OR lap_type_from = 'Race' THEN 'standard_on_track'
      ELSE 'other'
    END AS category
  FROM overtakes
)
SELECT 
  category,
  COUNT(*) AS overtake_count
FROM categorized
WHERE category IN ('retirements', 'pit_stops', 'start_related', 'standard_on_track')
GROUP BY category
ORDER BY category