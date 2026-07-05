WITH overtake_events AS (
  SELECT 
    lp1.race_id,
    lp1.driver_id,
    lp1.lap AS current_lap,
    lp1.position AS current_position,
    lp1.lap_type AS current_lap_type,
    lp2.position AS prev_position,
    lp2.lap_type AS prev_lap_type
  FROM lap_positions lp1
  JOIN lap_positions lp2 
    ON lp1.race_id = lp2.race_id 
    AND lp1.driver_id = lp2.driver_id 
    AND lp1.lap = lp2.lap + 1
  JOIN races_ext re 
    ON lp1.race_id = re.race_id 
    AND re.is_pit_data_available = 1
  WHERE lp1.position < lp2.position
    AND lp2.position > 1
    AND lp1.position > 0
    AND lp2.position > 0
)
SELECT 
  current_lap_type AS overtake_type,
  COUNT(*) AS number_of_overtakes
FROM overtake_events
GROUP BY current_lap_type
ORDER BY number_of_overtakes DESC