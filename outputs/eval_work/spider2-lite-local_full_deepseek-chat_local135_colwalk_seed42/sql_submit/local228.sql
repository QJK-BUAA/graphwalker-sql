WITH batsman_runs AS (
    SELECT 
        b.striker AS player_id,
        m.season_id,
        SUM(bs.runs_scored) AS total_runs
    FROM ball_by_ball b
    JOIN batsman_scored bs ON b.match_id = bs.match_id AND b.over_id = bs.over_id AND b.ball_id = bs.ball_id AND b.innings_no = bs.innings_no
    JOIN match m ON b.match_id = m.match_id
    GROUP BY b.striker, m.season_id
),
ranked_batsmen AS (
    SELECT 
        player_id,
        season_id,
        total_runs,
        ROW_NUMBER() OVER (PARTITION BY season_id ORDER BY total_runs DESC, player_id ASC) AS rn
    FROM batsman_runs
),
bowler_wickets AS (
    SELECT 
        wt.player_out AS player_id,
        m.season_id,
        COUNT(*) AS total_wickets
    FROM wicket_taken wt
    JOIN match m ON wt.match_id = m.match_id
    WHERE wt.kind_out NOT IN ('run out', 'hit wicket', 'retired hurt')
    GROUP BY wt.player_out, m.season_id
),
ranked_bowlers AS (
    SELECT 
        player_id,
        season_id,
        total_wickets,
        ROW_NUMBER() OVER (PARTITION BY season_id ORDER BY total_wickets DESC, player_id ASC) AS rn
    FROM bowler_wickets
)
SELECT 
    rb.season_id,
    rb.player_id AS batsman_id,
    p1.player_name AS batsman_name,
    rb.total_runs,
    rbow.player_id AS bowler_id,
    p2.player_name AS bowler_name,
    rbow.total_wickets
FROM ranked_batsmen rb
JOIN ranked_bowlers rbow ON rb.season_id = rbow.season_id AND rb.rn = rbow.rn
JOIN player p1 ON rb.player_id = p1.player_id
JOIN player p2 ON rbow.player_id = p2.player_id
WHERE rb.rn <= 3 AND rbow.rn <= 3
ORDER BY rb.season_id ASC, rb.rn ASC