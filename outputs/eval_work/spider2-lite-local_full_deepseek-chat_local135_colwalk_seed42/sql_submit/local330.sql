-- For each page, count distinct sessions where it is either the first or last page visited in that session
WITH session_pages AS (
    SELECT 
        session,
        path,
        stamp,
        ROW_NUMBER() OVER (PARTITION BY session ORDER BY stamp ASC) AS rn_asc,
        ROW_NUMBER() OVER (PARTITION BY session ORDER BY stamp DESC) AS rn_desc
    FROM activity_log
),
landing_exit AS (
    SELECT 
        session,
        path
    FROM session_pages
    WHERE rn_asc = 1 OR rn_desc = 1
)
SELECT 
    path,
    COUNT(DISTINCT session) AS total_sessions
FROM landing_exit
GROUP BY path
ORDER BY path