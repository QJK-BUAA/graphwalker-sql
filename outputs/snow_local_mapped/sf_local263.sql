-- Step 1: For each model (name, version) and step, find max test score among non-Stack models and Stack model's test score
WITH step_scores AS (
    SELECT 
        ms.name,
        ms.version,
        ms.step,
        MAX(CASE WHEN ms.model != 'Stack' THEN ms.test_score END) AS max_non_stack_test,
        MAX(CASE WHEN ms.model = 'Stack' THEN ms.test_score END) AS stack_test
    FROM model_score ms
    GROUP BY ms.name, ms.version, ms.step
),
-- Step 2: Determine status for each model (name, version) based on any step
model_status AS (
    SELECT 
        ss.name,
        ss.version,
        CASE 
            WHEN MAX(CASE WHEN ss.max_non_stack_test < ss.stack_test THEN 1 ELSE 0 END) = 1 THEN 'strong'
            WHEN MAX(CASE WHEN ss.max_non_stack_test = ss.stack_test THEN 1 ELSE 0 END) = 1 THEN 'soft'
        END AS status
    FROM step_scores ss
    WHERE ss.stack_test IS NOT NULL
    GROUP BY ss.name, ss.version
),
-- Step 3: Join with model table to get L1_model
model_l1 AS (
    SELECT 
        ms.name,
        ms.version,
        ms.status,
        m.L1_model
    FROM model_status ms
    JOIN model m ON ms.name = m.name AND ms.version = m.version
),
-- Step 4: Count occurrences of each L1_model per status
l1_counts AS (
    SELECT 
        L1_model,
        status,
        COUNT(*) AS occurrence_count
    FROM model_l1
    WHERE status IS NOT NULL
    GROUP BY L1_model, status
),
-- Step 5: Rank L1_models by occurrence count within each status
ranked AS (
    SELECT 
        L1_model,
        status,
        occurrence_count,
        ROW_NUMBER() OVER (PARTITION BY status ORDER BY occurrence_count DESC) AS rn
    FROM l1_counts
)
-- Step 6: Select the top L1_model for each status
SELECT 
    L1_model,
    status,
    occurrence_count
FROM ranked
WHERE rn = 1
ORDER BY status