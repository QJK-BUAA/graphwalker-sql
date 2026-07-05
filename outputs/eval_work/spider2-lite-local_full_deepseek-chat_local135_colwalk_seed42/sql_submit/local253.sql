-- Step 1: Clean salary by removing non-numeric characters (₹, commas, /yr, etc.) and cast to numeric
WITH cleaned_salaries AS (
    SELECT 
        Location,
        CompanyName,
        CAST(REPLACE(REPLACE(REPLACE(REPLACE(Salary, '₹', ''), ',', ''), '/yr', ''), ' ', '') AS REAL) AS CleanedSalary
    FROM SalaryDataset
    WHERE Location IN ('Mumbai', 'Pune', 'New Delhi', 'Hyderabad')
),
-- Step 2: Calculate national average salary (overall average across all locations)
national_avg AS (
    SELECT AVG(CleanedSalary) AS AvgSalaryCountry
    FROM cleaned_salaries
),
-- Step 3: Calculate average salary per company per location
city_company_avg AS (
    SELECT 
        Location,
        CompanyName,
        AVG(CleanedSalary) AS AvgSalaryState
    FROM cleaned_salaries
    GROUP BY Location, CompanyName
),
-- Step 4: Rank companies within each location by average salary descending
ranked_companies AS (
    SELECT 
        c.Location,
        c.CompanyName,
        c.AvgSalaryState,
        n.AvgSalaryCountry,
        ROW_NUMBER() OVER (PARTITION BY c.Location ORDER BY c.AvgSalaryState DESC) AS rn
    FROM city_company_avg c
    CROSS JOIN national_avg n
)
-- Step 5: Select top 5 per location
SELECT 
    Location,
    CompanyName AS "Company Name",
    ROUND(AvgSalaryState, 4) AS "Average Salary in State",
    ROUND(AvgSalaryCountry, 4) AS "Average Salary in Country"
FROM ranked_companies
WHERE rn <= 5
ORDER BY Location, AvgSalaryState DESC