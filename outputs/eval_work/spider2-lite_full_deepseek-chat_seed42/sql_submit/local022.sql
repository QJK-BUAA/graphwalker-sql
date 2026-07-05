SELECT DISTINCT p.player_name
FROM player p
JOIN player_match pm ON p.player_id = pm.player_id
JOIN match m ON pm.match_id = m.match_id
JOIN batsman_scored bs ON m.match_id = bs.match_id
JOIN team t ON pm.team_id = t.team_id
WHERE m.match_winner IS NOT NULL
  AND m.match_winner != pm.team_id
  AND pm.team_id = t.team_id
GROUP BY p.player_id, m.match_id
HAVING SUM(bs.runs_scored) >= 100