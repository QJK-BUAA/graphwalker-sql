SELECT 
    w1.name AS wrestler1,
    w2.name AS wrestler2
FROM Matches m
JOIN Wrestlers w1 ON m.winner_id = w1.id
JOIN Wrestlers w2 ON m.loser_id = w2.id
JOIN Belts b ON m.title_id = b.id
WHERE b.name = 'NXT'
  AND (m.title_change IS NULL OR m.title_change = 0)
ORDER BY CAST(m.duration AS REAL) ASC
LIMIT 1