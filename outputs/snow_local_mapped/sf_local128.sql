SELECT 
    b.BowlerID,
    b.BowlerFirstName,
    b.BowlerLastName,
    bs.MatchID,
    bs.GameNumber,
    bs.HandiCapScore,
    t.TourneyDate,
    t.TourneyLocation
FROM Bowler_Scores bs
JOIN Bowlers b ON bs.BowlerID = b.BowlerID
JOIN Tourney_Matches tm ON bs.MatchID = tm.MatchID
JOIN Tournaments t ON tm.TourneyID = t.TourneyID
WHERE bs.WonGame = 1
  AND bs.HandiCapScore <= 190
  AND t.TourneyLocation IN ('Thunderbird Lanes', 'Totem Lanes', 'Bolero Lanes')
  AND b.BowlerID IN (
    SELECT bs2.BowlerID
    FROM Bowler_Scores bs2
    JOIN Tourney_Matches tm2 ON bs2.MatchID = tm2.MatchID
    JOIN Tournaments t2 ON tm2.TourneyID = t2.TourneyID
    WHERE bs2.WonGame = 1
      AND bs2.HandiCapScore <= 190
      AND t2.TourneyLocation IN ('Thunderbird Lanes', 'Totem Lanes', 'Bolero Lanes')
    GROUP BY bs2.BowlerID
    HAVING COUNT(DISTINCT t2.TourneyLocation) = 3
  )