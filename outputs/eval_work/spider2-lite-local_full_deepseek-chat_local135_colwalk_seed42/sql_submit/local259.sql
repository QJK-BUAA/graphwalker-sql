-- For each player, compute all requested statistics
WITH 
-- Player roles: count occurrences of each role per player
player_roles AS (
    SELECT 
        pm.player_id,
        pm.role,
        COUNT(*) AS role_count
    FROM player_match pm
    GROUP BY pm.player_id, pm.role
),
-- Most frequent role per player (pick one if tie, e.g., max role alphabetically)
most_frequent_role AS (
    SELECT 
        pr.player_id,
        pr.role AS most_frequent_role
    FROM player_roles pr
    WHERE pr.role_count = (
        SELECT MAX(pr2.role_count)
        FROM player_roles pr2
        WHERE pr2.player_id = pr.player_id
    )
    GROUP BY pr.player_id
    HAVING pr.role = MAX(pr.role)  -- tie-breaker: alphabetically last role
),
-- Total runs scored per player (from batsman_scored)
total_runs AS (
    SELECT 
        b.striker AS player_id,
        SUM(bs.runs_scored) AS total_runs
    FROM ball_by_ball b
    JOIN batsman_scored bs ON b.match_id = bs.match_id 
        AND b.over_id = bs.over_id 
        AND b.ball_id = bs.ball_id 
        AND b.innings_no = bs.innings_no
    GROUP BY b.striker
),
-- Total matches played per player (as any role)
total_matches AS (
    SELECT 
        player_id,
        COUNT(DISTINCT match_id) AS total_matches
    FROM player_match
    GROUP BY player_id
),
-- Total dismissals per player (as batsman out)
total_dismissals AS (
    SELECT 
        wt.player_out AS player_id,
        COUNT(*) AS total_dismissals
    FROM wicket_taken wt
    GROUP BY wt.player_out
),
-- Highest score in a single match per player
-- We need runs per match per player (as striker)
runs_per_match AS (
    SELECT 
        b.striker AS player_id,
        b.match_id,
        SUM(bs.runs_scored) AS match_runs
    FROM ball_by_ball b
    JOIN batsman_scored bs ON b.match_id = bs.match_id 
        AND b.over_id = bs.over_id 
        AND b.ball_id = bs.ball_id 
        AND b.innings_no = bs.innings_no
    GROUP BY b.striker, b.match_id
),
highest_score AS (
    SELECT 
        player_id,
        MAX(match_runs) AS highest_score
    FROM runs_per_match
    GROUP BY player_id
),
-- Matches with at least 30, 50, 100 runs
matches_30 AS (
    SELECT player_id, COUNT(*) AS cnt_30
    FROM runs_per_match
    WHERE match_runs >= 30
    GROUP BY player_id
),
matches_50 AS (
    SELECT player_id, COUNT(*) AS cnt_50
    FROM runs_per_match
    WHERE match_runs >= 50
    GROUP BY player_id
),
matches_100 AS (
    SELECT player_id, COUNT(*) AS cnt_100
    FROM runs_per_match
    WHERE match_runs >= 100
    GROUP BY player_id
),
-- Total balls faced per player (as striker)
total_balls_faced AS (
    SELECT 
        striker AS player_id,
        COUNT(*) AS total_balls
    FROM ball_by_ball
    GROUP BY striker
),
-- Total wickets taken per player (as bowler)
total_wickets AS (
    SELECT 
        b.bowler AS player_id,
        COUNT(*) AS total_wickets
    FROM ball_by_ball b
    JOIN wicket_taken wt ON b.match_id = wt.match_id 
        AND b.over_id = wt.over_id 
        AND b.ball_id = wt.ball_id 
        AND b.innings_no = wt.innings_no
    GROUP BY b.bowler
),
-- Economy rate: runs conceded per over bowled
-- First, runs conceded per ball by bowler
runs_conceded_per_ball AS (
    SELECT 
        b.bowler AS player_id,
        b.match_id,
        b.over_id,
        b.ball_id,
        b.innings_no,
        COALESCE(bs.runs_scored, 0) AS runs_conceded
    FROM ball_by_ball b
    LEFT JOIN batsman_scored bs ON b.match_id = bs.match_id 
        AND b.over_id = bs.over_id 
        AND b.ball_id = bs.ball_id 
        AND b.innings_no = bs.innings_no
),
-- Total runs conceded and total balls bowled per player
bowler_stats AS (
    SELECT 
        player_id,
        SUM(runs_conceded) AS total_runs_conceded,
        COUNT(*) AS total_balls_bowled
    FROM runs_conceded_per_ball
    GROUP BY player_id
),
-- Economy rate = (total_runs_conceded / (total_balls_bowled/6)) = total_runs_conceded * 6 / total_balls_bowled
-- Best bowling performance in a single match: most wickets in a match, if tie fewest runs conceded
-- First, wickets per match per bowler
wickets_per_match AS (
    SELECT 
        b.bowler AS player_id,
        b.match_id,
        COUNT(*) AS wickets
    FROM ball_by_ball b
    JOIN wicket_taken wt ON b.match_id = wt.match_id 
        AND b.over_id = wt.over_id 
        AND b.ball_id = wt.ball_id 
        AND b.innings_no = wt.innings_no
    GROUP BY b.bowler, b.match_id
),
-- Runs conceded per match per bowler
runs_per_match_bowler AS (
    SELECT 
        b.bowler AS player_id,
        b.match_id,
        SUM(COALESCE(bs.runs_scored, 0)) AS runs_conceded
    FROM ball_by_ball b
    LEFT JOIN batsman_scored bs ON b.match_id = bs.match_id 
        AND b.over_id = bs.over_id 
        AND b.ball_id = bs.ball_id 
        AND b.innings_no = bs.innings_no
    GROUP BY b.bowler, b.match_id
),
-- Combine wickets and runs per match
bowling_perf_per_match AS (
    SELECT 
        wpm.player_id,
        wpm.match_id,
        wpm.wickets,
        rpm.runs_conceded
    FROM wickets_per_match wpm
    JOIN runs_per_match_bowler rpm ON wpm.player_id = rpm.player_id AND wpm.match_id = rpm.match_id
),
-- Best performance: max wickets, then min runs
best_bowling AS (
    SELECT 
        player_id,
        wickets || '-' || runs_conceded AS best_bowling_performance
    FROM bowling_perf_per_match bpm1
    WHERE (wickets, -runs_conceded) = (
        SELECT MAX(wickets), MAX(-runs_conceded)
        FROM bowling_perf_per_match bpm2
        WHERE bpm2.player_id = bpm1.player_id
    )
    GROUP BY player_id
)
-- Final query
SELECT 
    p.player_id,
    p.player_name,
    COALESCE(mfr.most_frequent_role, 'Unknown') AS most_frequent_role,
    p.batting_hand,
    p.bowling_skill,
    COALESCE(tr.total_runs, 0) AS total_runs,
    COALESCE(tm.total_matches, 0) AS total_matches,
    COALESCE(td.total_dismissals, 0) AS total_dismissals,
    CASE 
        WHEN COALESCE(td.total_dismissals, 0) = 0 THEN NULL
        ELSE CAST(COALESCE(tr.total_runs, 0) AS REAL) / td.total_dismissals
    END AS batting_average,
    COALESCE(hs.highest_score, 0) AS highest_score,
    COALESCE(m30.cnt_30, 0) AS matches_ge_30,
    COALESCE(m50.cnt_50, 0) AS matches_ge_50,
    COALESCE(m100.cnt_100, 0) AS matches_ge_100,
    COALESCE(tbf.total_balls, 0) AS total_balls_faced,
    CASE 
        WHEN COALESCE(tbf.total_balls, 0) = 0 THEN NULL
        ELSE CAST(COALESCE(tr.total_runs, 0) AS REAL) / tbf.total_balls * 100.0
    END AS strike_rate,
    COALESCE(tw.total_wickets, 0) AS total_wickets,
    CASE 
        WHEN COALESCE(bs.total_balls_bowled, 0) = 0 THEN NULL
        ELSE CAST(bs.total_runs_conceded AS REAL) * 6.0 / bs.total_balls_bowled
    END AS economy_rate,
    COALESCE(bb.best_bowling_performance, '0-0') AS best_bowling_performance
FROM player p
LEFT JOIN most_frequent_role mfr ON p.player_id = mfr.player_id
LEFT JOIN total_runs tr ON p.player_id = tr.player_id
LEFT JOIN total_matches tm ON p.player_id = tm.player_id
LEFT JOIN total_dismissals td ON p.player_id = td.player_id
LEFT JOIN highest_score hs ON p.player_id = hs.player_id
LEFT JOIN matches_30 m30 ON p.player_id = m30.player_id
LEFT JOIN matches_50 m50 ON p.player_id = m50.player_id
LEFT JOIN matches_100 m100 ON p.player_id = m100.player_id
LEFT JOIN total_balls_faced tbf ON p.player_id = tbf.player_id
LEFT JOIN total_wickets tw ON p.player_id = tw.player_id
LEFT JOIN bowler_stats bs ON p.player_id = bs.player_id
LEFT JOIN best_bowling bb ON p.player_id = bb.player_id
ORDER BY p.player_id