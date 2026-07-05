SELECT COUNT(*) AS total_singers FROM singer
SELECT s.Song_Name, s.Song_release_year FROM singer s WHERE s.Age = (SELECT MIN(Age) FROM singer)
SELECT Location, Name FROM stadium WHERE Capacity BETWEEN 5000 AND 10000
SELECT AVG(Capacity) AS average_capacity, MAX(Capacity) AS maximum_capacity FROM stadium
SELECT Name, Country FROM singer WHERE Song_Name LIKE '%Hey%'
SELECT Pets.weight FROM Has_Pet JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'dog' ORDER BY Pets.pet_age ASC LIMIT 1
SELECT COUNT(*)  FROM Has_Pet  JOIN Student ON Has_Pet.StuID = Student.StuID  WHERE Student.Age > 20
SELECT PetID, weight FROM Pets WHERE pet_age > 1
SELECT PetType, AVG(weight) AS avg_weight FROM Pets GROUP BY PetType
SELECT      s.StuID,     COUNT(hp.PetID) AS pet_count FROM Student s INNER JOIN Has_Pet hp ON s.StuID = hp.StuID GROUP BY s.StuID
SELECT COUNT(*) FROM countries
SELECT      cm.FullName,     cm.Id,     COUNT(m.ModelId) AS model_count FROM car_makers cm LEFT JOIN model_list m ON cm.Id = m.Maker GROUP BY cm.Id, cm.FullName ORDER BY cm.Id
SELECT COUNT(*)  FROM model_list  JOIN car_makers ON model_list.Maker = car_makers.Id  WHERE car_makers.Country = '1'
SELECT      Year,     AVG(CAST(Weight AS REAL)) AS avg_weight,     AVG(CAST(Year AS REAL)) AS avg_year FROM cars_data GROUP BY Year
SELECT c.CountryName FROM countries c LEFT JOIN car_makers cm ON c.CountryId = cm.Country WHERE cm.Country IS NULL
SELECT COUNT(*) AS airline_count FROM airlines
SELECT COUNT(*)  FROM airlines  WHERE airlines.Country = 'USA'
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'CVO'   AND a.uid NOT IN (     SELECT f2.Airline     FROM flights f2     WHERE f2.SourceAirport = 'APG'   )
SELECT FlightNo  FROM flights  WHERE SourceAirport = 'APG'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airports.City IN ('Aberdeen', 'Abilene')
SELECT COUNT(*) AS employee_count FROM employee
SELECT Name  FROM employee  ORDER BY Age ASC
SELECT employee.City, COUNT(employee.Employee_ID) AS employee_count FROM employee GROUP BY employee.City
SELECT Name, Location, District FROM shop ORDER BY Number_products DESC
SELECT s.District FROM shop s WHERE s.Number_products < 3000 INTERSECT SELECT s.District FROM shop s WHERE s.Number_products > 10000
SELECT      d.Document_ID,     d.Template_ID,     d.Document_Description FROM Documents d WHERE d.Document_Name = 'Robbin CV'
SELECT COUNT(DISTINCT Templates.Template_ID) AS different_templates_count FROM Documents JOIN Templates ON Documents.Template_ID = Templates.Template_ID
SELECT COUNT(*)  FROM Documents  JOIN Templates ON Documents.Template_ID = Templates.Template_ID  WHERE Templates.Template_Type_Code = 'PPT'
SELECT      t.Template_ID AS ids,     t.Version_Number AS version_numbers,     t.Template_Type_Code AS type_codes FROM Templates t
SELECT Paragraph_Text, Other_Details FROM Paragraphs WHERE Paragraph_Text LIKE '%Korea%'
SELECT COUNT(*) AS teacher_count FROM teacher
SELECT Hometown, COUNT(*) AS teacher_count FROM teacher GROUP BY Hometown
SELECT t.Hometown FROM teacher t GROUP BY t.Hometown HAVING COUNT(*) >= 2
SELECT t.Name FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID JOIN course c ON ca.Course_ID = c.Course_ID WHERE c.Course = 'Math'
SELECT t.Name FROM teacher t WHERE t.Teacher_ID NOT IN (     SELECT ca.Teacher_ID     FROM course_arrange ca )
SELECT AVG(CAST(Num_of_Staff AS REAL)) FROM museum WHERE Open_Year < '2009'
SELECT Open_Year, Num_of_Staff FROM museum WHERE Name = 'Plaza Museum'
SELECT Name FROM museum WHERE Num_of_Staff > (     SELECT MIN(Num_of_Staff)     FROM museum     WHERE Open_Year = '2010' )
SELECT SUM(visit.Total_spent) AS total_ticket_expense FROM visitor JOIN visit ON visit.visitor_ID = visitor.ID WHERE visitor.Level_of_membership = 1
SELECT COUNT(DISTINCT v.ID)  FROM visitor v WHERE v.ID NOT IN (     SELECT DISTINCT v2.ID     FROM visitor v2     JOIN visit vi ON v2.ID = vi.visitor_ID     JOIN museum m ON vi.Museum_ID = m.Museum_ID     WHERE m.Open_Year > '2010' )
SELECT COUNT(DISTINCT country_code) AS distinct_country_codes FROM players
SELECT COUNT(DISTINCT loser_name) AS distinct_loser_count FROM matches
SELECT first_name || ' ' || last_name AS full_name FROM players WHERE hand = 'L' ORDER BY birth_date ASC
SELECT year, COUNT(*) AS match_count FROM matches GROUP BY year ORDER BY year
SELECT      p.first_name,     p.country_code,     p.birth_date FROM matches m JOIN players p ON m.winner_id = p.player_id ORDER BY m.winner_rank_points DESC LIMIT 1
SELECT AVG(CAST(injured AS REAL)) FROM death
SELECT      death.killed,     death.injured,     death.note FROM death JOIN ship ON death.caused_by_ship_id = ship.id WHERE ship.tonnage = 't'
SELECT name, result FROM battle WHERE bulgarian_commander != 'Boril'
SELECT b.id, b.name FROM battle b JOIN death d ON b.id = d.caused_by_ship_id GROUP BY b.id, b.name HAVING SUM(d.killed) > 10
SELECT      s.id AS ship_id,     s.name AS ship_name FROM ship s JOIN death d ON s.id = d.caused_by_ship_id GROUP BY s.id, s.name ORDER BY SUM(d.injured) DESC LIMIT 1
SELECT DISTINCT name FROM battle WHERE bulgarian_commander = 'Kaloyan'   AND latin_commander = 'Baldwin I'
SELECT line_1, line_2 FROM Addresses
SELECT s.semester_name FROM Semesters s LEFT JOIN Student_Enrolment se ON s.semester_id = se.semester_id WHERE se.semester_id IS NULL
SELECT DISTINCT c.course_name FROM Courses c JOIN Student_Enrolment_Courses sec ON c.course_id = sec.course_id
SELECT s.first_name, s.middle_name, s.last_name FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id JOIN Student_Enrolment_Courses sec ON se.student_enrolment_id = sec.student_enrolment_id JOIN Transcript_Contents tc ON sec.student_course_id = tc.student_course_id JOIN Transcripts t ON tc.transcript_id = t.transcript_id ORDER BY t.transcript_date ASC LIMIT 1
SELECT COUNT(DISTINCT Addresses.address_id)  FROM Students  JOIN Addresses ON Students.current_address_id = Addresses.address_id
SELECT      Country,     COUNT(*) AS number_of_channels FROM TV_Channel GROUP BY Country ORDER BY number_of_channels DESC LIMIT 1
SELECT      tvs.Episode,     tvs.Rating FROM TV_series tvs ORDER BY CAST(tvs.Rating AS REAL) DESC LIMIT 3
SELECT Package_Option, series_name  FROM TV_Channel  WHERE Hight_definition_TV = 'yes'
SELECT Pixel_aspect_ratio_PAR, Country FROM TV_Channel WHERE Language != 'English'
SELECT id FROM TV_Channel GROUP BY id HAVING COUNT(*) > 2
SELECT COUNT(*) FROM poker_player
SELECT p.Name FROM people p JOIN poker_player pp ON p.People_ID = pp.People_ID ORDER BY pp.Final_Table_Made ASC
SELECT p.Name FROM people p JOIN poker_player pp ON p.People_ID = pp.People_ID ORDER BY pp.Earnings DESC
SELECT Nationality, COUNT(*) AS count FROM people GROUP BY Nationality
SELECT Nationality FROM people GROUP BY Nationality HAVING COUNT(*) >= 2
SELECT COUNT(DISTINCT state) AS state_count FROM AREA_CODE_STATE
SELECT MAX(area_code) AS max_area_code, MIN(area_code) AS min_area_code FROM AREA_CODE_STATE
SELECT contestant_name FROM CONTESTANTS WHERE contestant_name != 'Jessie Alloway'
SELECT c.contestant_number, c.contestant_name FROM CONTESTANTS c JOIN VOTES v ON c.contestant_number = v.contestant_number GROUP BY c.contestant_number, c.contestant_name ORDER BY COUNT(v.vote_id) ASC LIMIT 1
SELECT a.area_code FROM VOTES v JOIN AREA_CODE_STATE a ON v.state = a.state GROUP BY a.area_code ORDER BY COUNT(*) DESC LIMIT 1
SELECT Region, Population FROM country WHERE Name = 'Angola'
SELECT SUM(city.Population) AS total_population FROM city JOIN country ON city.CountryCode = country.Code WHERE city.District = 'Gelderland'
SELECT Name, Population, LifeExpectancy FROM country WHERE Continent = 'Asia' ORDER BY SurfaceArea DESC LIMIT 1
SELECT c.Name  FROM country c  WHERE c.Continent = 'Africa'    AND c.Population < (SELECT MIN(c2.Population) FROM country c2 WHERE c2.Continent = 'Asia')
SELECT DISTINCT city.Name FROM city JOIN country ON city.CountryCode = country.Code JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Continent = 'Asia'   AND countrylanguage.Language = 'Chinese'   AND countrylanguage.IsOfficial = 'T'
SELECT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID GROUP BY c.Conductor_ID, c.Name ORDER BY COUNT(o.Orchestra_ID) DESC LIMIT 1
SELECT Record_Company, COUNT(*) AS orchestra_count FROM orchestra GROUP BY Record_Company
SELECT      o.Record_Company,     COUNT(DISTINCT o.Orchestra_ID) AS orchestra_count FROM orchestra o GROUP BY o.Record_Company ORDER BY orchestra_count DESC LIMIT 1
SELECT o.Orchestra FROM orchestra o LEFT JOIN performance p ON o.Orchestra_ID = p.Orchestra_ID WHERE p.Performance_ID IS NULL
SELECT DISTINCT r1.Record_Company FROM orchestra r1 JOIN orchestra r2 ON r1.Record_Company = r2.Record_Company WHERE r1.Year_of_Founded < 2003 AND r2.Year_of_Founded > 2003
SELECT name, grade FROM Highschooler
SELECT name FROM Highschooler WHERE grade = 10
SELECT grade FROM Highschooler GROUP BY grade HAVING COUNT(*) >= 4
SELECT name FROM Highschooler WHERE ID NOT IN (     SELECT DISTINCT student_id     FROM Friend ) AND ID NOT IN (     SELECT DISTINCT friend_id     FROM Friend )
SELECT h.name FROM Highschooler h JOIN Likes l ON h.ID = l.student_id GROUP BY h.ID, h.name ORDER BY COUNT(*) DESC LIMIT 1
SELECT DISTINCT p.first_name FROM Professionals p WHERE p.first_name NOT IN (SELECT name FROM Dogs) UNION SELECT DISTINCT o.first_name FROM Owners o WHERE o.first_name NOT IN (SELECT name FROM Dogs)
SELECT t.treatment_type_description FROM Treatment_Types t JOIN Treatments tr ON t.treatment_type_code = tr.treatment_type_code GROUP BY t.treatment_type_code, t.treatment_type_description ORDER BY SUM(tr.cost_of_treatment) ASC LIMIT 1
SELECT o.owner_id, o.zip_code FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Treatments t ON d.dog_id = t.dog_id GROUP BY o.owner_id, o.zip_code ORDER BY SUM(t.cost_of_treatment) DESC LIMIT 1
SELECT      t.cost_of_treatment,     tt.treatment_type_description FROM Treatments t JOIN Treatment_Types tt ON t.treatment_type_code = tt.treatment_type_code
SELECT MAX(CAST(age AS INTEGER)) AS oldest_age FROM Dogs
SELECT Name FROM singer ORDER BY Net_Worth_Millions ASC
SELECT Name  FROM singer  ORDER BY Net_Worth_Millions DESC  LIMIT 1
SELECT Citizenship, COUNT(*) AS singer_count FROM singer GROUP BY Citizenship
SELECT DISTINCT s.Name FROM singer s JOIN song so ON s.Singer_ID = so.Singer_ID WHERE so.Sales > 300000
SELECT Citizenship FROM singer WHERE Birth_Year < 1945 INTERSECT SELECT Citizenship FROM singer WHERE Birth_Year > 1955
SELECT COUNT(*) AS total_features FROM Other_Available_Features
SELECT rft.feature_type_name FROM Other_Available_Features oaf JOIN Ref_Feature_Types rft ON oaf.feature_type_code = rft.feature_type_code WHERE oaf.feature_name = 'AirCon'
SELECT DISTINCT rpt.property_type_description FROM Properties p JOIN Ref_Property_Types rpt ON p.property_type_code = rpt.property_type_code
SELECT property_name FROM Properties WHERE (property_type_code = 'House' OR property_type_code = 'Apartment')   AND room_count > 1
