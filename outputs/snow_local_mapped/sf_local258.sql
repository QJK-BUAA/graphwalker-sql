-- Compute per-bowler aggregates: wickets (excluding run-outs and other non-bowler dismissals),
-- economy rate (runs from bat per over, ignoring extras), strike rate (balls per wicket),
-- and best bowling in a single match (most wickets in a match, with runs conceded excluding extras).
WITH
-- Filter wicket_taken to only those credited to the bowler (kind_out not in 'run out', 'retired hurt', 'obstructing field', etc.)
bowler_wickets AS (
    SELECT wt.match_id, wt.over_id, wt.ball_id, wt.innings_no, wt.player_out AS wicket_player,
           b.team_bowling AS bowler_team, b.bowler
    FROM wicket_taken wt
    JOIN ball_by_ball b ON wt.match_id = b.match_id AND wt.over_id = b.over_id AND wt.ball_id = b.ball_id AND wt.innings_no = b.innings_no
    WHERE wt.kind_out NOT IN ('run out', 'retired hurt', 'obstructing field', 'hit the ball twice', 'hit wicket', 'stumped', 'lbw', 'bowled', 'caught', 'caught and bowled')
    -- Actually we want only dismissals where the bowler gets credit: typically 'bowled', 'caught', 'lbw', 'stumped', 'caught and bowled', 'hit wicket'
    -- But the question says "excluding run-outs and other dismissals not attributed to the bowler".
    -- So we keep only those where kind_out is one of the standard bowler-credited types.
    -- Let's list them explicitly:
    AND wt.kind_out IN ('bowled', 'caught', 'lbw', 'stumped', 'caught and bowled', 'hit wicket')
),
-- Runs scored off the bat (from batsman_scored) per ball, excluding extras
runs_from_bat AS (
    SELECT bs.match_id, bs.over_id, bs.ball_id, bs.innings_no, bs.runs_scored
    FROM batsman_scored bs
),
-- Extras per ball (to be excluded from runs conceded)
extras_per_ball AS (
    SELECT er.match_id, er.over_id, er.ball_id, er.innings_no, SUM(er.extra_runs) AS extra_runs
    FROM extra_runs er
    GROUP BY er.match_id, er.over_id, er.ball_id, er.innings_no
),
-- All balls bowled by each bowler (including extras, but we'll compute runs from bat only)
bowler_balls AS (
    SELECT b.match_id, b.over_id, b.ball_id, b.innings_no, b.bowler,
           COALESCE(rfb.runs_scored, 0) AS runs_bat,
           COALESCE(epb.extra_runs, 0) AS extra
    FROM ball_by_ball b
    LEFT JOIN runs_from_bat rfb ON b.match_id = rfb.match_id AND b.over_id = rfb.over_id AND b.ball_id = rfb.ball_id AND b.innings_no = rfb.innings_no
    LEFT JOIN extras_per_ball epb ON b.match_id = epb.match_id AND b.over_id = epb.over_id AND b.ball_id = epb.ball_id AND b.innings_no = epb.innings_no
),
-- Per bowler aggregates
bowler_stats AS (
    SELECT bb.bowler,
           COUNT(DISTINCT bw.wicket_player) AS total_wickets,
           SUM(bb.runs_bat) AS total_runs_conceded,
           COUNT(*) AS total_balls,
           -- Economy rate: runs per over (6 balls)
           CAST(SUM(bb.runs_bat) AS REAL) / (COUNT(*) / 6.0) AS economy_rate,
           -- Strike rate: balls per wicket
           CASE WHEN COUNT(DISTINCT bw.wicket_player) > 0 THEN CAST(COUNT(*) AS REAL) / COUNT(DISTINCT bw.wicket_player) ELSE NULL END AS strike_rate
    FROM bowler_balls bb
    LEFT JOIN bowler_wickets bw ON bb.match_id = bw.match_id AND bb.over_id = bw.over_id AND bb.ball_id = bw.ball_id AND bb.innings_no = bw.innings_no AND bb.bowler = bw.bowler
    GROUP BY bb.bowler
),
-- Best bowling in a single match: for each bowler, find the match with most wickets (and if tie, least runs)
best_match AS (
    SELECT bb.bowler,
           bb.match_id,
           COUNT(DISTINCT bw.wicket_player) AS match_wickets,
           SUM(bb.runs_bat) AS match_runs
    FROM bowler_balls bb
    LEFT JOIN bowler_wickets bw ON bb.match_id = bw.match_id AND bb.over_id = bw.over_id AND bb.ball_id = bw.ball_id AND bb.innings_no = bw.innings_no AND bb.bowler = bw.bowler
    GROUP BY bb.bowler, bb.match_id
),
best_per_bowler AS (
    SELECT bowler, match_id, match_wickets, match_runs,
           ROW_NUMBER() OVER (PARTITION BY bowler ORDER BY match_wickets DESC, match_runs ASC) AS rn
    FROM best_match
)
SELECT p.player_name AS bowler_name,
       bs.total_wickets,
       ROUND(bs.economy_rate, 4) AS economy_rate,
       ROUND(bs.strike_rate, 4) AS strike_rate,
       (SELECT CAST(bp.match_wickets AS TEXT) || '-' || CAST(bp.match_runs AS TEXT)
        FROM best_per_bowler bp
        WHERE bp.bowler = bs.bowler AND bp.rn = 1) AS best_bowling
FROM bowler_stats bs
JOIN player p ON bs.bowler = p.player_id
ORDER BY total_wickets DESC, economy_rate ASC