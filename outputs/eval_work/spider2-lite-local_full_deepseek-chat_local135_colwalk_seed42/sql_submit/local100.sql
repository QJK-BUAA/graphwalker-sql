-- Step 1: Find Shahrukh Khan's PID
-- Step 2: Find actors who acted directly with Shahrukh Khan (Shahrukh number 1)
-- Step 3: Find actors who acted with those from step 2 but not directly with Shahrukh (Shahrukh number 2)
-- Step 4: Count distinct actors with Shahrukh number 2

WITH shahrukh_pid AS (
    SELECT PID FROM Person WHERE Name = 'Shahrukh Khan' LIMIT 1
),
direct_collaborators AS (
    SELECT DISTINCT c1.PID
    FROM M_Cast c1
    JOIN shahrukh_pid s ON c1.MID IN (
        SELECT MID FROM M_Cast WHERE PID = s.PID
    )
    WHERE c1.PID != s.PID
),
second_degree AS (
    SELECT DISTINCT c2.PID
    FROM M_Cast c2
    WHERE c2.MID IN (
        SELECT MID FROM M_Cast WHERE PID IN (SELECT PID FROM direct_collaborators)
    )
    AND c2.PID NOT IN (SELECT PID FROM direct_collaborators)
    AND c2.PID NOT IN (SELECT PID FROM shahrukh_pid)
)
SELECT COUNT(DISTINCT PID) AS count
FROM second_degree