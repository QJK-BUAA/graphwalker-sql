-- For each year, find the top 2 most common primary_collision_factor values
-- Then find the year(s) where that pair is unique compared to all other years
WITH yearly_top2 AS (
  SELECT 
    strftime('%Y', collisions.collision_date) AS year,
    collisions.primary_collision_factor,
    COUNT(*) AS cnt,
    ROW_NUMBER() OVER (PARTITION BY strftime('%Y', collisions.collision_date) ORDER BY COUNT(*) DESC) AS rn
  FROM collisions
  WHERE collisions.primary_collision_factor IS NOT NULL
  GROUP BY year, collisions.primary_collision_factor
),
yearly_pair AS (
  SELECT 
    year,
    GROUP_CONCAT(primary_collision_factor, ', ' ORDER BY primary_collision_factor) AS top2_factors
  FROM yearly_top2
  WHERE rn <= 2
  GROUP BY year
)
SELECT yp1.year
FROM yearly_pair yp1
WHERE yp1.top2_factors NOT IN (
  SELECT yp2.top2_factors
  FROM yearly_pair yp2
  WHERE yp2.year != yp1.year
)