-- Compute quintile rank for each student based on their grade in completed English courses
WITH CompletedEnglish AS (
    SELECT 
        s.StudentID,
        s.StudLastName,
        ss.Grade
    FROM Students s
    JOIN Student_Schedules ss ON s.StudentID = ss.StudentID
    JOIN Classes c ON ss.ClassID = c.ClassID
    JOIN Subjects sub ON c.SubjectID = sub.SubjectID
    WHERE ss.ClassStatus = 2
      AND sub.SubjectName LIKE '%English%'
),
Ranked AS (
    SELECT 
        StudentID,
        StudLastName,
        Grade,
        (SELECT COUNT(*) FROM CompletedEnglish ce2 WHERE ce2.Grade >= ce1.Grade) AS rank_ge,
        (SELECT COUNT(*) FROM CompletedEnglish) AS total_students
    FROM CompletedEnglish ce1
)
SELECT 
    StudLastName,
    CASE 
        WHEN CAST(rank_ge AS REAL) / total_students <= 0.2 THEN 'First'
        WHEN CAST(rank_ge AS REAL) / total_students <= 0.4 THEN 'Second'
        WHEN CAST(rank_ge AS REAL) / total_students <= 0.6 THEN 'Third'
        WHEN CAST(rank_ge AS REAL) / total_students <= 0.8 THEN 'Fourth'
        ELSE 'Fifth'
    END AS quintile
FROM Ranked
ORDER BY 
    CASE quintile
        WHEN 'First' THEN 1
        WHEN 'Second' THEN 2
        WHEN 'Third' THEN 3
        WHEN 'Fourth' THEN 4
        WHEN 'Fifth' THEN 5
    END