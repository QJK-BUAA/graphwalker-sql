WITH filtered_jobs AS (
    SELECT j.job_id, j.salary_year_avg
    FROM job_postings_fact j
    WHERE j.job_title_short = 'Data Analyst'
      AND j.salary_year_avg IS NOT NULL
      AND j.job_work_from_home = 1
),
skill_demand AS (
    SELECT sj.skill_id, COUNT(*) AS demand_count
    FROM filtered_jobs fj
    JOIN skills_job_dim sj ON fj.job_id = sj.job_id
    GROUP BY sj.skill_id
    ORDER BY demand_count DESC
    LIMIT 3
),
jobs_with_top_skills AS (
    SELECT DISTINCT fj.job_id
    FROM filtered_jobs fj
    JOIN skills_job_dim sj ON fj.job_id = sj.job_id
    WHERE sj.skill_id IN (SELECT skill_id FROM skill_demand)
)
SELECT AVG(fj.salary_year_avg) AS overall_avg_salary
FROM filtered_jobs fj
WHERE fj.job_id IN (SELECT job_id FROM jobs_with_top_skills)