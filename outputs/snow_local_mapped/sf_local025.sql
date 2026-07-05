WITH over_runs AS (
    -- Combine runs from batsman_scored and extra_runs for each over in each innings of each match
    SELECT 
        b.match_id,
        b.innings_no,
        b.over_id,
        SUM(COALESCE(bs.runs_scored, 0) + COALESCE(er.extra_runs, 0)) AS total_runs
    FROM ball_by_ball b
    LEFT JOIN batsman_scored bs ON b.match_id = bs.match_id 
        AND b.over_id = bs.over_id 
        AND b.ball_id = bs.ball_id 
        AND b.innings_no = bs.innings_no
    LEFT JOIN extra_runs er ON b.match_id = er.match_id 
        AND b.over_id = er.over_id 
        AND b.ball_id = er.ball_id 
        AND b.innings_no = er.innings_no
    GROUP BY b.match_id, b.innings_no, b.over_id
),
max_over_per_match AS (
    -- For each match, find the over with the highest total runs (across all innings)
    SELECT 
        match_id,
        MAX(total_runs) AS max_over_runs
    FROM over_runs
    GROUP BY match_id
),
over_details AS (
    -- Get the bowler and over details for the highest scoring over in each match
    SELECT 
        m.match_id,
        m.max_over_runs,
        b.over_id,
        b.innings_no,
        b.bowler
    FROM max_over_per_match m
    JOIN over_runs o ON m.match_id = o.match_id AND m.max_over_runs = o.total_runs
    JOIN ball_by_ball b ON m.match_id = b.match_id 
        AND o.over_id = b.over_id 
        AND o.innings_no = b.innings_no
    GROUP BY m.match_id  -- In case of ties, pick one over per match
)
-- Calculate the average of the highest over totals across all matches
SELECT 
    CAST(SUM(max_over_runs) AS REAL) / COUNT(*) AS avg_highest_over_runs
FROM over_details