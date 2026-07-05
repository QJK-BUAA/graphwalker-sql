SELECT Name, Country FROM singer WHERE Song_Name LIKE '%Hey%'
SELECT Pets.weight FROM Has_Pet JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'dog' ORDER BY Pets.pet_age ASC LIMIT 1
SELECT c.CountryName FROM countries c LEFT JOIN car_makers cm ON c.CountryId = cm.Country WHERE cm.Id IS NULL
SELECT COUNT(*) FROM airlines
SELECT Name FROM employee ORDER BY Age ASC
SELECT      d.Document_ID,     d.Template_ID,     d.Document_Description FROM Documents d WHERE d.Document_Name = 'Robbin CV'
SELECT t.Hometown FROM teacher t GROUP BY t.Hometown HAVING COUNT(t.Teacher_ID) >= 2
SELECT Name FROM museum WHERE Num_of_Staff > (     SELECT MIN(Num_of_Staff)     FROM museum     WHERE Open_Year > '2010' )
SELECT COUNT(DISTINCT loser_name) FROM matches
SELECT ship.id, ship.name FROM death JOIN ship ON death.caused_by_ship_id = ship.id GROUP BY ship.id, ship.name ORDER BY SUM(death.injured) DESC LIMIT 1
SELECT      s.first_name,     s.middle_name,     s.last_name FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id JOIN Student_Enrolment_Courses sec ON se.student_enrolment_id = sec.student_enrolment_id JOIN Transcript_Contents tc ON sec.student_course_id = tc.student_course_id JOIN Transcripts t ON tc.transcript_id = t.transcript_id ORDER BY t.transcript_date ASC LIMIT 1
SELECT id  FROM TV_Channel  GROUP BY id  HAVING COUNT(*) > 2
SELECT people.Name FROM poker_player JOIN people ON poker_player.People_ID = people.People_ID ORDER BY poker_player.Final_Table_Made ASC
SELECT AREA_CODE_STATE.area_code FROM VOTES JOIN AREA_CODE_STATE ON VOTES.state = AREA_CODE_STATE.state GROUP BY AREA_CODE_STATE.area_code ORDER BY COUNT(DISTINCT VOTES.vote_id) DESC LIMIT 1
SELECT Name, Population, LifeExpectancy  FROM country  WHERE Continent = 'Asia'  ORDER BY SurfaceArea DESC  LIMIT 1
SELECT Record_Company, COUNT(*) AS cnt FROM orchestra GROUP BY Record_Company ORDER BY cnt DESC LIMIT 1
SELECT name, grade FROM Highschooler
SELECT tt.treatment_type_description FROM Treatment_Types tt JOIN Treatments t ON tt.treatment_type_code = t.treatment_type_code GROUP BY tt.treatment_type_code, tt.treatment_type_description ORDER BY SUM(t.cost_of_treatment) ASC LIMIT 1
SELECT Citizenship, COUNT(*) AS singer_count FROM singer GROUP BY Citizenship
SELECT p.property_name FROM Properties p JOIN Ref_Property_Types rpt ON p.property_type_code = rpt.property_type_code WHERE (rpt.property_type_description = 'House' OR rpt.property_type_description = 'Apartment')   AND p.room_count > 1
