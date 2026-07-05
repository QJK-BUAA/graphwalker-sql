WITH team_wins AS (
    -- Count wins for each team as home team
    SELECT 
        l.id AS league_id,
        l.name AS league_name,
        t.team_api_id,
        t.team_long_name,
        COUNT(*) AS wins
    FROM League l
    JOIN Match m ON m.league_id = l.id
    JOIN Team t ON t.team_api_id = m.home_team_api_id
    WHERE m.home_team_goal > m.away_team_goal
    GROUP BY l.id, t.team_api_id
    
    UNION ALL
    
    -- Count wins for each team as away team
    SELECT 
        l.id AS league_id,
        l.name AS league_name,
        t.team_api_id,
        t.team_long_name,
        COUNT(*) AS wins
    FROM League l
    JOIN Match m ON m.league_id = l.id
    JOIN Team t ON t.team_api_id = m.away_team_api_id
    WHERE m.away_team_goal > m.home_team_goal
    GROUP BY l.id, t.team_api_id
),
total_wins AS (
    -- Sum wins for each team in each league
    SELECT 
        league_id,
        league_name,
        team_api_id,
        team_long_name,
        SUM(wins) AS total_wins
    FROM team_wins
    GROUP BY league_id, team_api_id
),
all_teams_in_league AS (
    -- Get all teams that have played in each league (including those with 0 wins)
    SELECT DISTINCT
        l.id AS league_id,
        l.name AS league_name,
        t.team_api_id,
        t.team_long_name
    FROM League l
    JOIN Match m ON m.league_id = l.id
    JOIN Team t ON t.team_api_id IN (m.home_team_api_id, m.away_team_api_id)
),
team_win_counts AS (
    -- Combine all teams with their win counts (0 for teams with no wins)
    SELECT 
        a.league_id,
        a.league_name,
        a.team_api_id,
        a.team_long_name,
        COALESCE(w.total_wins, 0) AS total_wins
    FROM all_teams_in_league a
    LEFT JOIN total_wins w ON a.league_id = w.league_id AND a.team_api_id = w.team_api_id
),
ranked_wins AS (
    -- Rank teams by total wins within each league, with tiebreaker to pick one
    SELECT 
        league_id,
        league_name,
        team_api_id,
        team_long_name,
        total_wins,
        ROW_NUMBER() OVER (
            PARTITION BY league_id 
            ORDER BY total_wins ASC, team_api_id ASC
        ) AS rn
    FROM team_win_counts
)
-- Select the team with fewest wins in each league
SELECT 
    league_name,
    team_long_name,
    total_wins
FROM ranked_wins
WHERE rn = 1
ORDER BY league_name