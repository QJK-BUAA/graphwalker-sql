-- Step 1: For each (step, version), find the test score of the "Stack" model
WITH stack_scores AS (
    SELECT ms.step, ms.version, ms.test_score AS stack_test_score
    FROM model_score ms
    WHERE ms.model = 'Stack'
),
-- Step 2: For each (step, version), find the maximum test score among non-"Stack" models
non_stack_max AS (
    SELECT ms.step, ms.version, MAX(ms.test_score) AS max_non_stack_test_score
    FROM model_score ms
    WHERE ms.model != 'Stack'
    GROUP BY ms.step, ms.version
),
-- Step 3: Filter to (step, version) pairs where max non-Stack test score < Stack test score
valid_combos AS (
    SELECT ns.step, ns.version
    FROM non_stack_max ns
    JOIN stack_scores ss ON ns.step = ss.step AND ns.version = ss.version
    WHERE ns.max_non_stack_test_score < ss.stack_test_score
),
-- Step 4: Count occurrences of each problem in solution table across steps 1,2,3
solution_counts AS (
    SELECT s.name, COUNT(*) AS total_occurrences
    FROM solution s
    WHERE s.version IN (1, 2, 3)
    GROUP BY s.name
),
-- Step 5: Count occurrences of each problem in model_score for valid combos
model_score_counts AS (
    SELECT ms.name, COUNT(*) AS ms_count
    FROM model_score ms
    JOIN valid_combos vc ON ms.step = vc.step AND ms.version = vc.version
    GROUP BY ms.name
)
-- Step 6: Find problems where model_score count exceeds solution count
SELECT p.name AS problem
FROM problem p
JOIN model_score_counts msc ON p.name = msc.name
JOIN solution_counts sc ON p.name = sc.name
WHERE msc.ms_count > sc.total_occurrences