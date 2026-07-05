SELECT 
    w1.name AS wrestler1,
    w2.name AS wrestler2
FROM Matches m
JOIN Wrestlers w1 ON m.winner_id = CAST(w1.id AS TEXT)
JOIN Wrestlers w2 ON m.loser_id = CAST(w2.id AS TEXT)
WHERE m.title_id = (SELECT id FROM Belts WHERE name = 'NXT')
  AND m.title_change = 0
ORDER BY CAST(SUBSTR(m.duration, 1, 2) AS INTEGER) * 60 + CAST(SUBSTR(m.duration, 4, 2) AS INTEGER) ASC
LIMIT 1