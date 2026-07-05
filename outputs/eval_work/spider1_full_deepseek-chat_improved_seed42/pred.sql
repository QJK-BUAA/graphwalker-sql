SELECT Name, Country FROM singer WHERE Song_Name LIKE '%Hey%'
SELECT Pets.weight FROM Has_Pet JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'dog' ORDER BY Pets.pet_age ASC LIMIT 1
SELECT c.CountryName FROM countries c LEFT JOIN car_makers cm ON c.CountryId = cm.Country WHERE cm.Id IS NULL
SELECT COUNT(*) FROM airlines
SELECT Name FROM employee ORDER BY Age ASC
SELECT      d.Document_ID,     d.Template_ID,     d.Document_Description FROM Documents d WHERE d.Document_Name = 'Robbin CV'
SELECT t.Hometown FROM teacher t GROUP BY t.Hometown HAVING COUNT(t.Teacher_ID) >= 2
SELECT Name FROM museum WHERE Num_of_Staff > (     SELECT MIN(Num_of_Staff)     FROM museum     WHERE Open_Year = '2010' )
```sql SELECT COUNT(DISTINCT loser_name) AS distinct_loser_count FROM matches
SELECT      s.id AS ship_id,     s.name AS ship_name FROM death d JOIN ship s ON d.caused_by_ship_id = s.id GROUP BY s.id, s.name ORDER BY SUM(d.injured) DESC LIMIT 1
SELECT s.first_name, s.middle_name, s.last_name FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id JOIN Student_Enrolment_Courses sec ON se.student_enrolment_id = sec.student_enrolment_id JOIN Transcript_Contents tc ON sec.student_course_id = tc.student_course_id JOIN Transcripts t ON tc.transcript_id = t.transcript_id WHERE t.transcript_date IS NOT NULL ORDER BY t.transcript_date ASC LIMIT 1
SELECT id  FROM TV_Channel  GROUP BY id  HAVING COUNT(*) > 2
SELECT p.Name FROM poker_player AS pp JOIN people AS p ON pp.People_ID = p.People_ID ORDER BY pp.Final_Table_Made ASC
SELECT a.area_code FROM VOTES v JOIN AREA_CODE_STATE a ON v.state = a.state GROUP BY a.area_code ORDER BY COUNT(*) DESC LIMIT 1
SELECT Name, Population, LifeExpectancy FROM country WHERE Continent = 'Asia' ORDER BY SurfaceArea DESC LIMIT 1
SELECT Record_Company FROM orchestra WHERE Record_Company IS NOT NULL GROUP BY Record_Company ORDER BY COUNT(*) DESC LIMIT 1
SELECT name, grade FROM Highschooler
SELECT tt.treatment_type_description FROM Treatment_Types tt JOIN Treatments t ON tt.treatment_type_code = t.treatment_type_code GROUP BY tt.treatment_type_code, tt.treatment_type_description ORDER BY SUM(t.cost_of_treatment) ASC LIMIT 1
SELECT Citizenship, COUNT(*) AS singer_count FROM singer GROUP BY Citizenship
SELECT p.property_name FROM Properties p JOIN Ref_Property_Types rpt ON p.property_type_code = rpt.property_type_code WHERE (rpt.property_type_description LIKE '%House%' OR rpt.property_type_description LIKE '%Apartment%')   AND p.room_count > 1
