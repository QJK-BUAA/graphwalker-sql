WITH team_wins AS (
    SELECT 
        l.name AS league_name,
        t.team_long_name AS team_name,
        SUM(
            CASE 
                WHEN m.home_team_api_id = t.team_api_id AND m.home_team_goal > m.away_team_goal THEN 1
                WHEN m.away_team_api_id = t.team_api_id AND m.away_team_goal > m.home_team_goal THEN 1
                ELSE 0
            END
        ) AS total_wins
    FROM League l
    JOIN Match m ON m.league_id = l.id
    JOIN Team t ON t.team_api_id IN (m.home_team_api_id, m.away_team_api_id)
    GROUP BY l.id, t.team_api_id
),
min_wins_per_league AS (
    SELECT 
        league_name,
        MIN(total_wins) AS min_wins
    FROM team_wins
    GROUP BY league_name
)
SELECT 
    tw.league_name,
    MIN(tw.team_name) AS team_name
FROM team_wins tw
JOIN min_wins_per_league mw ON tw.league_name = mw.league_name AND tw.total_wins = mw.min_wins
GROUP BY tw.league_name
ORDER BY tw.league_name