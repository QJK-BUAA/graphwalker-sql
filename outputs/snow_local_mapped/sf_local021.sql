SELECT AVG(total_runs) AS avg_total_runs
FROM (
    SELECT player_match.player_id, SUM(batsman_scored.runs_scored) AS total_runs
    FROM batsman_scored
    JOIN player_match ON batsman_scored.match_id = player_match.match_id
    JOIN player ON player_match.player_id = player.player_id
    GROUP BY player_match.player_id, batsman_scored.match_id
    HAVING SUM(batsman_scored.runs_scored) > 50
) AS subquery