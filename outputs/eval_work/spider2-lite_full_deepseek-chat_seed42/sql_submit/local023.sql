SELECT 
    p.player_name,
    ROUND(AVG(bs.runs_scored), 4) AS batting_average
FROM player p
JOIN batsman_scored bs ON p.player_id = bs.match_id
WHERE bs.match_id = 5
GROUP BY p.player_id
ORDER BY batting_average DESC
LIMIT 5