SELECT Song_Name FROM singer WHERE Age > (SELECT AVG(Age) FROM singer)
SELECT Song_Name FROM singer WHERE Age > (SELECT AVG(Age) FROM singer)
SELECT s.Name, s.Capacity FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year >= '2014' GROUP BY s.Stadium_ID ORDER BY COUNT(c.concert_ID) DESC LIMIT 1
SELECT      s.Name,      s.Capacity FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year > '2013' GROUP BY s.Stadium_ID, s.Name, s.Capacity ORDER BY COUNT(c.concert_ID) DESC LIMIT 1
SELECT Year FROM concert GROUP BY Year ORDER BY COUNT(*) DESC LIMIT 1
SELECT Year FROM concert GROUP BY Year ORDER BY COUNT(*) DESC LIMIT 1
SELECT Name FROM stadium EXCEPT SELECT Name FROM stadium WHERE Stadium_ID IN (SELECT Stadium_ID FROM concert)
SELECT Name FROM stadium EXCEPT SELECT Name FROM stadium WHERE Stadium_ID IN (SELECT Stadium_ID FROM concert)
SELECT Country FROM singer WHERE Age > 40 INTERSECT SELECT Country FROM singer WHERE Age < 30
SELECT Name FROM stadium EXCEPT SELECT s.Name FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year = '2014'
SELECT Name FROM stadium EXCEPT SELECT s.Name FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year = '2014'
SELECT DISTINCT s.Name FROM singer s JOIN singer_in_concert sic ON s.Singer_ID = sic.Singer_ID JOIN concert c ON sic.concert_ID = c.concert_ID WHERE c.Year = '2014'
SELECT DISTINCT s.Name FROM singer s JOIN singer_in_concert sic ON s.Singer_ID = sic.Singer_ID JOIN concert c ON sic.concert_ID = c.concert_ID WHERE c.Year = '2014'
SELECT s.Name, s.Location FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year = '2014' INTERSECT SELECT s.Name, s.Location FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year = '2015'
SELECT s.Name, s.Location FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year = '2014' INTERSECT SELECT s.Name, s.Location FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year = '2015'
SELECT COUNT(*)  FROM concert  WHERE Stadium_ID = (     SELECT Stadium_ID      FROM stadium      ORDER BY Capacity DESC      LIMIT 1 )
SELECT COUNT(*)  FROM concert  WHERE concert.Stadium_ID = (     SELECT Stadium_ID      FROM stadium      ORDER BY Capacity DESC      LIMIT 1 )
SELECT COUNT(*) FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Student.Sex = 'F'   AND Pets.PetType = 'dog'
SELECT COUNT(*)  FROM Student  JOIN Has_Pet ON Student.StuID = Has_Pet.StuID  JOIN Pets ON Has_Pet.PetID = Pets.PetID  WHERE Pets.PetType = 'dog'    AND Student.Sex = 'F'
SELECT DISTINCT Student.Fname FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType IN ('cat', 'dog')
SELECT DISTINCT s.Fname FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType IN ('cat', 'dog')
SELECT Student.Fname FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'cat' INTERSECT SELECT Student.Fname FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'dog'
SELECT Student.Fname FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'cat' INTERSECT SELECT Student.Fname FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'dog'
SELECT Student.Major, Student.Age FROM Student EXCEPT SELECT Student.Major, Student.Age FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'cat'
SELECT s.Major, s.Age FROM Student s WHERE s.StuID NOT IN (     SELECT hp.StuID     FROM Has_Pet hp     JOIN Pets p ON hp.PetID = p.PetID     WHERE p.PetType = 'cat' )
SELECT StuID FROM Student EXCEPT SELECT StuID FROM Has_Pet WHERE PetID IN (SELECT PetID FROM Pets WHERE PetType = 'cat')
SELECT StuID FROM Student EXCEPT SELECT StuID FROM Has_Pet JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'cat'
SELECT DISTINCT s.Fname, s.Age FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'dog' EXCEPT SELECT s.Fname, s.Age FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'cat'
SELECT DISTINCT s.Fname FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'dog' EXCEPT SELECT DISTINCT s.Fname FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'cat'
SELECT s.LName FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'cat' AND p.pet_age = 3
SELECT Student.LName FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'cat' AND Pets.pet_age = 3
SELECT AVG(Student.Age) FROM Student WHERE Student.StuID NOT IN (     SELECT Has_Pet.StuID     FROM Has_Pet )
SELECT AVG(CAST(Student.Age AS REAL)) FROM Student WHERE Student.StuID NOT IN (     SELECT DISTINCT StuID     FROM Pets )
SELECT c.Model  FROM car_names c  JOIN cars_data d ON c.MakeId = d.Id  WHERE d.Horsepower = (SELECT MIN(Horsepower) FROM cars_data WHERE Horsepower IS NOT NULL)
SELECT m.Model FROM model_list m WHERE m.ModelId = (     SELECT c.Id     FROM cars_data c     WHERE CAST(c.Horsepower AS REAL) = (         SELECT MIN(CAST(c2.Horsepower AS REAL))         FROM cars_data c2         WHERE c2.Horsepower IS NOT NULL     )     LIMIT 1 )
SELECT c.Model FROM car_names c JOIN cars_data d ON c.MakeId = d.Id WHERE d.Weight < (SELECT AVG(CAST(Weight AS REAL)) FROM cars_data)
SELECT m.Model FROM model_list m JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Weight < (SELECT AVG(CAST(cd2.Weight AS REAL)) FROM cars_data cd2)
SELECT DISTINCT Maker  FROM car_makers  WHERE Id IN (     SELECT DISTINCT Maker      FROM cars_data      WHERE Year = 1970 )
SELECT DISTINCT FullName FROM car_makers
SELECT      cn.Make,     cd.Year AS production_time FROM cars_data cd JOIN car_names cn ON cd.Id = cn.MakeId WHERE cd.Year = (SELECT MIN(Year) FROM cars_data)
SELECT      cm.Maker,     cd.Year FROM cars_data cd JOIN car_names cn ON cd.Id = cn.MakeId JOIN model_list ml ON cn.Model = ml.Model JOIN car_makers cm ON ml.Maker = cm.Id WHERE cd.Year = (     SELECT MIN(Year) FROM cars_data ) LIMIT 1
SELECT DISTINCT model_list.Model FROM cars_data JOIN car_names ON cars_data.Id = car_names.MakeId JOIN model_list ON car_names.Model = model_list.Model WHERE cars_data.Year > 1980
SELECT DISTINCT m.Model FROM model_list m JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Year > 1980
SELECT      cont.Continent AS continent_name,     COUNT(car.Id) AS maker_count FROM car_makers car JOIN countries cou ON car.Country = cou.CountryId JOIN continents cont ON cou.Continent = cont.ContId GROUP BY cont.Continent
SELECT c.Continent, COUNT(cm.Id) AS car_maker_count FROM continents c LEFT JOIN car_makers cm ON c.ContId = cm.Country GROUP BY c.Continent, c.ContId
SELECT c.CountryName FROM countries c JOIN car_makers cm ON c.CountryId = cm.Country GROUP BY c.CountryName ORDER BY COUNT(cm.Id) DESC LIMIT 1
SELECT c.CountryName FROM countries c JOIN car_makers cm ON c.CountryId = cm.Country GROUP BY c.CountryName ORDER BY COUNT(cm.Id) DESC LIMIT 1
SELECT COUNT(*)  FROM model_list  JOIN car_makers ON model_list.Maker = car_makers.Id  WHERE car_makers.Country = 'usa'
SELECT COUNT(*)  FROM model_list  JOIN car_makers ON model_list.Maker = car_makers.Id  WHERE car_makers.Country = '1'
SELECT c.CountryName FROM countries c JOIN continents co ON c.Continent = co.ContId JOIN car_makers cm ON c.CountryId = cm.Country WHERE co.Continent = 'Europe' GROUP BY c.CountryName HAVING COUNT(cm.Id) >= 3
SELECT c.CountryName FROM countries c JOIN car_makers cm ON c.CountryId = cm.Country WHERE c.Continent = 3 GROUP BY c.CountryName HAVING COUNT(cm.Id) >= 3
SELECT MAX(CAST(cars_data.Horsepower AS REAL)) AS max_horsepower, car_names.Make FROM cars_data JOIN car_names ON cars_data.Id = car_names.MakeId WHERE cars_data.Cylinders = 3 GROUP BY car_names.Make
SELECT MAX(cars_data.Horsepower) AS max_horsepower, car_names.Make FROM cars_data JOIN car_names ON cars_data.Id = car_names.MakeId WHERE cars_data.Cylinders = 3
SELECT Model FROM (     SELECT car_names.Model, CAST(cars_data.MPG AS REAL) AS MPG_val     FROM cars_data     JOIN car_names ON cars_data.Id = car_names.MakeId ) ORDER BY MPG_val DESC LIMIT 1
SELECT Id  FROM cars_data  WHERE CAST(MPG AS REAL) = (SELECT MAX(CAST(MPG AS REAL)) FROM cars_data)
SELECT Model FROM (     SELECT cn.Model, COUNT(DISTINCT cn.Make) AS cnt     FROM car_names cn     JOIN model_list ml ON cn.Model = ml.Model     GROUP BY cn.Model     ORDER BY cnt DESC     LIMIT 1 ) AS sub
SELECT COUNT(*) AS version_count FROM car_names cn JOIN cars_data cd ON cn.MakeId = cd.Id GROUP BY cn.Model ORDER BY version_count DESC LIMIT 1
SELECT DISTINCT m.Model FROM model_list m JOIN car_makers cm ON m.Maker = cm.Id JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cm.FullName = 'General Motors' UNION SELECT DISTINCT m.Model FROM model_list m JOIN car_makers cm ON m.Maker = cm.Id JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Weight > 3500
SELECT DISTINCT m.Model FROM model_list m JOIN car_makers cm ON m.Maker = cm.Id JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cm.FullName = 'General Motors' UNION SELECT DISTINCT m.Model FROM model_list m JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Weight > 3500
SELECT Cylinders FROM cars_data WHERE Id = (     SELECT Id     FROM cars_data     WHERE Id IN (         SELECT MakeId         FROM car_names         WHERE Model = 'volvo'     )     ORDER BY Accelerate ASC     LIMIT 1 )
SELECT Cylinders  FROM cars_data  WHERE Id IN (     SELECT Id      FROM cars_data      WHERE Id IN (         SELECT MakeId          FROM car_names          WHERE Model LIKE '%volvo%'     )      ORDER BY Accelerate ASC      LIMIT 1 )
SELECT COUNT(*)  FROM cars_data  WHERE CAST(Accelerate AS REAL) > (     SELECT CAST(Accelerate AS REAL)      FROM cars_data      WHERE CAST(Horsepower AS REAL) = (         SELECT MAX(CAST(Horsepower AS REAL))          FROM cars_data     )     LIMIT 1 )
SELECT COUNT(*)  FROM cars_data  WHERE Accelerate > (     SELECT Accelerate      FROM cars_data      WHERE CAST(Horsepower AS REAL) = (         SELECT MAX(CAST(Horsepower AS REAL))          FROM cars_data     )     LIMIT 1 )
SELECT c.Model FROM car_names c JOIN cars_data d ON c.MakeId = d.Id WHERE d.Cylinders = 4 ORDER BY CAST(d.Horsepower AS REAL) DESC LIMIT 1
SELECT cn.Model FROM car_names cn JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Cylinders = 4 ORDER BY CAST(cd.Horsepower AS REAL) DESC LIMIT 1
SELECT c.Id AS makeid, c.MPG AS make_name FROM cars_data c WHERE c.Horsepower > (SELECT MIN(Horsepower) FROM cars_data)   AND c.Cylinders <= 3
-- Find cars with less than 4 cylinders, excluding those with minimum horsepower SELECT cn.MakeId, cn.Make FROM car_names cn JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Cylinders < 4 EXCEPT SELECT cn.MakeId, cn.Make FROM car_names cn JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Horsepower = (     SELECT MIN(CAST(Horsepower AS REAL))     FROM cars_data     WHERE Horsepower IS NOT NULL AND Horsepower != '' )
SELECT m.Model FROM model_list m JOIN car_makers cm ON m.Maker = cm.Id JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Weight < 3500 EXCEPT SELECT m.Model FROM model_list m JOIN car_makers cm ON m.Maker = cm.Id WHERE cm.FullName = 'Ford Motor Company'
SELECT DISTINCT m.Model FROM model_list m JOIN car_makers cm ON m.Maker = cm.Id JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cd.Weight < 3500 EXCEPT SELECT DISTINCT m2.Model FROM model_list m2 JOIN car_makers cm2 ON m2.Maker = cm2.Id WHERE cm2.FullName = 'Ford Motor Company'
SELECT CountryName FROM countries EXCEPT SELECT Country FROM car_makers
SELECT CountryName FROM countries EXCEPT SELECT Country FROM car_makers
SELECT      cm.Id,      cm.Maker FROM car_makers cm JOIN model_list ml ON cm.Id = ml.Maker GROUP BY cm.Id, cm.Maker HAVING COUNT(ml.Model) >= 2
SELECT      cm.Id,     cm.Maker FROM car_makers cm INNER JOIN model_list ml ON cm.Id = ml.Maker GROUP BY cm.Id, cm.Maker HAVING COUNT(ml.ModelId) >= 2
SELECT      c.CountryId AS id,     c.CountryName AS name FROM countries c INNER JOIN car_makers cm ON c.CountryId = cm.Country GROUP BY c.CountryId, c.CountryName HAVING COUNT(cm.Id) > 3      OR c.CountryId IN (         SELECT cm2.Country         FROM car_makers cm2         WHERE cm2.Maker = 'fiat' OR cm2.FullName = 'fiat'     )
-- Countries with more than 3 car makers SELECT c.CountryId AS id, c.CountryName AS name FROM countries c JOIN car_makers cm ON c.CountryId = cm.Country GROUP BY c.CountryId, c.CountryName HAVING COUNT(cm.Id) > 3 UNION -- Countries that produce fiat model (via car_makers) SELECT c.CountryId AS id, c.CountryName AS name FROM countries c JOIN car_makers cm ON c.CountryId = cm.Country WHERE cm.Maker = 'fiat' OR cm.FullName = 'fiat'
SELECT COUNT(*)  FROM flights  JOIN airports AS src ON flights.SourceAirport = src.AirportCode  JOIN airports AS dst ON flights.DestAirport = dst.AirportCode  WHERE src.City = 'Aberdeen' AND dst.City = 'Ashley'
SELECT COUNT(*)  FROM flights  JOIN airports AS src ON flights.SourceAirport = src.AirportCode  JOIN airports AS dst ON flights.DestAirport = dst.AirportCode  WHERE src.City = 'Aberdeen' AND dst.City = 'Ashley'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.DestAirport = airports.AirportCode  JOIN airlines ON flights.Airline = airlines.uid  WHERE airlines.Airline = 'United Airlines'    AND airports.City = 'Aberdeen'
SELECT COUNT(*)  FROM flights  JOIN airlines ON flights.Airline = airlines.uid  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airlines.Airline = 'United Airlines'    AND airports.City = 'Aberdeen'
SELECT a.City FROM flights f JOIN airports a ON f.DestAirport = a.AirportCode GROUP BY a.City ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.City FROM airports a WHERE a.AirportCode = (     SELECT f.DestAirport     FROM flights f     GROUP BY f.DestAirport     ORDER BY COUNT(*) DESC     LIMIT 1 )
SELECT a.City FROM flights f JOIN airports a ON f.SourceAirport = a.AirportCode GROUP BY a.City ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.City FROM flights f JOIN airports a ON f.SourceAirport = a.AirportCode GROUP BY a.City ORDER BY COUNT(*) DESC LIMIT 1
SELECT AirportCode FROM (     SELECT a.AirportCode, COUNT(*) AS cnt     FROM airports a     JOIN flights f ON a.AirportCode = f.DestAirport     GROUP BY a.AirportCode     ORDER BY cnt DESC     LIMIT 1 ) AS sub
SELECT AirportCode FROM (     SELECT a.AirportCode, COUNT(*) AS cnt     FROM airports a     JOIN flights f ON a.AirportCode = f.SourceAirport OR a.AirportCode = f.DestAirport     GROUP BY a.AirportCode     ORDER BY cnt DESC     LIMIT 1 ) AS sub
SELECT AirportCode FROM (     SELECT a.AirportCode, COUNT(*) AS cnt     FROM airports a     JOIN flights f ON a.AirportCode = f.SourceAirport OR a.AirportCode = f.DestAirport     GROUP BY a.AirportCode     ORDER BY cnt ASC     LIMIT 1 ) AS sub
SELECT AirportCode FROM (     SELECT a.AirportCode, COUNT(f.FlightNo) AS cnt     FROM airports a     LEFT JOIN flights f ON a.AirportCode = f.SourceAirport OR a.AirportCode = f.DestAirport     GROUP BY a.AirportCode     ORDER BY cnt ASC     LIMIT 1 ) AS sub
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.Airline ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.Airline ORDER BY COUNT(*) DESC LIMIT 1
SELECT      a.Abbreviation,     a.Country FROM airlines a JOIN (     SELECT Airline, COUNT(*) AS flight_count     FROM flights     GROUP BY Airline     ORDER BY flight_count ASC     LIMIT 1 ) f ON a.uid = f.Airline
SELECT a.Abbreviation, a.Country FROM airlines a WHERE a.uid = (     SELECT f.Airline     FROM flights f     GROUP BY f.Airline     ORDER BY COUNT(*) ASC     LIMIT 1 )
SELECT Airline FROM flights WHERE SourceAirport = 'APG' INTERSECT SELECT Airline FROM flights WHERE SourceAirport = 'CVO'
SELECT Airline FROM flights WHERE SourceAirport = 'APG' INTERSECT SELECT Airline FROM flights WHERE SourceAirport = 'CVO'
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'CVO' EXCEPT SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'APG'
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'CVO' EXCEPT SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'APG'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airports.City = 'Aberdeen' OR airports.City = 'Abilene'
SELECT COUNT(*) FROM flights WHERE DestAirport IN (SELECT AirportCode FROM airports WHERE City = 'Aberdeen') UNION SELECT COUNT(*) FROM flights WHERE DestAirport IN (SELECT AirportCode FROM airports WHERE City = 'Abilene')
SELECT AirportName FROM airports EXCEPT SELECT AirportName FROM airports WHERE AirportCode IN (     SELECT SourceAirport FROM flights     UNION     SELECT DestAirport FROM flights )
SELECT AirportCode FROM airports EXCEPT SELECT SourceAirport FROM flights EXCEPT SELECT DestAirport FROM flights
SELECT Name FROM shop WHERE Number_products > (SELECT AVG(CAST(Number_products AS REAL)) FROM shop)
SELECT s.Name FROM shop s WHERE s.Number_products > (SELECT AVG(CAST(s2.Number_products AS REAL)) FROM shop s2)
SELECT e.Name FROM employee e WHERE e.Employee_ID = (     SELECT ev.Employee_ID     FROM evaluation ev     GROUP BY ev.Employee_ID     ORDER BY COUNT(*) DESC     LIMIT 1 )
SELECT e.Name FROM employee e JOIN (     SELECT Employee_ID, COUNT(*) AS cnt     FROM evaluation     GROUP BY Employee_ID     ORDER BY cnt DESC     LIMIT 1 ) sub ON e.Employee_ID = sub.Employee_ID
SELECT e.Name FROM employee e JOIN evaluation ev ON e.Employee_ID = ev.Employee_ID WHERE ev.Bonus = (SELECT MAX(Bonus) FROM evaluation)
SELECT e.Name FROM employee e WHERE e.Employee_ID = (     SELECT ev.Employee_ID     FROM evaluation ev     ORDER BY ev.Bonus DESC     LIMIT 1 )
SELECT Name FROM employee WHERE Employee_ID NOT IN (     SELECT Employee_ID     FROM evaluation )
SELECT Name  FROM employee  EXCEPT  SELECT e.Name  FROM employee e  JOIN evaluation ev ON e.Employee_ID = ev.Employee_ID
SELECT s.Name FROM shop s WHERE s.Shop_ID = (     SELECT h.Shop_ID     FROM hiring h     GROUP BY h.Shop_ID     ORDER BY COUNT(h.Employee_ID) DESC     LIMIT 1 )
SELECT s.Name FROM shop s JOIN hiring h ON s.Shop_ID = h.Shop_ID GROUP BY s.Shop_ID, s.Name ORDER BY COUNT(h.Employee_ID) DESC LIMIT 1
SELECT Name FROM shop EXCEPT SELECT s.Name FROM shop s JOIN hiring h ON s.Shop_ID = h.Shop_ID
SELECT Name FROM shop EXCEPT SELECT s.Name FROM shop s INNER JOIN hiring h ON s.Shop_ID = h.Shop_ID
SELECT shop.District FROM shop WHERE shop.Number_products < 3000 INTERSECT SELECT shop.District FROM shop WHERE shop.Number_products > 10000
SELECT District FROM shop WHERE Number_products < 3000 INTERSECT SELECT District FROM shop WHERE Number_products > 10000
SELECT      t.Template_ID AS id,     t.Template_Type_Code AS type_code FROM Templates t WHERE t.Template_ID = (     SELECT d.Template_ID     FROM Documents d     GROUP BY d.Template_ID     ORDER BY COUNT(d.Document_ID) DESC     LIMIT 1 )
SELECT t.Template_ID, t.Template_Type_Code FROM Templates t WHERE t.Template_ID = (     SELECT d.Template_ID     FROM Documents d     GROUP BY d.Template_ID     ORDER BY COUNT(d.Document_ID) DESC     LIMIT 1 )
SELECT Template_ID  FROM Templates  EXCEPT  SELECT Template_ID  FROM Documents
SELECT Template_ID FROM Templates EXCEPT SELECT Template_ID FROM Documents WHERE Template_ID IS NOT NULL
SELECT t.Template_Type_Code FROM Templates t GROUP BY t.Template_Type_Code ORDER BY COUNT(t.Template_ID) DESC LIMIT 1
SELECT Ref_Template_Types.Template_Type_Code FROM Templates JOIN Ref_Template_Types ON Templates.Template_Type_Code = Ref_Template_Types.Template_Type_Code GROUP BY Ref_Template_Types.Template_Type_Code ORDER BY COUNT(Templates.Template_ID) DESC LIMIT 1
SELECT Ref_Template_Types.Template_Type_Code FROM Documents JOIN Templates ON Documents.Template_ID = Templates.Template_ID JOIN Ref_Template_Types ON Templates.Template_Type_Code = Ref_Template_Types.Template_Type_Code GROUP BY Ref_Template_Types.Template_Type_Code ORDER BY COUNT(Documents.Document_ID) DESC LIMIT 1
SELECT      rtt.Template_Type_Code FROM      Documents d     JOIN Templates t ON d.Template_ID = t.Template_ID     JOIN Ref_Template_Types rtt ON t.Template_Type_Code = rtt.Template_Type_Code GROUP BY      rtt.Template_Type_Code ORDER BY      COUNT(d.Document_ID) DESC LIMIT 1
SELECT Ref_Template_Types.Template_Type_Code FROM Ref_Template_Types EXCEPT SELECT DISTINCT Templates.Template_Type_Code FROM Documents JOIN Templates ON Documents.Template_ID = Templates.Template_ID
SELECT Template_Type_Code  FROM Ref_Template_Types  EXCEPT  SELECT Template_Type_Code  FROM Templates
SELECT d.Document_ID, d.Document_Name FROM Documents d WHERE d.Document_ID = (     SELECT p.Document_ID     FROM Paragraphs p     GROUP BY p.Document_ID     ORDER BY COUNT(p.Paragraph_ID) DESC     LIMIT 1 )
SELECT d.Document_ID, d.Document_Name FROM Documents d WHERE d.Document_ID = (     SELECT p.Document_ID     FROM Paragraphs p     GROUP BY p.Document_ID     ORDER BY COUNT(p.Paragraph_ID) DESC     LIMIT 1 )
SELECT Document_ID FROM (     SELECT Documents.Document_ID, COUNT(Paragraphs.Paragraph_ID) AS cnt     FROM Documents     LEFT JOIN Paragraphs ON Documents.Document_ID = Paragraphs.Document_ID     GROUP BY Documents.Document_ID ) ORDER BY cnt ASC LIMIT 1
SELECT Document_ID FROM (     SELECT Documents.Document_ID, COUNT(Paragraphs.Paragraph_ID) AS cnt     FROM Documents     INNER JOIN Paragraphs ON Documents.Document_ID = Paragraphs.Document_ID     GROUP BY Documents.Document_ID     ORDER BY cnt ASC     LIMIT 1 ) AS sub
SELECT Documents.Document_ID FROM Documents JOIN Paragraphs ON Documents.Document_ID = Paragraphs.Document_ID WHERE Paragraphs.Paragraph_Text = 'Brazil' INTERSECT SELECT Documents.Document_ID FROM Documents JOIN Paragraphs ON Documents.Document_ID = Paragraphs.Document_ID WHERE Paragraphs.Paragraph_Text = 'Ireland'
SELECT DISTINCT d.Document_ID FROM Documents d JOIN Paragraphs p ON d.Document_ID = p.Document_ID WHERE p.Paragraph_Text = 'Brazil' INTERSECT SELECT DISTINCT d.Document_ID FROM Documents d JOIN Paragraphs p ON d.Document_ID = p.Document_ID WHERE p.Paragraph_Text = 'Ireland'
SELECT teacher.Hometown FROM teacher JOIN course_arrange ON teacher.Teacher_ID = course_arrange.Teacher_ID JOIN course ON course_arrange.Course_ID = course.Course_ID GROUP BY teacher.Hometown ORDER BY COUNT(*) DESC LIMIT 1
SELECT teacher.Hometown FROM teacher GROUP BY teacher.Hometown ORDER BY COUNT(*) DESC LIMIT 1
SELECT t.Name, c.Course FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID JOIN course c ON ca.Course_ID = c.Course_ID ORDER BY t.Name ASC
SELECT t.Name, c.Course FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID JOIN course c ON ca.Course_ID = c.Course_ID ORDER BY t.Name ASC
SELECT t.Name FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID JOIN course c ON ca.Course_ID = c.Course_ID WHERE c.Course = 'Math'
SELECT teacher.Name FROM teacher JOIN course_arrange ON teacher.Teacher_ID = course_arrange.Teacher_ID JOIN course ON course_arrange.Course_ID = course.Course_ID WHERE course.Course = 'Math'
SELECT Name FROM teacher EXCEPT SELECT Name FROM teacher WHERE Teacher_ID IN (SELECT Teacher_ID FROM course_arrange)
SELECT Name FROM teacher EXCEPT SELECT Name FROM teacher WHERE Teacher_ID IN (SELECT Teacher_ID FROM course_arrange)
SELECT Name FROM museum WHERE Num_of_Staff > (     SELECT MIN(Num_of_Staff)     FROM museum     WHERE Open_Year = '2010' )
SELECT v.ID, v.Name, v.Level_of_membership FROM visitor v WHERE v.ID = (     SELECT vi.visitor_ID     FROM visit vi     GROUP BY vi.visitor_ID     ORDER BY SUM(vi.Total_spent) DESC     LIMIT 1 )
SELECT m.Museum_ID AS id, m.Name AS name FROM museum m WHERE m.Museum_ID = (     SELECT v.Museum_ID     FROM visit v     GROUP BY v.Museum_ID     ORDER BY COUNT(*) DESC     LIMIT 1 )
SELECT Name FROM museum EXCEPT SELECT Name FROM museum WHERE Museum_ID IN (SELECT Museum_ID FROM visit)
SELECT v.Name, v.Age FROM visitor v WHERE v.ID = (     SELECT visitor_ID     FROM visit     ORDER BY Num_of_Ticket DESC     LIMIT 1 )
SELECT v.Name FROM visitor v JOIN visit vi ON v.ID = vi.visitor_ID JOIN museum m ON vi.Museum_ID = m.Museum_ID WHERE m.Open_Year < '2009' INTERSECT SELECT v.Name FROM visitor v JOIN visit vi ON v.ID = vi.visitor_ID JOIN museum m ON vi.Museum_ID = m.Museum_ID WHERE m.Open_Year > '2011'
SELECT COUNT(*)  FROM visitor  WHERE visitor.ID NOT IN (     SELECT visit.visitor_ID      FROM visit      INNER JOIN museum ON visit.Museum_ID = museum.Museum_ID      WHERE museum.Open_Year > '2010' )
SELECT winner_name FROM matches WHERE year = 2013 INTERSECT SELECT winner_name FROM matches WHERE year = 2016
SELECT players.first_name || ' ' || players.last_name AS player_name FROM matches JOIN players ON matches.winner_id = players.player_id WHERE matches.year = 2013 INTERSECT SELECT players.first_name || ' ' || players.last_name AS player_name FROM matches JOIN players ON matches.winner_id = players.player_id WHERE matches.year = 2016
SELECT p.country_code, p.first_name FROM players p WHERE p.player_id IN (     SELECT winner_id FROM matches WHERE tourney_name = 'WTA Championships'     INTERSECT     SELECT winner_id FROM matches WHERE tourney_name = 'Australian Open' )
SELECT p.first_name, p.country_code FROM players p JOIN matches m ON p.player_id = m.winner_id WHERE m.tourney_name = 'WTA Championships' INTERSECT SELECT p.first_name, p.country_code FROM players p JOIN matches m ON p.player_id = m.winner_id WHERE m.tourney_name = 'Australian Open'
SELECT p.first_name, p.country_code FROM players p WHERE p.player_id = (     SELECT r.player_id     FROM rankings r     GROUP BY r.player_id     ORDER BY SUM(r.tours) DESC     LIMIT 1 )
SELECT p.first_name, p.country_code FROM players p JOIN rankings r ON p.player_id = r.player_id WHERE r.tours = (SELECT MAX(tours) FROM rankings) ORDER BY r.tours DESC LIMIT 1
SELECT year FROM matches GROUP BY year ORDER BY COUNT(*) DESC LIMIT 1
SELECT      year,     COUNT(*) AS match_count FROM matches GROUP BY year ORDER BY match_count DESC LIMIT 1
SELECT      w.winner_name,     w.winner_rank_points FROM matches w GROUP BY w.winner_id ORDER BY COUNT(*) DESC LIMIT 1
-- Find the winner with the most wins, then get their name and rank points SELECT      p.first_name || ' ' || p.last_name AS winner_name,     r.ranking_points FROM players p JOIN (     SELECT winner_id, COUNT(*) AS win_count     FROM matches     GROUP BY winner_id     ORDER BY win_count DESC     LIMIT 1 ) top_winner ON p.player_id = top_winner.winner_id JOIN rankings r ON p.player_id = r.player_id ORDER BY r.ranking_points DESC LIMIT 1
SELECT w.winner_name FROM matches w WHERE w.tourney_name = 'Australian Open' ORDER BY w.winner_rank_points DESC LIMIT 1
SELECT w.winner_name FROM matches w WHERE w.tourney_name = 'Australian Open' ORDER BY w.winner_rank_points DESC LIMIT 1
SELECT players.country_code FROM players GROUP BY players.country_code ORDER BY COUNT(players.player_id) DESC LIMIT 1
SELECT country_code FROM (     SELECT country_code, COUNT(player_id) AS cnt     FROM players     GROUP BY country_code     ORDER BY cnt DESC     LIMIT 1 ) AS sub
SELECT      p.first_name,     p.country_code,     p.birth_date FROM players p JOIN matches m ON p.player_id = m.winner_id WHERE m.winner_rank_points = (     SELECT MAX(winner_rank_points) FROM matches )
SELECT      p.first_name,     p.country_code,     p.birth_date FROM players p JOIN matches m ON p.player_id = m.winner_id WHERE m.winner_rank_points = (     SELECT MAX(winner_rank_points) FROM matches ) ORDER BY m.winner_rank_points DESC LIMIT 1
SELECT b.id, b.name FROM battle b JOIN death d ON b.id = d.caused_by_ship_id GROUP BY b.id, b.name HAVING SUM(d.killed) > 10
SELECT ship.id, ship.name FROM ship JOIN death ON ship.id = death.caused_by_ship_id GROUP BY ship.id, ship.name ORDER BY SUM(death.injured) DESC LIMIT 1
SELECT COUNT(*) FROM battle EXCEPT SELECT COUNT(*) FROM battle WHERE id IN (     SELECT lost_in_battle FROM ship WHERE tonnage = '225' )
SELECT b.name, b.date FROM battle b WHERE b.id IN (     SELECT id FROM battle WHERE id IN (SELECT id FROM battle WHERE name = 'Lettice')     INTERSECT     SELECT id FROM battle WHERE id IN (SELECT id FROM battle WHERE name = 'HMS Atalanta') )
SELECT b.name, b.result, b.bulgarian_commander FROM battle b WHERE b.id NOT IN (     SELECT s.lost_in_battle     FROM ship s     WHERE s.location = 'English Channel' )
SELECT d.department_name, d.department_id FROM Departments d JOIN Degree_Programs dp ON d.department_id = dp.department_id GROUP BY d.department_id, d.department_name ORDER BY COUNT(dp.degree_program_id) DESC LIMIT 1
SELECT d.department_name, d.department_id FROM Departments d WHERE d.department_id = (     SELECT dp.department_id     FROM Degree_Programs dp     GROUP BY dp.department_id     ORDER BY COUNT(dp.degree_program_id) DESC     LIMIT 1 )
SELECT s.semester_name, s.semester_id FROM Semesters s WHERE s.semester_id = (     SELECT se.semester_id     FROM Student_Enrolment se     GROUP BY se.semester_id     ORDER BY COUNT(se.student_enrolment_id) DESC     LIMIT 1 )
SELECT s.semester_name, s.semester_id FROM Semesters s JOIN Student_Enrolment se ON s.semester_id = se.semester_id GROUP BY s.semester_id, s.semester_name ORDER BY COUNT(se.student_enrolment_id) DESC LIMIT 1
SELECT s.first_name, s.middle_name, s.last_name FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id WHERE dp.degree_summary_name = 'Bachelor'
SELECT s.first_name, s.middle_name, s.last_name FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id WHERE dp.degree_summary_name LIKE '%Bachelor%'
SELECT degree_summary_name FROM Degree_Programs WHERE degree_program_id = (     SELECT degree_program_id     FROM Student_Enrolment     GROUP BY degree_program_id     ORDER BY COUNT(*) DESC     LIMIT 1 )
SELECT dp.degree_summary_name FROM Student_Enrolment se JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id GROUP BY dp.degree_summary_name ORDER BY COUNT(se.student_enrolment_id) DESC LIMIT 1
SELECT      dp.degree_program_id,     dp.degree_summary_name FROM Degree_Programs dp WHERE dp.degree_program_id = (     SELECT se.degree_program_id     FROM Student_Enrolment se     GROUP BY se.degree_program_id     ORDER BY COUNT(se.student_enrolment_id) DESC     LIMIT 1 )
SELECT      Degree_Programs.degree_program_id AS program_id,     Degree_Programs.degree_summary_name AS summary FROM      Student_Enrolment     JOIN Degree_Programs ON Student_Enrolment.degree_program_id = Degree_Programs.degree_program_id GROUP BY      Degree_Programs.degree_program_id,     Degree_Programs.degree_summary_name ORDER BY      COUNT(Student_Enrolment.student_enrolment_id) DESC LIMIT 1
SELECT s.student_id, s.first_name, s.middle_name, s.last_name, cnt AS enrollment_count FROM (     SELECT student_id, COUNT(*) AS cnt     FROM Student_Enrolment     GROUP BY student_id     ORDER BY cnt DESC     LIMIT 1 ) AS max_enroll JOIN Students s ON max_enroll.student_id = s.student_id
SELECT      s.first_name,     s.middle_name,     s.last_name,     s.student_id,     COUNT(se.student_enrolment_id) AS enrollment_count FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id GROUP BY s.student_id ORDER BY enrollment_count DESC LIMIT 1
SELECT semester_name FROM Semesters EXCEPT SELECT s.semester_name FROM Semesters s JOIN Student_Enrolment se ON s.semester_id = se.semester_id
SELECT semester_name FROM Semesters EXCEPT SELECT semester_name FROM Semesters s JOIN Student_Enrolment se ON s.semester_id = se.semester_id
SELECT c.course_name FROM Courses c WHERE c.course_id = (     SELECT sec.course_id     FROM Student_Enrolment_Courses sec     GROUP BY sec.course_id     ORDER BY COUNT(sec.student_course_id) DESC     LIMIT 1 )
SELECT c.course_name FROM Courses c JOIN Student_Enrolment_Courses sec ON c.course_id = sec.course_id GROUP BY c.course_id, c.course_name ORDER BY COUNT(sec.student_course_id) DESC LIMIT 1
SELECT s.last_name FROM Students s JOIN Addresses a ON s.current_address_id = a.address_id WHERE a.state_province_county = 'North Carolina'   AND s.date_first_registered IS NULL
SELECT last_name  FROM Students  WHERE permanent_address_id IN (     SELECT address_id      FROM Addresses      WHERE state_province_county = 'North Carolina' ) AND student_id NOT IN (     SELECT student_id      FROM Student_Registrations )
SELECT      a.address_id,     a.line_1,     a.line_2,     a.line_3 FROM Addresses a JOIN Students s ON s.permanent_address_id = a.address_id GROUP BY a.address_id, a.line_1, a.line_2, a.line_3 ORDER BY COUNT(s.student_id) DESC LIMIT 1
SELECT      a.address_id,     a.line_1,     a.line_2 FROM Addresses a WHERE a.address_id = (     SELECT address_id     FROM (         SELECT              s.permanent_address_id AS address_id,             COUNT(*) AS cnt         FROM Students s         GROUP BY s.permanent_address_id         UNION ALL         SELECT              s.current_address_id AS address_id,             COUNT(*) AS cnt         FROM Students s         GROUP BY s.current_address_id     ) AS combined     GROUP BY address_id     ORDER BY SUM(cnt) DESC     LIMIT 1 )
SELECT      tc.student_course_id AS course_enrollment_id,     COUNT(tc.transcript_id) AS transcript_count FROM Transcript_Contents tc JOIN Transcripts t ON tc.transcript_id = t.transcript_id GROUP BY tc.student_course_id ORDER BY transcript_count DESC LIMIT 1
SELECT      MAX(cnt) AS max_appearances,     student_course_id FROM (     SELECT          SEC.student_course_id,         COUNT(DISTINCT TC.transcript_id) AS cnt     FROM Student_Enrolment_Courses SEC     JOIN Transcript_Contents TC ON SEC.student_course_id = TC.student_course_id     GROUP BY SEC.student_course_id ) sub ORDER BY max_appearances DESC LIMIT 1
SELECT t.transcript_date, t.transcript_id FROM Transcripts t WHERE t.transcript_id = (     SELECT tc.transcript_id     FROM Transcript_Contents tc     GROUP BY tc.transcript_id     ORDER BY COUNT(*) ASC     LIMIT 1 )
SELECT t.transcript_date, t.transcript_id FROM Transcripts t WHERE t.transcript_id = (     SELECT tc.transcript_id     FROM Transcript_Contents tc     GROUP BY tc.transcript_id     ORDER BY COUNT(*) ASC     LIMIT 1 )
SELECT semester_id FROM Student_Enrolment JOIN Degree_Programs ON Student_Enrolment.degree_program_id = Degree_Programs.degree_program_id WHERE Degree_Programs.degree_summary_name = 'Master' INTERSECT SELECT semester_id FROM Student_Enrolment JOIN Degree_Programs ON Student_Enrolment.degree_program_id = Degree_Programs.degree_program_id WHERE Degree_Programs.degree_summary_name = 'Bachelor'
SELECT DISTINCT se.semester_id FROM Student_Enrolment se WHERE EXISTS (     SELECT 1     FROM Student_Enrolment se2     JOIN Degree_Programs dp ON se2.degree_program_id = dp.degree_program_id     WHERE se2.semester_id = se.semester_id     AND dp.other_details LIKE '%Masters%' ) AND EXISTS (     SELECT 1     FROM Student_Enrolment se3     JOIN Degree_Programs dp2 ON se3.degree_program_id = dp2.degree_program_id     WHERE se3.semester_id = se.semester_id     AND dp2.other_details LIKE '%Bachelors%' )
SELECT s.first_name FROM Students s JOIN Addresses a ON s.permanent_address_id = a.address_id WHERE a.country = 'Haiti' UNION SELECT s.first_name FROM Students s WHERE s.cell_mobile_number = '09700166582'
SELECT first_name FROM Students  JOIN Addresses ON Students.permanent_address_id = Addresses.address_id  WHERE Addresses.country = 'Haiti' UNION SELECT first_name FROM Students  WHERE Students.cell_mobile_number = '09700166582'
SELECT      Country,     COUNT(*) AS channel_count FROM TV_Channel GROUP BY Country ORDER BY channel_count DESC LIMIT 1
SELECT Country, COUNT(*) AS channel_count FROM TV_Channel GROUP BY Country ORDER BY channel_count DESC LIMIT 1
SELECT Language, channel_count FROM (     SELECT Language, COUNT(DISTINCT id) AS channel_count     FROM TV_Channel     GROUP BY Language ) ORDER BY channel_count ASC LIMIT 1
SELECT      Language,     COUNT(*) AS channel_count FROM TV_Channel GROUP BY Language HAVING COUNT(*) = (     SELECT MIN(cnt)     FROM (         SELECT COUNT(*) AS cnt         FROM TV_Channel         GROUP BY Language     ) AS sub ) ORDER BY channel_count ASC LIMIT 1
SELECT DISTINCT TV_Channel.Country FROM TV_Channel WHERE TV_Channel.id NOT IN (     SELECT Cartoon.Channel     FROM Cartoon     WHERE Cartoon.Written_by = 'Todd Casey' )
SELECT Country FROM TV_Channel EXCEPT SELECT DISTINCT TV_Channel.Country FROM Cartoon JOIN TV_Channel ON Cartoon.Channel = TV_Channel.id WHERE Cartoon.Written_by = 'Todd Casey'
SELECT DISTINCT T.series_name, T.Country FROM TV_Channel T JOIN Cartoon C ON C.Channel = T.id WHERE C.Directed_by = 'Ben Jones' OR C.Directed_by = 'Michael Chang'
SELECT TV_Channel.series_name, TV_Channel.Country FROM TV_Channel JOIN Cartoon ON TV_Channel.id = Cartoon.Channel WHERE Cartoon.Directed_by = 'Ben Jones' INTERSECT SELECT TV_Channel.series_name, TV_Channel.Country FROM TV_Channel JOIN Cartoon ON TV_Channel.id = Cartoon.Channel WHERE Cartoon.Directed_by = 'Michael Chang'
SELECT TV_Channel.id FROM TV_Channel EXCEPT SELECT DISTINCT Cartoon.Channel FROM Cartoon WHERE Cartoon.Directed_by = 'Ben Jones'
SELECT id FROM TV_Channel EXCEPT SELECT Channel FROM Cartoon WHERE Directed_by = 'Ben Jones'
SELECT Package_Option FROM TV_Channel EXCEPT SELECT Package_Option FROM TV_Channel WHERE id IN (SELECT Channel FROM Cartoon WHERE Directed_by = 'Ben Jones')
SELECT Package_Option FROM TV_Channel EXCEPT SELECT TV_Channel.Package_Option FROM TV_Channel JOIN Cartoon ON TV_Channel.id = Cartoon.Channel WHERE Cartoon.Directed_by = 'Ben Jones'
SELECT people.Birth_Date FROM people JOIN poker_player ON people.People_ID = poker_player.People_ID WHERE poker_player.Earnings = (     SELECT MIN(Earnings) FROM poker_player )
SELECT people.Birth_Date FROM people JOIN poker_player ON people.People_ID = poker_player.People_ID WHERE poker_player.Earnings = (SELECT MIN(Earnings) FROM poker_player)
SELECT p.Money_Rank FROM poker_player p JOIN people pe ON p.People_ID = pe.People_ID WHERE pe.Height = (SELECT MAX(Height) FROM people)
SELECT p.Money_Rank FROM poker_player p JOIN people pe ON p.People_ID = pe.People_ID WHERE pe.Height = (SELECT MAX(Height) FROM people)
SELECT Nationality FROM people GROUP BY Nationality ORDER BY COUNT(*) DESC LIMIT 1
SELECT people.Nationality FROM people GROUP BY people.Nationality ORDER BY COUNT(*) DESC LIMIT 1
SELECT Name FROM people EXCEPT SELECT Name FROM people WHERE People_ID IN (SELECT People_ID FROM poker_player)
SELECT Name FROM people EXCEPT SELECT people.Name FROM people INNER JOIN poker_player ON people.People_ID = poker_player.People_ID
SELECT c.contestant_number, c.contestant_name FROM CONTESTANTS c WHERE c.contestant_number = (     SELECT v.contestant_number     FROM VOTES v     GROUP BY v.contestant_number     ORDER BY COUNT(v.vote_id) ASC     LIMIT 1 )
SELECT COUNT(*)  FROM CONTESTANTS  WHERE contestant_number NOT IN (     SELECT DISTINCT contestant_number      FROM VOTES )
SELECT AREA_CODE_STATE.area_code FROM VOTES JOIN AREA_CODE_STATE ON VOTES.state = AREA_CODE_STATE.state GROUP BY AREA_CODE_STATE.area_code ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.area_code FROM AREA_CODE_STATE a JOIN VOTES v ON a.state = v.state JOIN CONTESTANTS c ON v.contestant_number = c.contestant_number WHERE c.contestant_name = 'Tabatha Gehling' INTERSECT SELECT a.area_code FROM AREA_CODE_STATE a JOIN VOTES v ON a.state = v.state JOIN CONTESTANTS c ON v.contestant_number = c.contestant_number WHERE c.contestant_name = 'Kelly Clauss'
SELECT cl.Language FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE c.Name = 'Aruba' GROUP BY cl.Language ORDER BY MAX(cl.Percentage) DESC LIMIT 1
SELECT countrylanguage.Language FROM country JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Name = 'Aruba'
SELECT Name  FROM country  WHERE Continent = 'Asia'  ORDER BY LifeExpectancy ASC  LIMIT 1
SELECT Name  FROM country  WHERE Continent = 'Asia'  ORDER BY LifeExpectancy ASC  LIMIT 1
SELECT c.Name FROM country c WHERE c.Code = (     SELECT cl.CountryCode     FROM countrylanguage cl     GROUP BY cl.CountryCode     ORDER BY COUNT(cl.Language) DESC     LIMIT 1 )
SELECT c.Name FROM country c WHERE c.Code = (     SELECT cl.CountryCode     FROM countrylanguage cl     GROUP BY cl.CountryCode     ORDER BY COUNT(cl.Language) DESC     LIMIT 1 )
SELECT Continent FROM (     SELECT c.Continent, COUNT(DISTINCT cl.Language) AS lang_count     FROM country c     JOIN countrylanguage cl ON c.Code = cl.CountryCode     GROUP BY c.Continent     ORDER BY lang_count DESC     LIMIT 1 ) AS sub
SELECT      c.Continent,     COUNT(DISTINCT cl.Language) AS language_count FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode GROUP BY c.Continent ORDER BY language_count DESC LIMIT 1
SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'English' INTERSECT SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'French'
SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'English' INTERSECT SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'French'
SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'English' AND cl.IsOfficial = 'T' INTERSECT SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'French' AND cl.IsOfficial = 'T'
SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'English' AND cl.IsOfficial = 'T' INTERSECT SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'French' AND cl.IsOfficial = 'T'
SELECT DISTINCT c.Region FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language IN ('English', 'Dutch')
SELECT DISTINCT c.Region FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language IN ('Dutch', 'English')
SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'English' AND cl.IsOfficial = 'T' UNION SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'Dutch' AND cl.IsOfficial = 'T'
SELECT DISTINCT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language IN ('English', 'Dutch')   AND cl.IsOfficial = 'T'
SELECT cl.Language FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code WHERE c.Continent = 'Asia' GROUP BY cl.Language ORDER BY SUM(cl.Percentage) DESC LIMIT 1
SELECT Language FROM (     SELECT cl.Language, COUNT(DISTINCT c.Code) AS cnt     FROM countrylanguage cl     JOIN country c ON cl.CountryCode = c.Code     WHERE c.Continent = 'Asia'     GROUP BY cl.Language     ORDER BY cnt DESC     LIMIT 1 ) AS sub
SELECT Language FROM countrylanguage WHERE CountryCode IN (     SELECT Code     FROM country     WHERE GovernmentForm = 'Republic' ) GROUP BY Language HAVING COUNT(DISTINCT CountryCode) = 1
SELECT Language FROM countrylanguage WHERE CountryCode IN (     SELECT Code     FROM country     WHERE GovernmentForm = 'Republic' ) GROUP BY Language HAVING COUNT(DISTINCT CountryCode) = 1
SELECT c.Name  FROM city c  JOIN countrylanguage cl ON c.CountryCode = cl.CountryCode  WHERE cl.Language = 'English'  ORDER BY c.Population DESC  LIMIT 1
SELECT city.Name FROM city JOIN countrylanguage ON city.CountryCode = countrylanguage.CountryCode WHERE countrylanguage.Language = 'English' ORDER BY city.Population DESC LIMIT 1
SELECT Name, Population, LifeExpectancy FROM country WHERE Continent = 'Asia' ORDER BY SurfaceArea DESC LIMIT 1
SELECT Name, Population, LifeExpectancy FROM country WHERE Continent = 'Asia' ORDER BY SurfaceArea DESC LIMIT 1
SELECT AVG(c.LifeExpectancy) FROM country c WHERE c.Code NOT IN (     SELECT cl.CountryCode     FROM countrylanguage cl     WHERE cl.Language = 'English' AND cl.IsOfficial = 'T' )
SELECT AVG(country.LifeExpectancy) FROM country WHERE country.Code NOT IN (     SELECT countrylanguage.CountryCode     FROM countrylanguage     WHERE countrylanguage.Language = 'English'     AND countrylanguage.IsOfficial = 'T' )
SELECT SUM(c.Population) FROM country c WHERE c.Code NOT IN (     SELECT cl.CountryCode     FROM countrylanguage cl     WHERE cl.Language = 'English' )
SELECT SUM(Population) FROM country EXCEPT SELECT SUM(Population) FROM country WHERE Code IN (     SELECT CountryCode FROM countrylanguage     WHERE Language = 'English' )
SELECT Name  FROM country  WHERE SurfaceArea > (     SELECT MIN(SurfaceArea)      FROM country      WHERE Continent = 'Europe' )
SELECT c.Name FROM country c WHERE c.SurfaceArea > (     SELECT MIN(c2.SurfaceArea)     FROM country c2     WHERE c2.Continent = 'Europe' )
SELECT Name FROM country WHERE Continent = 'Africa' AND Population < (SELECT MAX(Population) FROM country WHERE Continent = 'Asia')
SELECT Name FROM country WHERE Continent = 'Africa' AND Population < (SELECT MAX(Population) FROM country WHERE Continent = 'Asia')
SELECT c.Name FROM country c WHERE c.Continent = 'Asia'   AND c.Population > (     SELECT MIN(c2.Population)     FROM country c2     WHERE c2.Continent = 'Africa'   )
SELECT c.Name FROM country c WHERE c.Continent = 'Asia'   AND c.Population > (     SELECT MAX(c2.Population)     FROM country c2     WHERE c2.Continent = 'Africa'   )
SELECT country.Code FROM country EXCEPT SELECT countrylanguage.CountryCode FROM countrylanguage WHERE countrylanguage.Language = 'English'
SELECT country.Code FROM country EXCEPT SELECT countrylanguage.CountryCode FROM countrylanguage WHERE countrylanguage.Language = 'English'
SELECT c.Code FROM country c WHERE c.Code NOT IN (     SELECT cl.CountryCode     FROM countrylanguage cl     WHERE cl.Language = 'English' ) AND c.GovernmentForm != 'Republic'
SELECT Code FROM country EXCEPT SELECT CountryCode FROM countrylanguage WHERE Language = 'English' EXCEPT SELECT Code FROM country WHERE GovernmentForm = 'Republic'
SELECT city.Name FROM city WHERE city.CountryCode IN (     SELECT country.Code     FROM country     JOIN countrylanguage ON country.Code = countrylanguage.CountryCode     WHERE country.Continent = 'Europe'     AND countrylanguage.Language = 'English'     AND countrylanguage.IsOfficial = 'F' )
SELECT city.Name FROM city JOIN country ON city.CountryCode = country.Code JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Continent = 'Europe'   AND countrylanguage.Language = 'English'   AND countrylanguage.IsOfficial = 'F'
SELECT DISTINCT city.Name FROM city JOIN country ON city.CountryCode = country.Code JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Continent = 'Asia'   AND countrylanguage.Language = 'Chinese'   AND countrylanguage.IsOfficial = 'T'
SELECT DISTINCT city.Name FROM city JOIN country ON city.CountryCode = country.Code JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Continent = 'Asia'   AND countrylanguage.Language = 'Chinese'   AND countrylanguage.IsOfficial = 'T'
SELECT      city.District,     COUNT(*) AS number_of_cities FROM city WHERE city.Population > (     SELECT AVG(CAST(city.Population AS REAL))     FROM city ) GROUP BY city.District
SELECT      c.District,     COUNT(*) AS city_count FROM city c WHERE c.Population > (     SELECT AVG(c2.Population)     FROM city c2 ) GROUP BY c.District
SELECT SUM(Population) AS total_population, AVG(SurfaceArea) AS average_area FROM country WHERE Continent = 'North America' AND SurfaceArea > 3000
SELECT SUM(Population) AS total_population, AVG(SurfaceArea) AS avg_surface_area FROM country WHERE Continent = 'North America' AND SurfaceArea > 3000
SELECT Language FROM (     SELECT cl.Language, COUNT(DISTINCT cl.CountryCode) AS cnt     FROM countrylanguage cl     GROUP BY cl.Language     ORDER BY cnt DESC     LIMIT 1 ) AS sub
SELECT Language FROM (     SELECT Language, COUNT(DISTINCT CountryCode) AS cnt     FROM countrylanguage     GROUP BY Language ) AS lang_counts ORDER BY cnt DESC LIMIT 1
SELECT COUNT(*)  FROM country c  WHERE c.Code IN (     SELECT cl.CountryCode      FROM countrylanguage cl      WHERE cl.Language = 'Spanish'      AND cl.Percentage = (         SELECT MAX(cl2.Percentage)          FROM countrylanguage cl2          WHERE cl2.CountryCode = cl.CountryCode     ) )
SELECT COUNT(*) AS country_count FROM (     SELECT cl.CountryCode     FROM countrylanguage cl     WHERE cl.Language = 'Spanish'       AND cl.Percentage = (           SELECT MAX(cl2.Percentage)           FROM countrylanguage cl2           WHERE cl2.CountryCode = cl.CountryCode       )     GROUP BY cl.CountryCode ) AS predominant_spanish
SELECT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID GROUP BY c.Conductor_ID, c.Name ORDER BY COUNT(o.Orchestra_ID) DESC LIMIT 1
SELECT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID GROUP BY c.Conductor_ID, c.Name ORDER BY COUNT(o.Orchestra_ID) DESC LIMIT 1
SELECT COUNT(*) AS orchestra_count FROM orchestra GROUP BY orchestra.Record_Company ORDER BY orchestra_count DESC LIMIT 1
SELECT Record_Company FROM orchestra GROUP BY Record_Company ORDER BY COUNT(*) DESC LIMIT 1
SELECT Orchestra  FROM orchestra  EXCEPT  SELECT o.Orchestra  FROM orchestra o  JOIN performance p ON o.Orchestra_ID = p.Orchestra_ID
SELECT Orchestra  FROM orchestra  EXCEPT  SELECT Orchestra  FROM orchestra  WHERE Orchestra_ID IN (     SELECT Orchestra_ID      FROM performance )
SELECT Record_Company FROM orchestra WHERE Year_of_Founded < 2003 INTERSECT SELECT Record_Company FROM orchestra WHERE Year_of_Founded > 2003
SELECT Record_Company FROM orchestra WHERE Year_of_Founded < 2003 INTERSECT SELECT Record_Company FROM orchestra WHERE Year_of_Founded > 2003
SELECT grade FROM Highschooler GROUP BY grade ORDER BY COUNT(*) DESC LIMIT 1
SELECT grade FROM Highschooler GROUP BY grade ORDER BY COUNT(*) DESC LIMIT 1
SELECT h.name FROM Highschooler h WHERE h.ID = (     SELECT f.student_id     FROM Friend f     GROUP BY f.student_id     ORDER BY COUNT(f.friend_id) DESC     LIMIT 1 )
SELECT h.name FROM Highschooler h WHERE h.ID = (     SELECT f.student_id     FROM Friend f     GROUP BY f.student_id     ORDER BY COUNT(f.friend_id) DESC     LIMIT 1 )
SELECT h2.name FROM Highschooler h1 JOIN Friend f ON h1.ID = f.student_id JOIN Highschooler h2 ON f.friend_id = h2.ID WHERE h1.name = 'Kyle'
SELECT h2.name FROM Highschooler h1 JOIN Friend f ON h1.ID = f.student_id JOIN Highschooler h2 ON f.friend_id = h2.ID WHERE h1.name = 'Kyle'
SELECT ID FROM Highschooler EXCEPT SELECT student_id FROM Friend UNION SELECT friend_id FROM Friend
SELECT ID FROM Highschooler EXCEPT SELECT student_id FROM Friend
SELECT name  FROM Highschooler  EXCEPT  SELECT name  FROM Highschooler  WHERE ID IN (     SELECT student_id      FROM Friend )
SELECT name FROM Highschooler WHERE ID NOT IN (     SELECT DISTINCT student_id     FROM Friend )
SELECT ID FROM Highschooler WHERE ID IN (SELECT ID FROM Highschooler WHERE ID IN (SELECT ID FROM Friend)) INTERSECT SELECT ID FROM Highschooler WHERE ID IN (SELECT liked_id FROM Likes)
SELECT ID FROM Highschooler INTERSECT SELECT ID FROM Highschooler
SELECT name FROM Highschooler WHERE ID IN (SELECT ID FROM Friend) INTERSECT SELECT name FROM Highschooler WHERE ID IN (SELECT liked_id FROM Likes)
SELECT name FROM Highschooler WHERE ID IN (SELECT student_id FROM Friend) INTERSECT SELECT name FROM Highschooler WHERE ID IN (SELECT liked_id FROM Likes)
SELECT h.name FROM Highschooler h WHERE h.ID IN (     SELECT l.student_id     FROM Likes l     GROUP BY l.student_id     ORDER BY COUNT(*) DESC     LIMIT 1 )
SELECT name FROM Highschooler WHERE ID = (     SELECT liked_id     FROM Likes     GROUP BY liked_id     ORDER BY COUNT(*) DESC     LIMIT 1 )
SELECT h.name FROM Highschooler h JOIN Friend f ON h.ID = f.student_id WHERE h.grade > 5 GROUP BY h.ID, h.name HAVING COUNT(f.friend_id) >= 2
SELECT h.name FROM Highschooler h JOIN Friend f ON h.ID = f.student_id WHERE h.grade > 5 GROUP BY h.ID, h.name HAVING COUNT(f.friend_id) >= 2
SELECT AVG(CAST(Highschooler.grade AS REAL)) FROM Highschooler WHERE Highschooler.ID IN (     SELECT DISTINCT Friend.ID1     FROM Friend )
SELECT AVG(CAST(grade AS REAL))  FROM Highschooler  WHERE ID IN (     SELECT ID1 FROM Friend     UNION     SELECT ID2 FROM Friend )
SELECT MIN(grade) FROM Highschooler WHERE ID NOT IN (     SELECT student_id FROM Friend     UNION     SELECT friend_id FROM Friend )
SELECT MIN(grade)  FROM Highschooler  WHERE ID NOT IN (SELECT ID1 FROM Friend UNION SELECT ID2 FROM Friend)
SELECT state FROM Owners INTERSECT SELECT state FROM Professionals
SELECT state FROM Owners INTERSECT SELECT state FROM Professionals
SELECT AVG(CAST(Dogs.age AS REAL)) FROM Dogs JOIN Treatments ON Dogs.dog_id = Treatments.dog_id
SELECT AVG(CAST(Dogs.age AS REAL)) FROM Dogs JOIN Treatments ON Dogs.dog_id = Treatments.dog_id
SELECT p.professional_id, p.last_name, p.cell_number FROM Professionals p WHERE p.state = 'Indiana' UNION SELECT p.professional_id, p.last_name, p.cell_number FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id GROUP BY p.professional_id, p.last_name, p.cell_number HAVING COUNT(t.treatment_id) > 2
SELECT professional_id, last_name, cell_number FROM Professionals WHERE state = 'Indiana' UNION SELECT p.professional_id, p.last_name, p.cell_number FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id GROUP BY p.professional_id HAVING COUNT(t.treatment_id) > 2
SELECT d.name FROM Dogs d WHERE d.dog_id NOT IN (     SELECT t.dog_id     FROM Treatments t     GROUP BY t.dog_id     HAVING SUM(t.cost_of_treatment) > 1000 )
SELECT d.name FROM Dogs d WHERE d.owner_id IN (     SELECT o.owner_id     FROM Owners o     JOIN Dogs d2 ON o.owner_id = d2.owner_id     JOIN Treatments t ON d2.dog_id = t.dog_id     GROUP BY o.owner_id     HAVING SUM(t.cost_of_treatment) <= 1000 )
SELECT first_name FROM Professionals EXCEPT SELECT name FROM Dogs
SELECT first_name FROM Professionals UNION SELECT first_name FROM Owners EXCEPT SELECT name FROM Dogs
SELECT professional_id, role_code, email_address FROM Professionals EXCEPT SELECT p.professional_id, p.role_code, p.email_address FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id WHERE t.dog_id IS NOT NULL
SELECT professional_id, role_code, email_address FROM Professionals EXCEPT SELECT p.professional_id, p.role_code, p.email_address FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id
SELECT o.owner_id, o.first_name, o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id GROUP BY o.owner_id, o.first_name, o.last_name ORDER BY COUNT(d.dog_id) DESC LIMIT 1
SELECT o.owner_id, o.first_name, o.last_name FROM Owners o WHERE o.owner_id = (     SELECT d.owner_id     FROM Dogs d     GROUP BY d.owner_id     ORDER BY COUNT(d.dog_id) DESC     LIMIT 1 )
SELECT b.breed_name FROM Breeds b JOIN Dogs d ON b.breed_code = d.breed_code GROUP BY b.breed_code, b.breed_name ORDER BY COUNT(d.dog_id) DESC LIMIT 1
SELECT b.breed_name FROM Dogs d JOIN Breeds b ON d.breed_code = b.breed_code GROUP BY b.breed_code, b.breed_name ORDER BY COUNT(d.dog_id) DESC LIMIT 1
SELECT o.owner_id, o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Treatments t ON d.dog_id = t.dog_id GROUP BY o.owner_id, o.last_name ORDER BY COUNT(t.treatment_id) DESC LIMIT 1
SELECT o.owner_id, o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Treatments t ON d.dog_id = t.dog_id GROUP BY o.owner_id, o.last_name ORDER BY SUM(t.cost_of_treatment) DESC LIMIT 1
SELECT tt.treatment_type_description FROM Treatment_Types tt WHERE tt.treatment_type_code = (     SELECT t.treatment_type_code     FROM Treatments t     GROUP BY t.treatment_type_code     ORDER BY SUM(t.cost_of_treatment) ASC     LIMIT 1 )
SELECT tt.treatment_type_description FROM Treatment_Types tt WHERE tt.treatment_type_code = (     SELECT t.treatment_type_code     FROM Treatments t     GROUP BY t.treatment_type_code     ORDER BY SUM(t.cost_of_treatment) ASC     LIMIT 1 )
SELECT o.owner_id, o.zip_code FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Treatments t ON d.dog_id = t.dog_id GROUP BY o.owner_id, o.zip_code ORDER BY SUM(t.cost_of_treatment) DESC LIMIT 1
SELECT o.owner_id, o.zip_code FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Treatments t ON d.dog_id = t.dog_id GROUP BY o.owner_id, o.zip_code ORDER BY SUM(t.cost_of_treatment) DESC LIMIT 1
SELECT DISTINCT p.first_name, p.last_name FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id WHERE t.cost_of_treatment < (SELECT AVG(cost_of_treatment) FROM Treatments)
SELECT DISTINCT p.first_name, p.last_name FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id WHERE t.cost_of_treatment < (SELECT AVG(CAST(cost_of_treatment AS REAL)) FROM Treatments)
SELECT d.name, t.date_of_treatment FROM Dogs d JOIN Treatments t ON d.dog_id = t.dog_id WHERE d.breed_code = (     SELECT breed_code     FROM Dogs     GROUP BY breed_code     ORDER BY COUNT(*) ASC     LIMIT 1 )
SELECT d.name, t.date_of_treatment FROM Dogs d JOIN Treatments t ON d.dog_id = t.dog_id WHERE d.breed_code = (     SELECT breed_code     FROM Dogs     GROUP BY breed_code     ORDER BY COUNT(*) ASC     LIMIT 1 )
SELECT o.last_name FROM Owners o WHERE o.owner_id = (     SELECT d.owner_id     FROM Dogs d     ORDER BY d.date_of_birth DESC     LIMIT 1 )
SELECT o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id ORDER BY d.date_of_birth DESC LIMIT 1
SELECT COUNT(*)  FROM Dogs  WHERE CAST(age AS REAL) < (SELECT AVG(CAST(age AS REAL)) FROM Dogs)
SELECT COUNT(*)  FROM Dogs  WHERE CAST(age AS REAL) < (SELECT AVG(CAST(age AS REAL)) FROM Dogs)
SELECT COUNT(*)  FROM Dogs  EXCEPT  SELECT COUNT(*)  FROM Dogs  WHERE dog_id IN (     SELECT dog_id      FROM Treatments )
SELECT COUNT(*)  FROM Dogs  EXCEPT SELECT COUNT(DISTINCT dog_id)  FROM Treatments
SELECT COUNT(*) FROM Owners EXCEPT SELECT COUNT(*) FROM Owners WHERE owner_id IN (SELECT DISTINCT owner_id FROM Dogs)
SELECT COUNT(*) FROM (     SELECT owner_id FROM Owners     EXCEPT     SELECT owner_id FROM Dogs ) AS owners_without_dogs
SELECT COUNT(*) FROM Professionals EXCEPT SELECT COUNT(*) FROM Professionals WHERE professional_id IN (SELECT DISTINCT professional_id FROM Treatments)
SELECT COUNT(*) FROM Professionals EXCEPT SELECT COUNT(*) FROM Professionals WHERE professional_id IN (SELECT professional_id FROM Treatments)
SELECT Citizenship FROM singer GROUP BY Citizenship ORDER BY COUNT(*) DESC LIMIT 1
SELECT singer.Citizenship FROM singer GROUP BY singer.Citizenship ORDER BY COUNT(*) DESC LIMIT 1
SELECT Name FROM singer EXCEPT SELECT Name FROM singer WHERE Singer_ID IN (SELECT Singer_ID FROM song)
SELECT Name  FROM singer  WHERE NOT EXISTS (     SELECT 1      FROM song      WHERE song.Singer_ID = singer.Singer_ID )
SELECT Citizenship FROM singer WHERE Birth_Year < 1945 INTERSECT SELECT Citizenship FROM singer WHERE Birth_Year > 1955
SELECT Citizenship FROM singer WHERE Birth_Year < 1945 INTERSECT SELECT Citizenship FROM singer WHERE Birth_Year > 1955
SELECT property_name FROM Properties WHERE (property_type_code = 'House' OR property_type_code = 'Apartment')   AND room_count > 1
