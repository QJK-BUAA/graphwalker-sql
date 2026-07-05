WITH avg_salary_per_rank AS (
    SELECT 
        FacRank,
        AVG(CAST(FacSalary AS REAL)) AS avg_salary
    FROM university_faculty
    GROUP BY FacRank
),
salary_diff AS (
    SELECT 
        uf.FacRank,
        uf.FacFirstName,
        uf.FacLastName,
        uf.FacSalary,
        ABS(CAST(uf.FacSalary AS REAL) - ar.avg_salary) AS diff
    FROM university_faculty uf
    JOIN avg_salary_per_rank ar ON uf.FacRank = ar.FacRank
),
min_diff_per_rank AS (
    SELECT 
        FacRank,
        MIN(diff) AS min_diff
    FROM salary_diff
    GROUP BY FacRank
)
SELECT 
    sd.FacRank,
    sd.FacFirstName,
    sd.FacLastName,
    sd.FacSalary
FROM salary_diff sd
JOIN min_diff_per_rank md ON sd.FacRank = md.FacRank AND sd.diff = md.min_diff
ORDER BY sd.FacRank, sd.FacLastName