WITH avg_salary_per_rank AS (
    SELECT 
        FacRank,
        AVG(FacSalary) AS avg_salary
    FROM university_faculty
    GROUP BY FacRank
),
salary_diff AS (
    SELECT 
        uf.FacRank,
        uf.FacFirstName,
        uf.FacLastName,
        uf.FacSalary,
        ABS(uf.FacSalary - ar.avg_salary) AS salary_diff
    FROM university_faculty uf
    JOIN avg_salary_per_rank ar ON uf.FacRank = ar.FacRank
),
min_diff_per_rank AS (
    SELECT 
        FacRank,
        MIN(salary_diff) AS min_diff
    FROM salary_diff
    GROUP BY FacRank
)
SELECT 
    sd.FacRank,
    sd.FacFirstName,
    sd.FacLastName,
    sd.FacSalary
FROM salary_diff sd
JOIN min_diff_per_rank md ON sd.FacRank = md.FacRank AND sd.salary_diff = md.min_diff
ORDER BY sd.FacRank, sd.FacFirstName, sd.FacLastName