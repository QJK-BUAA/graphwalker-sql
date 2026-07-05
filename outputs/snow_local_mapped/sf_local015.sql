-- Calculate fatality rate for motorcycle collisions separated by helmet usage
-- Group 1: parties wearing helmets (helmet used)
-- Group 2: parties not wearing helmets (helmet not used)
-- For each group: total motorcyclist fatalities / total collisions in that group

WITH 
-- Identify collisions that are motorcycle collisions
motorcycle_collisions AS (
    SELECT DISTINCT case_id
    FROM collisions
    WHERE motorcycle_collision = 1
),
-- Identify parties involved in motorcycle collisions with helmet info
helmet_usage AS (
    SELECT 
        p.case_id,
        p.party_number,
        p.party_type,
        -- Determine if helmet was used based on safety equipment fields
        CASE 
            WHEN (p.party_safety_equipment_1 LIKE '%helmet%used%' OR 
                  p.party_safety_equipment_2 LIKE '%helmet%used%' OR
                  p.party_safety_equipment_1 LIKE '%motorcycle helmet%' OR
                  p.party_safety_equipment_2 LIKE '%motorcycle helmet%')
            THEN 1  -- helmet used
            WHEN (p.party_safety_equipment_1 LIKE '%helmet%not%used%' OR 
                  p.party_safety_equipment_2 LIKE '%helmet%not%used%' OR
                  p.party_safety_equipment_1 LIKE '%no helmet%' OR
                  p.party_safety_equipment_2 LIKE '%no helmet%' OR
                  p.party_safety_equipment_1 = 'none' OR
                  p.party_safety_equipment_2 = 'none' OR
                  p.party_safety_equipment_1 = 'not used' OR
                  p.party_safety_equipment_2 = 'not used')
            THEN 0  -- helmet not used
            ELSE NULL  -- unknown
        END AS helmet_used
    FROM parties p
    INNER JOIN motorcycle_collisions mc ON p.case_id = mc.case_id
    WHERE p.party_type IN ('driver', 'passenger')
),
-- Aggregate to collision level: determine if collision had any helmet users or non-users
collision_helmet_status AS (
    SELECT 
        case_id,
        MAX(CASE WHEN helmet_used = 1 THEN 1 ELSE 0 END) AS has_helmet_used,
        MAX(CASE WHEN helmet_used = 0 THEN 1 ELSE 0 END) AS has_helmet_not_used
    FROM helmet_usage
    WHERE helmet_used IS NOT NULL
    GROUP BY case_id
),
-- Get motorcyclist fatalities per collision
motorcyclist_fatalities AS (
    SELECT 
        case_id,
        CAST(SUM(motorcyclist_killed_count) AS REAL) AS total_motorcyclist_killed
    FROM collisions
    WHERE motorcycle_collision = 1
    GROUP BY case_id
)
-- Calculate percentages
SELECT
    -- Percentage for collisions where helmets were used
    CASE 
        WHEN COUNT(CASE WHEN chs.has_helmet_used = 1 THEN 1 END) > 0 
        THEN ROUND(
            (COALESCE(SUM(CASE WHEN chs.has_helmet_used = 1 THEN mf.total_motorcyclist_killed ELSE 0 END), 0) * 100.0) /
            NULLIF(COUNT(CASE WHEN chs.has_helmet_used = 1 THEN 1 END), 0),
            4
        )
        ELSE 0
    END AS helmet_used_fatality_rate_percent,
    -- Percentage for collisions where helmets were not used
    CASE 
        WHEN COUNT(CASE WHEN chs.has_helmet_not_used = 1 THEN 1 END) > 0 
        THEN ROUND(
            (COALESCE(SUM(CASE WHEN chs.has_helmet_not_used = 1 THEN mf.total_motorcyclist_killed ELSE 0 END), 0) * 100.0) /
            NULLIF(COUNT(CASE WHEN chs.has_helmet_not_used = 1 THEN 1 END), 0),
            4
        )
        ELSE 0
    END AS helmet_not_used_fatality_rate_percent
FROM collision_helmet_status chs
LEFT JOIN motorcyclist_fatalities mf ON chs.case_id = mf.case_id