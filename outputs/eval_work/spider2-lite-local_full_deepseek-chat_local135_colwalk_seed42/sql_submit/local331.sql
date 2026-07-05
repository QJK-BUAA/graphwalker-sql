-- Step 1: Identify sessions with two consecutive '/detail' visits
-- Step 2: Find the next page visit after those two consecutive '/detail' visits
-- Step 3: Count occurrences of each third-page visit per session
-- Step 4: Get top 3 most frequent third-page visits

WITH consecutive_details AS (
  SELECT 
    a1.session,
    a1.stamp AS first_detail_stamp,
    a2.stamp AS second_detail_stamp
  FROM access_log a1
  JOIN access_log a2 
    ON a1.session = a2.session 
    AND a1.stamp < a2.stamp
    AND a1.action = '/detail'
    AND a2.action = '/detail'
  WHERE NOT EXISTS (
    SELECT 1 FROM access_log a3
    WHERE a3.session = a1.session
      AND a3.stamp > a1.stamp
      AND a3.stamp < a2.stamp
  )
),
next_page AS (
  SELECT 
    cd.session,
    al.action AS third_page,
    al.stamp
  FROM consecutive_details cd
  JOIN access_log al 
    ON cd.session = al.session 
    AND al.stamp > cd.second_detail_stamp
  WHERE NOT EXISTS (
    SELECT 1 FROM access_log al2
    WHERE al2.session = cd.session
      AND al2.stamp > cd.second_detail_stamp
      AND al2.stamp < al.stamp
  )
)
SELECT 
  third_page,
  COUNT(*) AS occurrence_count
FROM next_page
GROUP BY third_page
ORDER BY occurrence_count DESC
LIMIT 3