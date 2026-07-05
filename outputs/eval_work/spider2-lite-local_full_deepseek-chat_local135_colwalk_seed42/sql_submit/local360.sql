-- Step 1: For each session, find the timestamp of the first '/detail' or '/complete' event
WITH first_event AS (
    SELECT 
        session,
        MIN(stamp) AS first_stamp
    FROM activity_log
    WHERE path IN ('/detail', '/complete')
    GROUP BY session
),
-- Step 2: Count events before that first event with non-empty search_type
pre_events AS (
    SELECT 
        a.session,
        COUNT(*) AS event_count
    FROM activity_log a
    JOIN first_event f ON a.session = f.session
    WHERE a.stamp < f.first_stamp
      AND a.search_type != ''
    GROUP BY a.session
),
-- Step 3: Find the minimum count
min_count AS (
    SELECT MIN(event_count) AS min_event_count
    FROM pre_events
)
-- Step 4: Return sessions with that minimum count, along with path and search_type
SELECT 
    a.session,
    a.path,
    a.search_type
FROM activity_log a
JOIN pre_events p ON a.session = p.session
JOIN min_count m ON p.event_count = m.min_event_count
WHERE a.path IN ('/detail', '/complete')
  AND a.search_type != ''
ORDER BY a.session