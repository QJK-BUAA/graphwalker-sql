-- Calculate median of highest season goals per team
WITH team_season_goals AS (
    SELECT 
        home_team_api_id AS team_api_id,
        season,
        SUM(home_team_goal) AS total_goals
    FROM Match
    GROUP BY home_team_api_id, season
    UNION ALL
    SELECT 
        away_team_api_id AS team_api_id,
        season,
        SUM(away_team_goal) AS total_goals
    FROM Match
    GROUP BY away_team_api_id, season
),
team_highest_goals AS (
    SELECT 
        team_api_id,
        MAX(total_goals) AS highest_season_goals
    FROM team_season_goals
    GROUP BY team_api_id
),
ranked AS (
    SELECT 
        highest_season_goals,
        ROW_NUMBER() OVER (ORDER BY highest_season_goals) AS rn,
        COUNT(*) OVER () AS cnt
    FROM team_highest_goals
)
SELECT 
    AVG(CAST(highest_season_goals AS REAL)) AS median_highest_season_goals
FROM ranked
WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)