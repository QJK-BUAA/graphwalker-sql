WITH team_points AS (
    SELECT 
        m.season,
        m.league_id,
        l.name AS league_name,
        c.name AS country_name,
        t.team_long_name AS team_name,
        SUM(
            CASE 
                WHEN m.home_team_api_id = t.team_api_id THEN 
                    CASE 
                        WHEN m.home_team_goal > m.away_team_goal THEN 3
                        WHEN m.home_team_goal = m.away_team_goal THEN 1
                        ELSE 0
                    END
                WHEN m.away_team_api_id = t.team_api_id THEN
                    CASE 
                        WHEN m.away_team_goal > m.home_team_goal THEN 3
                        WHEN m.away_team_goal = m.home_team_goal THEN 1
                        ELSE 0
                    END
            END
        ) AS total_points
    FROM Match m
    JOIN Team t ON t.team_api_id IN (m.home_team_api_id, m.away_team_api_id)
    JOIN League l ON m.league_id = l.id
    JOIN Country c ON l.country_id = c.id
    GROUP BY m.season, m.league_id, t.team_api_id
),
ranked_teams AS (
    SELECT 
        season,
        team_name,
        league_name,
        country_name,
        total_points,
        ROW_NUMBER() OVER (PARTITION BY season, league_id ORDER BY total_points DESC) AS rn
    FROM team_points
)
SELECT 
    season,
    team_name,
    league_name,
    country_name,
    total_points
FROM ranked_teams
WHERE rn = 1
ORDER BY season, league_name