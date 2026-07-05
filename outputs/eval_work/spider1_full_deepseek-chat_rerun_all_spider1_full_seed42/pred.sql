SELECT COUNT(*) AS singer_count FROM singer
SELECT COUNT(*) AS total_singers FROM singer
SELECT Name, Country, Age FROM singer ORDER BY Age DESC
SELECT Name, Country, Age FROM singer ORDER BY Age DESC
SELECT AVG(CAST(Age AS REAL)) AS average_age, MIN(Age) AS minimum_age, MAX(Age) AS maximum_age FROM singer WHERE Country = 'France'
SELECT AVG(CAST(Age AS REAL)) AS average_age, MIN(Age) AS minimum_age, MAX(Age) AS maximum_age FROM singer WHERE Country = 'French'
SELECT Song_Name, Song_release_year FROM singer WHERE Age = (SELECT MIN(Age) FROM singer)
SELECT s.Song_Name AS Name, s.Song_release_year AS release_year FROM singer s WHERE s.Age = (SELECT MIN(Age) FROM singer)
SELECT DISTINCT Country FROM singer WHERE Age > 20
SELECT DISTINCT Country FROM singer WHERE Age > 20
SELECT s.Country, COUNT(*) AS number_of_singers FROM singer s GROUP BY s.Country
SELECT Country, COUNT(*) AS singer_count FROM singer GROUP BY Country
SELECT s.Song_Name FROM singer s WHERE s.Age > (SELECT AVG(s2.Age) FROM singer s2)
SELECT Song_Name  FROM singer  WHERE Age > (SELECT AVG(Age) FROM singer)
SELECT Location, Name FROM stadium WHERE Capacity BETWEEN 5000 AND 10000
SELECT Location, Name FROM stadium WHERE Capacity BETWEEN 5000 AND 10000
SELECT MAX(Capacity) AS max_capacity, AVG(Capacity) AS average_capacity FROM stadium
SELECT AVG(Capacity) AS average_capacity, MAX(Capacity) AS maximum_capacity FROM stadium
SELECT Name, Capacity FROM stadium ORDER BY Average DESC LIMIT 1
SELECT Name, Capacity FROM stadium ORDER BY Average DESC LIMIT 1
SELECT COUNT(*) AS concert_count FROM concert WHERE Year = '2014' OR Year = '2015'
SELECT COUNT(*) AS concert_count FROM concert WHERE Year = '2014' OR Year = '2015'
SELECT      s.Name AS stadium_name,     COUNT(c.concert_ID) AS number_of_concerts FROM stadium s LEFT JOIN concert c ON s.Stadium_ID = c.Stadium_ID GROUP BY s.Stadium_ID, s.Name ORDER BY s.Name
SELECT      s.Name AS stadium_name,     COUNT(c.concert_ID) AS concert_count FROM stadium s LEFT JOIN concert c ON s.Stadium_ID = c.Stadium_ID GROUP BY s.Stadium_ID, s.Name
SELECT s.Name, s.Capacity FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year >= '2014' GROUP BY s.Stadium_ID, s.Name, s.Capacity ORDER BY COUNT(c.concert_ID) DESC LIMIT 1
SELECT      s.Name,     s.Capacity FROM stadium s JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.Year > '2013' GROUP BY s.Stadium_ID, s.Name, s.Capacity ORDER BY COUNT(c.concert_ID) DESC LIMIT 1
SELECT Year FROM concert GROUP BY Year ORDER BY COUNT(*) DESC LIMIT 1
SELECT Year FROM concert GROUP BY Year ORDER BY COUNT(*) DESC LIMIT 1
SELECT s.Name  FROM stadium s  LEFT JOIN concert c ON s.Stadium_ID = c.Stadium_ID  WHERE c.concert_ID IS NULL
SELECT s.Name FROM stadium s LEFT JOIN concert c ON s.Stadium_ID = c.Stadium_ID WHERE c.concert_ID IS NULL
SELECT DISTINCT s1.Country FROM singer s1 JOIN singer s2 ON s1.Country = s2.Country WHERE s1.Age > 40 AND s2.Age < 30
SELECT s.Name FROM stadium s WHERE s.Stadium_ID NOT IN (     SELECT c.Stadium_ID     FROM concert c     WHERE c.Year = '2014' )
SELECT s.Name FROM stadium s WHERE s.Stadium_ID NOT IN (     SELECT c.Stadium_ID     FROM concert c     WHERE c.Year = '2014' )
SELECT      c.concert_Name AS name,     c.Theme AS theme,     COUNT(s.singer_ID) AS number_of_singers FROM concert c LEFT JOIN singer_in_concert s ON c.concert_ID = s.concert_ID GROUP BY c.concert_ID, c.concert_Name, c.Theme
SELECT      c.concert_Name AS name,     c.Theme AS theme,     COUNT(sic.Singer_ID) AS number_of_singers FROM concert c LEFT JOIN singer_in_concert sic ON c.concert_ID = sic.concert_ID GROUP BY c.concert_ID, c.concert_Name, c.Theme ORDER BY c.concert_Name
SELECT s.Name, COUNT(sc.concert_ID) AS number_of_concerts FROM singer s LEFT JOIN singer_in_concert sc ON s.Singer_ID = sc.Singer_ID GROUP BY s.Singer_ID, s.Name
SELECT s.Name, COUNT(sc.concert_ID) AS number_of_concerts FROM singer s LEFT JOIN singer_in_concert sc ON s.Singer_ID = sc.Singer_ID GROUP BY s.Singer_ID, s.Name
SELECT DISTINCT s.Name FROM singer s JOIN singer_in_concert sic ON s.Singer_ID = sic.Singer_ID JOIN concert c ON sic.concert_ID = c.concert_ID WHERE c.Year = '2014'
SELECT DISTINCT s.Name FROM singer s JOIN singer_in_concert sic ON s.Singer_ID = sic.Singer_ID JOIN concert c ON sic.concert_ID = c.concert_ID WHERE c.Year = '2014'
SELECT Name, Country FROM singer WHERE Song_Name LIKE '%Hey%'
SELECT Name, Country FROM singer WHERE Song_Name LIKE '%Hey%'
SELECT s.Name, s.Location FROM stadium s WHERE s.Stadium_ID IN (     SELECT c.Stadium_ID     FROM concert c     WHERE c.Year = '2014'     INTERSECT     SELECT c.Stadium_ID     FROM concert c     WHERE c.Year = '2015' )
SELECT s.Name, s.Location FROM stadium s WHERE s.Stadium_ID IN (     SELECT c.Stadium_ID     FROM concert c     WHERE c.Year = '2014' ) AND s.Stadium_ID IN (     SELECT c.Stadium_ID     FROM concert c     WHERE c.Year = '2015' )
SELECT COUNT(*) AS number_of_concerts FROM concert JOIN stadium ON concert.Stadium_ID = stadium.Stadium_ID WHERE stadium.Capacity = (SELECT MAX(Capacity) FROM stadium)
SELECT COUNT(*)  FROM concert  WHERE Stadium_ID = (     SELECT Stadium_ID      FROM stadium      ORDER BY Capacity DESC      LIMIT 1 )
SELECT COUNT(*) AS number_of_pets FROM Pets WHERE weight > 10
SELECT COUNT(*) FROM Pets WHERE weight > 10
SELECT Pets.weight FROM Pets JOIN Has_Pet ON Has_Pet.PetID = Pets.PetID WHERE Pets.PetType = 'dog' ORDER BY Pets.pet_age ASC LIMIT 1
SELECT weight FROM Pets WHERE PetType = 'dog' ORDER BY pet_age ASC LIMIT 1
SELECT PetType, MAX(weight) AS max_weight FROM Pets GROUP BY PetType
SELECT PetType, MAX(weight) AS max_weight FROM Pets GROUP BY PetType
SELECT COUNT(*) AS number_of_pets FROM Has_Pet JOIN Student ON Has_Pet.StuID = Student.StuID WHERE Student.Age > 20
SELECT COUNT(*)  FROM Has_Pet  JOIN Student ON Has_Pet.StuID = Student.StuID  WHERE Student.Age > 20
SELECT COUNT(*)  FROM Student  JOIN Has_Pet ON Student.StuID = Has_Pet.StuID  JOIN Pets ON Has_Pet.PetID = Pets.PetID  WHERE Student.Sex = 'F' AND Pets.PetType = 'dog'
SELECT COUNT(*)  FROM Student  JOIN Has_Pet ON Student.StuID = Has_Pet.StuID  JOIN Pets ON Has_Pet.PetID = Pets.PetID  WHERE Pets.PetType = 'dog'    AND Student.Sex = 'F'
SELECT COUNT(DISTINCT PetType) AS distinct_pet_types FROM Pets
SELECT COUNT(DISTINCT PetType) AS different_pet_types FROM Pets
SELECT DISTINCT s.Fname FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType IN ('cat', 'dog')
SELECT DISTINCT s.Fname FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType IN ('cat', 'dog')
SELECT DISTINCT s.Fname FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType IN ('cat', 'dog') GROUP BY s.StuID, s.Fname HAVING COUNT(DISTINCT p.PetType) = 2
SELECT s.Fname FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType IN ('cat', 'dog') GROUP BY s.StuID, s.Fname HAVING COUNT(DISTINCT p.PetType) = 2
SELECT DISTINCT s.Major, s.Age FROM Student s WHERE s.StuID NOT IN (     SELECT hp.StuID     FROM Has_Pet hp     JOIN Pets p ON hp.PetID = p.PetID     WHERE p.PetType = 'cat' )
SELECT s.Major, s.Age FROM Student s WHERE s.StuID NOT IN (     SELECT o.StuID     FROM Pets p     JOIN Ownership o ON p.PetID = o.PetID     WHERE p.PetType = 'cat' )
SELECT s.StuID FROM Student s WHERE s.StuID NOT IN (     SELECT hp.StuID     FROM Has_Pet hp     JOIN Pets p ON hp.PetID = p.PetID     WHERE p.PetType = 'cat' )
SELECT Student.StuID FROM Student WHERE Student.StuID NOT IN (     SELECT Has_Pet.StuID     FROM Has_Pet     JOIN Pets ON Has_Pet.PetID = Pets.PetID     WHERE Pets.PetType = 'cat' )
SELECT DISTINCT s.Fname, s.Age FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'dog'   AND s.StuID NOT IN (     SELECT hp2.StuID     FROM Has_Pet hp2     JOIN Pets p2 ON hp2.PetID = p2.PetID     WHERE p2.PetType = 'cat'   )
SELECT DISTINCT s.Fname FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'dog'   AND s.StuID NOT IN (     SELECT hp2.StuID     FROM Has_Pet hp2     JOIN Pets p2 ON hp2.PetID = p2.PetID     WHERE p2.PetType = 'cat'   )
SELECT PetType, weight FROM Pets ORDER BY pet_age ASC LIMIT 1
SELECT PetType, weight FROM Pets ORDER BY pet_age ASC LIMIT 1
SELECT PetID, weight FROM Pets WHERE pet_age > 1
SELECT PetID, weight FROM Pets WHERE pet_age > 1
SELECT      PetType,     AVG(CAST(pet_age AS REAL)) AS average_age,     MAX(pet_age) AS max_age FROM Pets GROUP BY PetType
SELECT      PetType,     AVG(CAST(pet_age AS REAL)) AS average_age,     MAX(pet_age) AS maximum_age FROM Pets GROUP BY PetType
SELECT PetType, AVG(weight) AS avg_weight FROM Pets GROUP BY PetType
SELECT PetType, AVG(weight) AS avg_weight FROM Pets GROUP BY PetType
SELECT DISTINCT s.Fname, s.Age FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID
SELECT DISTINCT s.Fname, s.Age FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID
SELECT Pets.PetID FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Student.LName = 'Smith'
SELECT Pets.PetID FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID JOIN Pets ON Has_Pet.PetID = Pets.PetID WHERE Student.LName = 'Smith'
SELECT Student.StuID, COUNT(Has_Pet.PetID) AS pet_count FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID GROUP BY Student.StuID
SELECT Student.StuID, COUNT(Has_Pet.PetID) AS pet_count FROM Student JOIN Has_Pet ON Student.StuID = Has_Pet.StuID GROUP BY Student.StuID
SELECT s.Fname, s.Sex FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID GROUP BY s.StuID, s.Fname, s.Sex HAVING COUNT(hp.PetID) > 1
SELECT s.Fname, s.Sex FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID GROUP BY s.StuID, s.Fname, s.Sex HAVING COUNT(hp.PetID) > 1
SELECT s.LName FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'cat' AND p.pet_age = 3
SELECT s.LName FROM Student s JOIN Has_Pet hp ON s.StuID = hp.StuID JOIN Pets p ON hp.PetID = p.PetID WHERE p.PetType = 'cat' AND p.pet_age = 3
```sql SELECT AVG(CAST(Student.Age AS REAL)) FROM Student WHERE Student.StuID NOT IN (     SELECT DISTINCT StuID     FROM Pets )
```sql SELECT AVG(CAST(Student.Age AS REAL)) FROM Student WHERE Student.StuID NOT IN (     SELECT StuID FROM Pets )
SELECT COUNT(*) AS continent_count FROM continents
SELECT COUNT(*) AS number_of_continents FROM continents
SELECT      c.ContId AS continent_id,     c.Continent AS continent_name,     COUNT(co.CountryId) AS number_of_countries FROM continents c LEFT JOIN countries co ON c.ContId = co.Continent GROUP BY c.ContId, c.Continent ORDER BY c.ContId
SELECT      c.ContId AS id,     c.Continent AS name,     COUNT(co.CountryId) AS country_count FROM continents c LEFT JOIN countries co ON c.ContId = co.Continent GROUP BY c.ContId, c.Continent ORDER BY c.ContId
SELECT COUNT(*) FROM countries
SELECT COUNT(*) AS country_count FROM countries
SELECT      car_makers.FullName AS maker_full_name,     car_makers.Id AS maker_id,     COUNT(model_list.ModelId) AS number_of_models FROM car_makers LEFT JOIN model_list ON model_list.Maker = car_makers.Id GROUP BY car_makers.Id, car_makers.FullName ORDER BY car_makers.FullName
SELECT      cm.FullName,     cm.Id,     COUNT(ml.ModelId) AS model_count FROM car_makers cm LEFT JOIN model_list ml ON cm.Id = ml.Maker GROUP BY cm.Id, cm.FullName ORDER BY cm.Id
SELECT c.Model FROM car_names c JOIN cars_data d ON c.MakeId = d.Id WHERE d.Horsepower = (     SELECT MIN(Horsepower) FROM cars_data WHERE Horsepower IS NOT NULL )
SELECT m.Model  FROM model_list m  JOIN cars_data c ON m.ModelId = c.Id  WHERE c.Horsepower = (SELECT MIN(CAST(Horsepower AS REAL)) FROM cars_data WHERE Horsepower != '') LIMIT 1
SELECT cm.Model FROM car_names cm JOIN cars_data cd ON cm.MakeId = cd.Id WHERE cd.Weight < (SELECT AVG(Weight) FROM cars_data)
SELECT c.Model FROM car_names c JOIN cars_data d ON c.MakeId = d.Id WHERE d.Weight < (SELECT AVG(CAST(Weight AS REAL)) FROM cars_data)
SELECT DISTINCT cm.Maker FROM car_makers cm JOIN cars_data cd ON cm.Id = cd.Id WHERE cd.Year = 1970
SELECT DISTINCT Maker  FROM car_makers  WHERE Id IN (     SELECT DISTINCT cm.Id      FROM car_makers cm      JOIN cars_data cd ON cm.Id = cd.Id      WHERE cd.Year = 1970 )
SELECT      c.Id AS make,     c.Year AS production_time FROM cars_data c WHERE c.Year = (SELECT MIN(Year) FROM cars_data)
SELECT      cm.Maker,     cd.Year FROM cars_data cd JOIN car_names cn ON cd.Id = cn.MakeId JOIN model_list ml ON cn.Model = ml.Model JOIN car_makers cm ON ml.Maker = cm.Id ORDER BY cd.Year ASC LIMIT 1
SELECT DISTINCT m.Model FROM cars_data c JOIN car_names n ON c.Id = n.MakeId JOIN model_list m ON n.Model = m.Model WHERE c.Year > 1980
SELECT DISTINCT m.Model FROM cars_data c JOIN car_names n ON c.Id = n.MakeId JOIN model_list m ON n.Model = m.Model WHERE c.Year > 1980
SELECT      c.Continent AS continent_name,     COUNT(cm.Id) AS count FROM car_makers cm JOIN countries co ON cm.Country = co.CountryId JOIN continents c ON co.Continent = c.ContId GROUP BY c.Continent
SELECT      c.Continent AS "Continent Name",     COUNT(cm.Id) AS "Number of Car Makers" FROM continents c LEFT JOIN car_makers cm ON c.ContId = cm.Continent GROUP BY c.ContId, c.Continent ORDER BY c.Continent
SELECT c.CountryName FROM countries c JOIN car_makers cm ON c.CountryId = cm.Country GROUP BY c.CountryId, c.CountryName ORDER BY COUNT(cm.Id) DESC LIMIT 1
SELECT c.CountryName FROM countries c JOIN car_makers cm ON c.CountryId = cm.Country GROUP BY c.CountryId, c.CountryName ORDER BY COUNT(cm.Id) DESC LIMIT 1
SELECT      COUNT(model_list.ModelId) AS model_count,     car_makers.FullName FROM model_list JOIN car_makers ON model_list.Maker = car_makers.Id GROUP BY car_makers.Id, car_makers.FullName
SELECT      car_makers.Id,     car_makers.FullName,     COUNT(DISTINCT model_list.Model) AS model_count FROM car_makers JOIN model_list ON model_list.Maker = car_makers.Id JOIN car_names ON car_names.Model = model_list.Model JOIN cars_data ON cars_data.Id = car_names.MakeId GROUP BY car_makers.Id, car_makers.FullName
SELECT Accelerate  FROM cars_data  WHERE Id = (     SELECT MakeId      FROM car_names      WHERE Make = 'amc hornet sportabout (sw)' )
SELECT Accelerate  FROM cars_data  WHERE Id = (SELECT MakeId FROM car_names WHERE Model = 'amc hornet sportabout (sw)')
SELECT COUNT(*)  FROM car_makers  WHERE Country = 'france'
SELECT COUNT(*)  FROM car_makers  JOIN countries ON car_makers.Country = countries.CountryId  WHERE countries.CountryName = 'France'
SELECT COUNT(*)  FROM model_list  JOIN car_makers ON model_list.Maker = car_makers.Id  JOIN countries ON car_makers.Country = countries.CountryId  WHERE countries.CountryName = 'usa'
SELECT COUNT(*)  FROM model_list  JOIN car_makers ON model_list.Maker = car_makers.Id  JOIN countries ON car_makers.Country = countries.CountryId  WHERE countries.CountryName = 'United States'
SELECT AVG(CAST("MPG" AS REAL)) AS avg_mpg FROM cars_data WHERE "Cylinders" = 4
SELECT AVG(CAST("MPG" AS REAL)) AS avg_mpg FROM cars_data WHERE "Cylinders" = 4
SELECT MIN(Weight) AS smallest_weight FROM cars_data WHERE Cylinders = 8 AND Year = 1974
SELECT MIN(Weight)  FROM cars_data  WHERE Cylinders = 8 AND Year = 1974
SELECT car_makers.Maker AS maker, model_list.Model AS model FROM car_makers JOIN model_list ON model_list.Maker = car_makers.Id
SELECT      cm.Maker AS maker,     ml.Model AS model FROM model_list ml JOIN car_makers cm ON ml.Maker = cm.Id
SELECT DISTINCT c.CountryName AS name, c.CountryId AS id FROM countries c INNER JOIN car_makers cm ON c.CountryId = cm.Country
SELECT DISTINCT c.CountryName, c.CountryId FROM countries c INNER JOIN car_makers cm ON c.CountryId = cm.Country
SELECT COUNT(*)  FROM cars_data  WHERE CAST(Horsepower AS REAL) > 150
SELECT COUNT(*)  FROM cars_data  WHERE CAST(Horsepower AS REAL) > 150
SELECT Year, AVG(CAST(Weight AS REAL)) AS avg_weight FROM cars_data GROUP BY Year ORDER BY Year
SELECT      Year,     AVG(CAST(Weight AS REAL)) AS avg_weight,     AVG(CAST(Year AS REAL)) AS avg_year FROM cars_data GROUP BY Year
SELECT c.CountryName FROM countries c JOIN continents co ON c.Continent = co.ContId JOIN car_makers cm ON c.CountryId = cm.Country WHERE co.Continent = 'Europe' GROUP BY c.CountryName HAVING COUNT(cm.Id) >= 3
SELECT c.CountryName FROM countries c JOIN car_makers cm ON c.CountryId = cm.Country WHERE c.Continent = (SELECT ContId FROM continents WHERE Continent = 'Europe') GROUP BY c.CountryId, c.CountryName HAVING COUNT(cm.Id) >= 3
SELECT MAX(CAST(cars_data.Horsepower AS REAL)) AS max_horsepower, car_names.Make FROM cars_data JOIN car_names ON cars_data.Id = car_names.MakeId JOIN model_list ON car_names.Model = model_list.Model JOIN car_makers ON model_list.Maker = car_makers.Id JOIN countries ON car_makers.Country = countries.CountryId JOIN continents ON countries.Continent = continents.ContId WHERE cars_data.Cylinders = 3
SELECT      MAX(CAST(cars_data.Horsepower AS INTEGER)) AS largest_horsepower,     car_names.Make FROM cars_data JOIN car_names ON cars_data.Id = car_names.MakeId JOIN model_list ON car_names.Model = model_list.Model JOIN car_makers ON model_list.Maker = car_makers.Id JOIN countries ON car_makers.Country = countries.CountryId JOIN continents ON countries.Continent = continents.ContId WHERE cars_data.Cylinders = 3
SELECT car_names.Model FROM cars_data JOIN car_names ON cars_data.Id = car_names.MakeId JOIN model_list ON car_names.Model = model_list.Model WHERE cars_data.MPG != 'NULL' ORDER BY CAST(cars_data.MPG AS REAL) DESC LIMIT 1
SELECT Model  FROM model_list  ORDER BY ModelId DESC  LIMIT 1
SELECT AVG(CAST(Horsepower AS REAL))  FROM cars_data  WHERE Year < 1980    AND Horsepower IS NOT NULL    AND Horsepower != ''
SELECT AVG(CAST("Horsepower" AS REAL)) AS avg_horsepower FROM cars_data WHERE "Year" < 1980   AND "Horsepower" IS NOT NULL   AND "Horsepower" != ''
```sql SELECT AVG(cars_data.Edispl) AS avg_edispl FROM cars_data WHERE cars_data.Id IN (     SELECT car_names.MakeId     FROM car_names     WHERE car_names.Model = 'volvo' )
SELECT AVG(Edispl) AS avg_edispl FROM cars_data WHERE Id IN (     SELECT MakeId     FROM car_names     WHERE Make = 'Volvo' )
SELECT Cylinders, MAX(Accelerate) AS max_accelerate FROM cars_data GROUP BY Cylinders ORDER BY Cylinders
SELECT Cylinders, MAX(Accelerate) AS max_accelerate FROM cars_data GROUP BY Cylinders
SELECT m.Model FROM model_list m JOIN car_names c ON m.Model = c.Model JOIN cars_data d ON c.MakeId = d.Id GROUP BY m.Model ORDER BY COUNT(DISTINCT c.Make) DESC LIMIT 1
SELECT m.Model FROM model_list m JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id GROUP BY m.Model ORDER BY COUNT(DISTINCT cd.Id) DESC LIMIT 1
SELECT COUNT(*)  FROM cars_data  WHERE Cylinders > 4
SELECT COUNT(*) AS number_of_cars FROM cars_data WHERE Cylinders > 4
SELECT COUNT(*)  FROM cars_data  WHERE Year = 1980
SELECT COUNT(*)  FROM cars_data  WHERE Year = 1980
SELECT COUNT(*)  FROM model_list  JOIN car_makers ON model_list.Maker = car_makers.Id  WHERE car_makers.FullName = 'American Motor Company'
SELECT COUNT(*)  FROM model_list  JOIN car_makers ON model_list.Maker = car_makers.Id  WHERE car_makers.FullName = 'American Motor Company'
SELECT      cm.FullName,     cm.Id FROM car_makers cm JOIN model_list ml ON cm.Id = ml.Maker GROUP BY cm.Id, cm.FullName HAVING COUNT(ml.ModelId) > 3
SELECT      cm.Id,     cm.Maker FROM car_makers cm JOIN model_list ml ON cm.Id = ml.Maker GROUP BY cm.Id, cm.Maker HAVING COUNT(ml.ModelId) > 3
SELECT DISTINCT m.Model FROM model_list m JOIN car_makers cm ON m.Maker = cm.Id JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cm.FullName = 'General Motors' OR cd.Weight > 3500
SELECT DISTINCT m.Model FROM model_list m JOIN car_makers cm ON m.Maker = cm.Id JOIN car_names cn ON m.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id WHERE cm.Maker = 'General Motors' OR cd.Weight > 3500
SELECT DISTINCT Year FROM cars_data WHERE Weight >= 3000 AND Weight <= 4000 ORDER BY Year
SELECT DISTINCT Year FROM cars_data WHERE Weight < 4000   AND Weight > 3000
SELECT Horsepower  FROM cars_data  ORDER BY Accelerate DESC  LIMIT 1
SELECT Horsepower  FROM cars_data  ORDER BY Accelerate DESC  LIMIT 1
SELECT Cylinders  FROM cars_data  WHERE Id = (     SELECT Id      FROM cars_data      WHERE Id IN (         SELECT MakeId          FROM car_names          WHERE Model = 'volvo'     )      ORDER BY Accelerate ASC      LIMIT 1 )
SELECT Cylinders FROM cars_data WHERE Id IN (     SELECT MakeId     FROM car_names     WHERE Model LIKE '%volvo%' OR Make LIKE '%volvo%' ) ORDER BY Accelerate ASC LIMIT 1
SELECT COUNT(*)  FROM cars_data  WHERE Accelerate > (     SELECT Accelerate      FROM cars_data      WHERE Horsepower = (         SELECT MAX(CAST(Horsepower AS REAL))          FROM cars_data          WHERE Horsepower IS NOT NULL AND Horsepower != ''     )     LIMIT 1 )
```sql SELECT COUNT(*)  FROM cars_data  WHERE Accelerate > (     SELECT Accelerate      FROM cars_data      WHERE CAST(Horsepower AS REAL) = (         SELECT MAX(CAST(Horsepower AS REAL))          FROM cars_data     )     LIMIT 1 )
SELECT COUNT(*)  FROM countries c WHERE (     SELECT COUNT(*)      FROM car_makers cm      WHERE cm.Country = c.CountryId ) > 2
SELECT COUNT(*)  FROM countries  WHERE CountryId IN (     SELECT Country      FROM car_makers      GROUP BY Country      HAVING COUNT(*) > 2 )
SELECT COUNT(*)  FROM cars_data  WHERE Cylinders > 6
SELECT COUNT(*)  FROM cars_data  WHERE Cylinders > 6
SELECT cn.Model FROM cars_data cd JOIN car_names cn ON cd.Id = cn.MakeId JOIN model_list ml ON cn.Model = ml.Model WHERE cd.Cylinders = 4 ORDER BY CAST(cd.Horsepower AS REAL) DESC LIMIT 1
SELECT cn.Model FROM cars_data cd JOIN car_names cn ON cd.Id = cn.MakeId WHERE cd.Cylinders = 4 ORDER BY CAST(cd.Horsepower AS REAL) DESC LIMIT 1
SELECT      c.MakeId,     c.Make FROM car_names c JOIN cars_data d ON c.MakeId = d.Id WHERE d.Horsepower > (SELECT MIN(CAST(Horsepower AS REAL)) FROM cars_data WHERE Horsepower IS NOT NULL AND Horsepower != '')   AND d.Cylinders <= 3
SELECT DISTINCT cn.MakeId, cn.Make FROM cars_data cd JOIN car_names cn ON cd.Id = cn.MakeId WHERE cd.Cylinders < 4   AND cd.Horsepower > (SELECT MIN(CAST(Horsepower AS REAL)) FROM cars_data WHERE Horsepower IS NOT NULL AND Horsepower != '')   AND cd.Horsepower IS NOT NULL   AND cd.Horsepower != ''
SELECT MAX(CAST(cars_data.MPG AS REAL))  FROM cars_data  WHERE cars_data.Cylinders = 8 OR cars_data.Year < 1980
SELECT MAX(CAST(MPG AS REAL)) AS max_mpg FROM cars_data WHERE Cylinders = 8 OR Year < 1980
SELECT DISTINCT m.Model FROM cars_data c JOIN car_names n ON c.Id = n.MakeId JOIN model_list m ON n.Model = m.Model WHERE c.Weight < 3500   AND n.Make != 'Ford Motor Company'
SELECT DISTINCT cn.Model FROM car_names cn JOIN cars_data cd ON cn.MakeId = cd.Id JOIN model_list ml ON cn.Model = ml.Model WHERE cd.Weight < 3500   AND cn.Make != 'Ford Motor Company'
SELECT c.CountryName FROM countries c LEFT JOIN car_makers cm ON c.CountryId = cm.Country WHERE cm.Id IS NULL
SELECT c.CountryName FROM countries c LEFT JOIN car_makers cm ON c.CountryId = cm.Country WHERE cm.Id IS NULL
SELECT cm.Id, cm.Maker FROM car_makers cm JOIN model_list ml ON cm.Id = ml.Maker GROUP BY cm.Id, cm.Maker HAVING COUNT(ml.Model) >= 2
SELECT      cm.Id,     cm.Maker FROM car_makers cm JOIN model_list ml ON cm.Id = ml.Maker JOIN car_names cn ON ml.Model = cn.Model JOIN cars_data cd ON cn.MakeId = cd.Id GROUP BY cm.Id, cm.Maker HAVING COUNT(DISTINCT ml.Model) >= 2     AND COUNT(DISTINCT cd.Id) > 3
SELECT DISTINCT c.CountryId, c.CountryName FROM countries c WHERE c.CountryId IN (     SELECT cm.Country     FROM car_makers cm     GROUP BY cm.Country     HAVING COUNT(cm.Id) > 3 ) OR c.CountryId IN (     SELECT cm.Country     FROM car_makers cm     JOIN model_list ml ON cm.Id = ml.Maker     JOIN car_names cn ON ml.Model = cn.Model     WHERE ml.Model = 'fiat' )
SELECT DISTINCT c.CountryId, c.CountryName FROM countries c WHERE c.CountryId IN (     SELECT cm.Country     FROM car_makers cm     GROUP BY cm.Country     HAVING COUNT(cm.Id) > 3 ) OR c.CountryId IN (     SELECT cm.Country     FROM car_makers cm     JOIN model_list ml ON ml.Maker = cm.Id     JOIN car_names cn ON cn.Model = ml.Model     WHERE ml.Model = 'fiat' )
SELECT Country FROM airlines WHERE Airline = 'JetBlue Airways'
SELECT Country FROM airlines WHERE Airline LIKE '%Jetblue%'
SELECT Abbreviation FROM airlines WHERE Airline = 'JetBlue Airways'
SELECT Abbreviation FROM airlines WHERE Airline LIKE '%Jetblue%'
SELECT Airline, Abbreviation FROM airlines WHERE Country = 'USA'
SELECT Airline, Abbreviation FROM airlines WHERE Country = 'USA'
SELECT AirportCode, AirportName FROM airports WHERE City LIKE '%Anthony%'
SELECT AirportCode, AirportName FROM airports WHERE City LIKE '%Anthony%'
SELECT COUNT(*) FROM airlines
SELECT COUNT(*) AS total_airlines FROM airlines
SELECT COUNT(*) FROM airports
SELECT COUNT(*) FROM airports
SELECT COUNT(*) FROM flights
SELECT COUNT(*) FROM flights
SELECT Airline FROM airlines WHERE Abbreviation = 'UAL'
SELECT Airline  FROM airlines  WHERE Abbreviation = 'UAL'
SELECT COUNT(*) AS airline_count FROM airlines WHERE Country = 'USA'
SELECT COUNT(*) AS airline_count FROM airlines WHERE Country = 'USA'
SELECT City, Country FROM airports WHERE AirportName LIKE '%Alton%' OR City = 'Alton'
SELECT City, Country  FROM airports  WHERE AirportName LIKE '%Alton%' OR City = 'Alton'
SELECT AirportName  FROM airports  WHERE AirportCode = 'AKO'
SELECT AirportName  FROM airports  WHERE AirportCode = 'AKO'
SELECT AirportName  FROM airports  WHERE City LIKE '%Aberdeen%'
SELECT AirportName  FROM airports  WHERE City LIKE '%Aberdeen%'
SELECT COUNT(*) FROM flights WHERE SourceAirport = 'APG'
SELECT COUNT(*)  FROM flights  WHERE SourceAirport = 'APG'
SELECT COUNT(*)  FROM flights  WHERE DestAirport = 'ATO'
SELECT COUNT(*)  FROM flights  WHERE DestAirport = 'ATO'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.SourceAirport = airports.AirportCode  WHERE airports.City = 'Aberdeen'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.SourceAirport = airports.AirportCode  WHERE airports.City = 'Aberdeen'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airports.City = 'Aberdeen'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airports.City = 'Aberdeen'
SELECT COUNT(*)  FROM flights  JOIN airports AS src ON flights.SourceAirport = src.AirportCode  JOIN airports AS dst ON flights.DestAirport = dst.AirportCode  WHERE src.City = 'Aberdeen' AND dst.City = 'Ashley'
SELECT COUNT(*)  FROM flights  JOIN airports AS src ON flights.SourceAirport = src.AirportCode  JOIN airports AS dst ON flights.DestAirport = dst.AirportCode  WHERE src.City = 'Aberdeen' AND dst.City = 'Ashley'
SELECT COUNT(*)  FROM flights  JOIN airlines ON flights.Airline = airlines.uid  WHERE airlines.Airline = 'JetBlue Airways'
SELECT COUNT(*)  FROM flights  JOIN airlines ON flights.Airline = airlines.uid  WHERE airlines.Airline = 'Jetblue Airways'
SELECT COUNT(*)  FROM flights  JOIN airlines ON flights.Airline = airlines.uid  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airlines.Airline = 'United Airlines'    AND airports.AirportCode = 'ASY'
SELECT COUNT(*)  FROM flights  JOIN airlines ON flights.Airline = airlines.uid  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airlines.Airline = 'United Airlines'    AND airports.AirportCode = 'ASY'
SELECT COUNT(*)  FROM flights  JOIN airlines ON flights.Airline = airlines.uid  WHERE airlines.Airline = 'United Airlines'    AND flights.SourceAirport = 'AHD'
SELECT COUNT(*)  FROM flights  JOIN airlines ON flights.Airline = airlines.uid  WHERE airlines.Airline = 'United Airlines'    AND flights.SourceAirport = 'AHD'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.DestAirport = airports.AirportCode  JOIN airlines ON flights.Airline = airlines.uid  WHERE airlines.Airline = 'United Airlines'    AND airports.City = 'Aberdeen'
SELECT COUNT(*)  FROM flights  JOIN airlines ON flights.Airline = airlines.uid  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airlines.Airline = 'United Airlines'    AND airports.City = 'Aberdeen'
SELECT a.City, COUNT(*) AS num_arriving_flights FROM flights f JOIN airports a ON f.DestAirport = a.AirportCode GROUP BY a.City ORDER BY num_arriving_flights DESC LIMIT 1
SELECT a.City FROM flights f JOIN airports a ON f.DestAirport = a.AirportCode GROUP BY a.City ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.City FROM flights f JOIN airports a ON f.SourceAirport = a.AirportCode GROUP BY a.City ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.City FROM airports a JOIN flights f ON f.SourceAirport = a.AirportCode GROUP BY a.City ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.AirportCode FROM airports a JOIN flights f ON f.DestAirport = a.AirportCode GROUP BY a.AirportCode ORDER BY COUNT(*) DESC LIMIT 1
SELECT airports.AirportCode FROM airports JOIN flights ON flights.DestAirport = airports.AirportCode GROUP BY airports.AirportCode ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.AirportCode FROM airports a LEFT JOIN flights f ON a.AirportCode = f.DestAirport OR a.AirportCode = f.SourceAirport GROUP BY a.AirportCode ORDER BY COUNT(f.FlightNo) ASC LIMIT 1
SELECT a.AirportCode FROM airports a LEFT JOIN flights f ON f.SourceAirport = a.AirportCode OR f.DestAirport = a.AirportCode GROUP BY a.AirportCode ORDER BY COUNT(f.FlightNo) ASC LIMIT 1
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.Airline ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.Airline ORDER BY COUNT(*) DESC LIMIT 1
SELECT a.Abbreviation, a.Country FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.uid, a.Abbreviation, a.Country ORDER BY COUNT(f.FlightNo) ASC LIMIT 1
SELECT a.Abbreviation, a.Country FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.uid, a.Abbreviation, a.Country ORDER BY COUNT(*) ASC LIMIT 1
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'AHD'
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'AHD'
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.DestAirport = 'AHD'
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.DestAirport = 'AHD'
SELECT a.Airline FROM airlines a WHERE EXISTS (     SELECT 1 FROM flights f1      WHERE f1.Airline = a.uid      AND f1.SourceAirport = 'APG' ) AND EXISTS (     SELECT 1 FROM flights f2      WHERE f2.Airline = a.uid      AND f2.SourceAirport = 'CVO' )
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'APG' INTERSECT SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'CVO'
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'CVO'   AND a.uid NOT IN (     SELECT f2.Airline     FROM flights f2     WHERE f2.SourceAirport = 'APG'   )
SELECT DISTINCT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline WHERE f.SourceAirport = 'CVO'   AND a.Airline NOT IN (     SELECT a2.Airline     FROM airlines a2     JOIN flights f2 ON a2.uid = f2.Airline     WHERE f2.SourceAirport = 'APG'   )
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.Airline HAVING COUNT(f.FlightNo) >= 10
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.Airline HAVING COUNT(f.FlightNo) >= 10
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.Airline HAVING COUNT(f.FlightNo) < 200
SELECT a.Airline FROM airlines a JOIN flights f ON a.uid = f.Airline GROUP BY a.Airline HAVING COUNT(f.FlightNo) < 200
SELECT FlightNo  FROM flights  WHERE Airline = (SELECT uid FROM airlines WHERE Airline = 'United Airlines')
SELECT f.FlightNo FROM flights f JOIN airlines a ON f.Airline = a.uid WHERE a.Airline = 'United Airlines'
SELECT FlightNo  FROM flights  WHERE SourceAirport = 'APG'
SELECT FlightNo  FROM flights  WHERE SourceAirport = 'APG'
SELECT FlightNo  FROM flights  WHERE DestAirport = 'APG'
SELECT FlightNo  FROM flights  WHERE DestAirport = 'APG'
SELECT f.FlightNo FROM flights f JOIN airports a ON f.SourceAirport = a.AirportCode WHERE a.City = 'Aberdeen'
SELECT f.FlightNo FROM flights f JOIN airports a ON f.SourceAirport = a.AirportCode WHERE a.City = 'Aberdeen'
SELECT f.FlightNo FROM flights f JOIN airports a ON f.DestAirport = a.AirportCode WHERE a.City = 'Aberdeen'
SELECT f.FlightNo FROM flights f JOIN airports a ON f.DestAirport = a.AirportCode WHERE a.City = 'Aberdeen'
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airports.City IN ('Aberdeen', 'Abilene')
SELECT COUNT(*)  FROM flights  JOIN airports ON flights.DestAirport = airports.AirportCode  WHERE airports.City IN ('Aberdeen', 'Abilene')
SELECT a.AirportName FROM airports a LEFT JOIN flights f_in ON a.AirportCode = f_in.DestAirport LEFT JOIN flights f_out ON a.AirportCode = f_out.SourceAirport WHERE f_in.DestAirport IS NULL AND f_out.SourceAirport IS NULL
SELECT a.AirportCode FROM airports a WHERE a.AirportCode NOT IN (     SELECT f.SourceAirport FROM flights f     UNION     SELECT f.DestAirport FROM flights f )
SELECT COUNT(*) AS employee_count FROM employee
SELECT COUNT(*) FROM employee
SELECT Name FROM employee ORDER BY Age ASC
SELECT Name FROM employee ORDER BY Age ASC
SELECT employee.City, COUNT(employee.Employee_ID) AS number_of_employees FROM employee GROUP BY employee.City
SELECT e.City, COUNT(e.Employee_ID) AS employee_count FROM employee e JOIN hiring h ON e.Employee_ID = h.Employee_ID JOIN shop s ON h.Shop_ID = s.Shop_ID GROUP BY e.City
SELECT City FROM employee WHERE Age < 30 GROUP BY City HAVING COUNT(*) > 1
SELECT City FROM employee WHERE Age < 30 GROUP BY City HAVING COUNT(*) > 1
SELECT Location, COUNT(*) AS number_of_shops FROM shop GROUP BY Location
SELECT Location, COUNT(*) AS number_of_shops FROM shop GROUP BY Location
SELECT Manager_name, District FROM shop WHERE Number_products = (SELECT MAX(Number_products) FROM shop)
SELECT s.Manager_name, s.District FROM shop s ORDER BY s.Number_products DESC LIMIT 1
SELECT MIN(Number_products) AS min_products, MAX(Number_products) AS max_products FROM shop
SELECT MIN(Number_products) AS min_products, MAX(Number_products) AS max_products FROM shop
SELECT Name, Location, District FROM shop ORDER BY Number_products DESC
SELECT Name, Location, District FROM shop ORDER BY Number_products DESC
SELECT Name FROM shop WHERE Number_products > (SELECT AVG(Number_products) FROM shop)
SELECT Name FROM shop WHERE Number_products > (SELECT AVG(CAST(Number_products AS REAL)) FROM shop)
SELECT Name FROM employee WHERE Employee_ID = (SELECT Employee_ID FROM evaluation GROUP BY Employee_ID ORDER BY COUNT(*) DESC LIMIT 1)
SELECT e.Name FROM employee e JOIN evaluation ev ON e.Employee_ID = ev.Employee_ID GROUP BY e.Employee_ID, e.Name ORDER BY COUNT(*) DESC LIMIT 1
SELECT e.Name FROM employee e JOIN evaluation ev ON e.Employee_ID = ev.Employee_ID ORDER BY ev.Bonus DESC LIMIT 1
SELECT e.Name FROM employee e JOIN evaluation ev ON e.Employee_ID = ev.Employee_ID ORDER BY ev.Bonus DESC LIMIT 1
SELECT e.Name FROM employee e LEFT JOIN evaluation ev ON e.Employee_ID = ev.Employee_ID WHERE ev.Employee_ID IS NULL
SELECT e.Name FROM employee e LEFT JOIN evaluation ev ON e.Employee_ID = ev.Employee_ID WHERE ev.Employee_ID IS NULL
SELECT s.Name FROM shop s JOIN hiring h ON s.Shop_ID = h.Shop_ID GROUP BY s.Shop_ID, s.Name ORDER BY COUNT(h.Employee_ID) DESC LIMIT 1
SELECT s.Name FROM shop s JOIN hiring h ON s.Shop_ID = h.Shop_ID GROUP BY s.Shop_ID, s.Name ORDER BY COUNT(h.Employee_ID) DESC LIMIT 1
SELECT s.Name FROM shop s LEFT JOIN hiring h ON s.Shop_ID = h.Shop_ID WHERE h.Employee_ID IS NULL
SELECT s.Name FROM shop s LEFT JOIN hiring h ON s.Shop_ID = h.Shop_ID WHERE h.Shop_ID IS NULL
SELECT s.Name, COUNT(h.Employee_ID) AS number_of_employees FROM shop s LEFT JOIN hiring h ON s.Shop_ID = h.Shop_ID GROUP BY s.Shop_ID, s.Name
SELECT      s.Name AS shop_name,     COUNT(h.Employee_ID) AS number_of_employees FROM shop s LEFT JOIN hiring h ON s.Shop_ID = h.Shop_ID GROUP BY s.Shop_ID, s.Name
SELECT SUM(Bonus) AS total_bonus FROM evaluation
SELECT SUM(Bonus) AS total_bonus FROM evaluation
SELECT * FROM hiring
SELECT * FROM hiring
SELECT DISTINCT s1.District FROM shop s1 JOIN shop s2 ON s1.District = s2.District WHERE s1.Number_products < 3000   AND s2.Number_products > 10000
SELECT DISTINCT s1.District FROM shop s1 JOIN shop s2 ON s1.District = s2.District WHERE s1.Number_products < 3000   AND s2.Number_products > 10000
SELECT COUNT(DISTINCT Location) AS different_store_locations FROM shop
SELECT COUNT(DISTINCT Location) FROM shop
SELECT COUNT(*) AS document_count FROM Documents
SELECT COUNT(*) FROM Documents
SELECT Document_ID, Document_Name, Document_Description FROM Documents
SELECT Document_ID, Document_Name, Document_Description FROM Documents
SELECT Document_Name, Template_ID FROM Documents WHERE Document_Description LIKE '%w%'
SELECT Document_Name, Template_ID FROM Documents WHERE Document_Description LIKE '%w%'
SELECT      d.Document_ID,     d.Template_ID,     d.Document_Description FROM Documents d JOIN Templates t ON d.Template_ID = t.Template_ID JOIN Ref_Template_Types rtt ON t.Template_Type_Code = rtt.Template_Type_Code WHERE d.Document_Name = 'Robbin CV'
SELECT      d.Document_ID,     d.Template_ID,     d.Document_Description FROM Documents d WHERE d.Document_Name = 'Robbin CV'
SELECT COUNT(DISTINCT Templates.Template_ID) AS template_count FROM Documents JOIN Templates ON Documents.Template_ID = Templates.Template_ID
SELECT COUNT(DISTINCT Template_ID) AS number_of_different_templates FROM Templates
SELECT COUNT(*)  FROM Documents  JOIN Templates ON Documents.Template_ID = Templates.Template_ID  WHERE Templates.Template_Type_Code = 'PPT'
SELECT COUNT(*)  FROM Documents  JOIN Templates ON Documents.Template_ID = Templates.Template_ID  JOIN Ref_Template_Types ON Templates.Template_Type_Code = Ref_Template_Types.Template_Type_Code  WHERE Templates.Template_Type_Code = 'PPT'     OR Ref_Template_Types.Template_Type_Code = 'PPT'
SELECT      t.Template_ID,     COUNT(d.Document_ID) AS number_of_documents FROM Templates t LEFT JOIN Documents d ON t.Template_ID = d.Template_ID GROUP BY t.Template_ID ORDER BY t.Template_ID
SELECT      d.Template_ID,     COUNT(*) AS usage_count FROM Documents d JOIN Templates t ON d.Template_ID = t.Template_ID GROUP BY d.Template_ID ORDER BY d.Template_ID
SELECT      t.Template_ID AS id,     t.Template_Type_Code AS type_code FROM Templates t JOIN Documents d ON t.Template_ID = d.Template_ID GROUP BY t.Template_ID, t.Template_Type_Code ORDER BY COUNT(d.Document_ID) DESC LIMIT 1
SELECT t.Template_ID, t.Template_Type_Code FROM Templates t JOIN Documents d ON t.Template_ID = d.Template_ID GROUP BY t.Template_ID, t.Template_Type_Code ORDER BY COUNT(d.Document_ID) DESC LIMIT 1
SELECT t.Template_ID FROM Templates t JOIN Documents d ON t.Template_ID = d.Template_ID GROUP BY t.Template_ID HAVING COUNT(d.Document_ID) > 1
SELECT t.Template_ID FROM Templates t JOIN Documents d ON t.Template_ID = d.Template_ID GROUP BY t.Template_ID HAVING COUNT(d.Document_ID) > 1
SELECT t.Template_ID FROM Templates t LEFT JOIN Documents d ON t.Template_ID = d.Template_ID WHERE d.Template_ID IS NULL
SELECT Templates.Template_ID FROM Templates LEFT JOIN Documents ON Templates.Template_ID = Documents.Template_ID WHERE Documents.Document_ID IS NULL
SELECT COUNT(*) AS template_count FROM Templates
SELECT COUNT(*) FROM Templates
SELECT Template_ID, Version_Number, Template_Type_Code FROM Templates
SELECT      t.Template_ID,     t.Version_Number,     t.Template_Type_Code FROM Templates t
SELECT DISTINCT Template_Type_Code FROM Templates
SELECT Template_Type_Code FROM Ref_Template_Types
SELECT Template_ID  FROM Templates  WHERE Template_Type_Code IN ('PP', 'PPT')
SELECT Template_ID  FROM Templates  WHERE Template_Type_Code IN ('PP', 'PPT')
SELECT COUNT(*) AS template_count FROM Templates WHERE Template_Type_Code = 'CV'
SELECT COUNT(*)  FROM Templates  WHERE Template_Type_Code = 'CV'
SELECT      t.Version_Number,     t.Template_Type_Code FROM Templates t WHERE t.Version_Number > 5
SELECT Version_Number, Template_Type_Code FROM Templates WHERE Version_Number > 5
SELECT      Ref_Template_Types.Template_Type_Code,     COUNT(Templates.Template_ID) AS number_of_templates FROM Ref_Template_Types LEFT JOIN Templates ON Ref_Template_Types.Template_Type_Code = Templates.Template_Type_Code GROUP BY Ref_Template_Types.Template_Type_Code
SELECT      t.Template_Type_Code,     COUNT(t.Template_ID) AS template_count FROM Templates t GROUP BY t.Template_Type_Code ORDER BY t.Template_Type_Code
SELECT      t.Template_Type_Code,     COUNT(*) AS template_count FROM Templates t GROUP BY t.Template_Type_Code ORDER BY template_count DESC LIMIT 1
SELECT t.Template_Type_Code FROM Templates t GROUP BY t.Template_Type_Code ORDER BY COUNT(*) DESC LIMIT 1
SELECT      rt.Template_Type_Code FROM      Ref_Template_Types rt LEFT JOIN      Templates t ON rt.Template_Type_Code = t.Template_Type_Code GROUP BY      rt.Template_Type_Code HAVING      COUNT(t.Template_ID) < 3
SELECT rt.Template_Type_Code FROM Ref_Template_Types rt LEFT JOIN Templates t ON rt.Template_Type_Code = t.Template_Type_Code GROUP BY rt.Template_Type_Code HAVING COUNT(t.Template_ID) < 3
SELECT MIN(Templates.Version_Number) AS smallest_version_number,         Templates.Template_Type_Code FROM Templates GROUP BY Templates.Template_Type_Code ORDER BY smallest_version_number ASC LIMIT 1
SELECT MIN(Templates.Version_Number) AS lowest_version_number,         Templates.Template_Type_Code FROM Templates GROUP BY Templates.Template_Type_Code ORDER BY lowest_version_number LIMIT 1
SELECT t.Template_Type_Code FROM Documents d JOIN Templates t ON d.Template_ID = t.Template_ID WHERE d.Document_Name = 'Data base'
SELECT t.Template_Type_Code FROM Documents d JOIN Templates t ON d.Template_ID = t.Template_ID WHERE d.Document_Name = 'Data base'
SELECT d.Document_Name FROM Documents d JOIN Templates t ON d.Template_ID = t.Template_ID JOIN Ref_Template_Types rtt ON t.Template_Type_Code = rtt.Template_Type_Code WHERE rtt.Template_Type_Code = 'BK'
SELECT d.Document_Name FROM Documents d JOIN Templates t ON d.Template_ID = t.Template_ID WHERE t.Template_Type_Code = 'BK'
SELECT      rt.Template_Type_Code,     COUNT(d.Document_ID) AS document_count FROM Ref_Template_Types rt LEFT JOIN Templates t ON rt.Template_Type_Code = t.Template_Type_Code LEFT JOIN Documents d ON t.Template_ID = d.Template_ID GROUP BY rt.Template_Type_Code ORDER BY rt.Template_Type_Code
SELECT      t.Template_Type_Code,     COUNT(DISTINCT d.Document_ID) AS document_count FROM Templates t LEFT JOIN Documents d ON t.Template_ID = d.Template_ID GROUP BY t.Template_Type_Code ORDER BY t.Template_Type_Code
SELECT      t.Template_Type_Code,     COUNT(d.Document_ID) AS document_count FROM Documents d JOIN Templates t ON d.Template_ID = t.Template_ID GROUP BY t.Template_Type_Code ORDER BY document_count DESC LIMIT 1
SELECT      Ref_Template_Types.Template_Type_Code FROM      Documents     JOIN Templates ON Documents.Template_ID = Templates.Template_ID     JOIN Ref_Template_Types ON Templates.Template_Type_Code = Ref_Template_Types.Template_Type_Code GROUP BY      Ref_Template_Types.Template_Type_Code ORDER BY      COUNT(*) DESC LIMIT 1
SELECT t.Template_Type_Code FROM Ref_Template_Types t WHERE t.Template_Type_Code NOT IN (     SELECT DISTINCT tmpl.Template_Type_Code     FROM Templates tmpl     JOIN Documents d ON tmpl.Template_ID = d.Template_ID )
SELECT t.Template_Type_Code FROM Ref_Template_Types t WHERE t.Template_Type_Code NOT IN (     SELECT DISTINCT tmpl.Template_Type_Code     FROM Templates tmpl     JOIN Documents d ON tmpl.Template_ID = d.Template_ID )
SELECT Template_Type_Code, Template_Type_Description FROM Ref_Template_Types
SELECT Template_Type_Code, Template_Type_Description FROM Ref_Template_Types
SELECT Template_Type_Description  FROM Ref_Template_Types  WHERE Template_Type_Code = 'AD'
SELECT Template_Type_Description  FROM Ref_Template_Types  WHERE Template_Type_Code = 'AD'
SELECT Template_Type_Code  FROM Ref_Template_Types  WHERE Template_Type_Description = 'Book'
SELECT Template_Type_Code  FROM Ref_Template_Types  WHERE Template_Type_Description = 'Book'
SELECT DISTINCT rt.Template_Type_Description FROM Documents d JOIN Templates t ON d.Template_ID = t.Template_ID JOIN Ref_Template_Types rt ON t.Template_Type_Code = rt.Template_Type_Code
SELECT DISTINCT t.Template_Details FROM Templates t JOIN Documents d ON t.Template_ID = d.Template_ID
SELECT t.Template_ID FROM Templates t JOIN Ref_Template_Types rtt ON t.Template_Type_Code = rtt.Template_Type_Code WHERE rtt.Template_Type_Description = 'Presentation'
SELECT t.Template_ID FROM Templates t JOIN Ref_Template_Types rtt ON t.Template_Type_Code = rtt.Template_Type_Code WHERE rtt.Template_Type_Description = 'Presentation'
SELECT COUNT(*) FROM Paragraphs
SELECT COUNT(*) FROM Paragraphs
SELECT COUNT(*) AS paragraph_count FROM Paragraphs p JOIN Documents d ON p.Document_ID = d.Document_ID WHERE d.Document_Name = 'Summer Show'
SELECT COUNT(*)  FROM Paragraphs p  JOIN Documents d ON p.Document_ID = d.Document_ID  WHERE d.Document_Name = 'Summer Show'
SELECT Paragraph_ID, Document_ID, Paragraph_Text, Other_Details FROM Paragraphs WHERE Paragraph_Text LIKE '%Korea%'
SELECT Other_Details  FROM Paragraphs  WHERE Paragraph_Text LIKE '%Korea%'
SELECT p.Paragraph_ID, p.Paragraph_Text FROM Paragraphs p JOIN Documents d ON p.Document_ID = d.Document_ID WHERE d.Document_Name = 'Welcome to NY'
SELECT p.Paragraph_ID, p.Paragraph_Text FROM Paragraphs p JOIN Documents d ON p.Document_ID = d.Document_ID WHERE d.Document_Name = 'Welcome to NY'
SELECT p.Paragraph_Text FROM Paragraphs p JOIN Documents d ON p.Document_ID = d.Document_ID WHERE d.Document_Name = 'Customer reviews'
SELECT p.Paragraph_Text FROM Paragraphs p JOIN Documents d ON p.Document_ID = d.Document_ID WHERE d.Document_Name = 'Customer reviews'
SELECT      d.Document_ID,     COUNT(p.Paragraph_ID) AS paragraph_count FROM Documents d LEFT JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID ORDER BY d.Document_ID
SELECT      d.Document_ID,     COUNT(p.Paragraph_ID) AS paragraph_count FROM Documents d LEFT JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID ORDER BY d.Document_ID
SELECT      d.Document_ID,     d.Document_Name,     COUNT(p.Paragraph_ID) AS paragraph_count FROM Documents d LEFT JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID, d.Document_Name ORDER BY d.Document_ID
SELECT      d.Document_ID,     d.Document_Name,     COUNT(p.Paragraph_ID) AS paragraph_count FROM Documents d LEFT JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID, d.Document_Name
SELECT d.Document_ID FROM Documents d JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID HAVING COUNT(p.Paragraph_ID) >= 2
SELECT d.Document_ID FROM Documents d JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID HAVING COUNT(p.Paragraph_ID) >= 2
SELECT      d.Document_ID,     d.Document_Name FROM Documents d JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID, d.Document_Name ORDER BY COUNT(p.Paragraph_ID) DESC LIMIT 1
SELECT d.Document_ID, d.Document_Name FROM Documents d JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID, d.Document_Name ORDER BY COUNT(p.Paragraph_ID) DESC LIMIT 1
SELECT Documents.Document_ID FROM Documents LEFT JOIN Paragraphs ON Documents.Document_ID = Paragraphs.Document_ID GROUP BY Documents.Document_ID ORDER BY COUNT(Paragraphs.Paragraph_ID) ASC LIMIT 1
SELECT Documents.Document_ID FROM Documents LEFT JOIN Paragraphs ON Documents.Document_ID = Paragraphs.Document_ID GROUP BY Documents.Document_ID ORDER BY COUNT(Paragraphs.Paragraph_ID) ASC LIMIT 1
SELECT d.Document_ID FROM Documents d JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID HAVING COUNT(p.Paragraph_ID) BETWEEN 1 AND 2
SELECT d.Document_ID FROM Documents d JOIN Paragraphs p ON d.Document_ID = p.Document_ID GROUP BY d.Document_ID HAVING COUNT(p.Paragraph_ID) BETWEEN 1 AND 2
SELECT DISTINCT d.Document_ID FROM Documents d JOIN Paragraphs p1 ON d.Document_ID = p1.Document_ID JOIN Paragraphs p2 ON d.Document_ID = p2.Document_ID WHERE p1.Paragraph_Text = 'Brazil'   AND p2.Paragraph_Text = 'Ireland'
SELECT DISTINCT d.Document_ID FROM Documents d JOIN Paragraphs p1 ON d.Document_ID = p1.Document_ID JOIN Paragraphs p2 ON d.Document_ID = p2.Document_ID WHERE p1.Paragraph_Text LIKE '%Brazil%'   AND p2.Paragraph_Text LIKE '%Ireland%'
SELECT COUNT(*) AS teacher_count FROM teacher
SELECT COUNT(*) AS total_count FROM teacher
SELECT Name FROM teacher ORDER BY CAST(Age AS INTEGER) ASC
SELECT Name FROM teacher ORDER BY CAST(Age AS INTEGER) ASC
SELECT Age, Hometown FROM teacher
SELECT Age, Hometown FROM teacher
SELECT Name FROM teacher WHERE Hometown != 'Little Lever Urban District'
SELECT Name FROM teacher WHERE Hometown != 'Little Lever Urban District'
SELECT Name FROM teacher WHERE Age IN (32, 33)
SELECT Name FROM teacher WHERE Age IN (32, 33)
SELECT Hometown  FROM teacher  ORDER BY Age ASC  LIMIT 1
SELECT Hometown  FROM teacher  ORDER BY CAST(Age AS INTEGER) ASC  LIMIT 1
SELECT Hometown, COUNT(*) AS number_of_teachers FROM teacher GROUP BY Hometown ORDER BY Hometown
SELECT Hometown, COUNT(*) AS teacher_count FROM teacher GROUP BY Hometown
SELECT teacher.Hometown FROM teacher GROUP BY teacher.Hometown ORDER BY COUNT(*) DESC LIMIT 1
SELECT teacher.Hometown, COUNT(*) AS cnt FROM teacher JOIN course_arrange ON teacher.Teacher_ID = course_arrange.Teacher_ID JOIN course ON course_arrange.Course_ID = course.Course_ID GROUP BY teacher.Hometown ORDER BY cnt DESC LIMIT 1
SELECT t.Hometown FROM teacher t GROUP BY t.Hometown HAVING COUNT(t.Teacher_ID) >= 2
SELECT t.Hometown FROM teacher t GROUP BY t.Hometown HAVING COUNT(t.Teacher_ID) >= 2
SELECT t.Name, ca.Course_ID FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID
SELECT t.Name, c.Course FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID JOIN course c ON ca.Course_ID = c.Course_ID
SELECT t.Name, ca.Course_ID FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID ORDER BY t.Name ASC
SELECT t.Name AS teacher_name, c.Course AS course_name FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID JOIN course c ON ca.Course_ID = c.Course_ID ORDER BY t.Name ASC
SELECT t.Name  FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID JOIN course c ON ca.Course_ID = c.Course_ID WHERE c.Course LIKE '%math%'
SELECT t.Name FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID JOIN course c ON ca.Course_ID = c.Course_ID WHERE c.Course LIKE '%math%'
SELECT t.Name, COUNT(ca.Course_ID) AS course_count FROM teacher t LEFT JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID GROUP BY t.Teacher_ID, t.Name
SELECT t.Name, COUNT(ca.Course_ID) AS course_count FROM teacher t LEFT JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID GROUP BY t.Teacher_ID, t.Name
SELECT t.Name FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID GROUP BY t.Teacher_ID, t.Name HAVING COUNT(DISTINCT ca.Course_ID) >= 2
SELECT t.Name FROM teacher t JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID GROUP BY t.Teacher_ID, t.Name HAVING COUNT(DISTINCT ca.Course_ID) >= 2
SELECT t.Name FROM teacher t LEFT JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID WHERE ca.Teacher_ID IS NULL
SELECT t.Name FROM teacher t LEFT JOIN course_arrange ca ON t.Teacher_ID = ca.Teacher_ID WHERE ca.Teacher_ID IS NULL
SELECT COUNT(*)  FROM visitor  WHERE Age < 30
SELECT Name FROM visitor WHERE Level_of_membership > 4 ORDER BY Level_of_membership DESC
SELECT AVG(CAST(Age AS REAL))  FROM visitor  WHERE Level_of_membership <= 4
SELECT Name, Level_of_membership FROM visitor WHERE Level_of_membership > 4 ORDER BY Age DESC
SELECT Museum_ID, Name FROM museum ORDER BY Num_of_Staff DESC LIMIT 1
SELECT AVG(CAST(Num_of_Staff AS REAL)) FROM museum WHERE Open_Year < '2009'
SELECT Open_Year, Num_of_Staff FROM museum WHERE Name = 'Plaza Museum'
SELECT Name FROM museum WHERE Num_of_Staff > (     SELECT MIN(Num_of_Staff)     FROM museum     WHERE Open_Year = '2010' )
SELECT v.ID, v.Name, v.Age FROM visitor v JOIN visit vi ON v.ID = vi.visitor_ID GROUP BY v.ID, v.Name, v.Age HAVING COUNT(vi.Museum_ID) > 1
SELECT v.ID, v.Name, v.Level_of_membership FROM visitor v JOIN visit vi ON v.ID = vi.visitor_ID GROUP BY v.ID, v.Name, v.Level_of_membership HAVING SUM(vi.Total_spent) = (     SELECT MAX(total_spent)     FROM (         SELECT SUM(vi2.Total_spent) AS total_spent         FROM visitor v2         JOIN visit vi2 ON v2.ID = vi2.visitor_ID         GROUP BY v2.ID     ) )
SELECT m.Museum_ID AS id, m.Name AS name FROM museum m JOIN visit v ON m.Museum_ID = v.Museum_ID GROUP BY m.Museum_ID, m.Name ORDER BY SUM(v.Num_of_Ticket) DESC LIMIT 1
SELECT m.Name FROM museum m LEFT JOIN visit v ON m.Museum_ID = v.Museum_ID WHERE v.Museum_ID IS NULL
SELECT v.Name, v.Age FROM visitor v JOIN visit vi ON v.ID = vi.visitor_ID WHERE vi.Num_of_Ticket = (SELECT MAX(Num_of_Ticket) FROM visit)
SELECT AVG(Num_of_Ticket) AS average_tickets, MAX(Num_of_Ticket) AS max_tickets FROM visit
SELECT SUM(visit.Total_spent) AS total_ticket_expense FROM visit JOIN visitor ON visit.visitor_ID = visitor.ID WHERE visitor.Level_of_membership = 1
SELECT v.Name FROM visitor v JOIN visit vi ON v.ID = vi.visitor_ID JOIN museum m ON vi.Museum_ID = m.Museum_ID WHERE m.Open_Year < '2009' INTERSECT SELECT v.Name FROM visitor v JOIN visit vi ON v.ID = vi.visitor_ID JOIN museum m ON vi.Museum_ID = m.Museum_ID WHERE m.Open_Year > '2011'
SELECT COUNT(DISTINCT v.ID)  FROM visitor v WHERE v.ID NOT IN (     SELECT DISTINCT v2.ID     FROM visitor v2     JOIN visit vi ON v2.ID = vi.visitor_ID     JOIN museum m ON vi.Museum_ID = m.Museum_ID     WHERE m.Open_Year > '2010' )
SELECT COUNT(*)  FROM museum  WHERE Open_Year > '2013' OR Open_Year < '2008'
SELECT COUNT(*) AS total_players FROM players
SELECT COUNT(*) AS player_count FROM players
SELECT COUNT(*) FROM matches
SELECT COUNT(*) FROM matches
SELECT first_name, birth_date FROM players WHERE country_code = 'USA'
SELECT first_name, birth_date FROM players WHERE country_code = 'USA'
SELECT AVG(loser_age) AS avg_loser_age, AVG(winner_age) AS avg_winner_age FROM matches
SELECT AVG(loser_age) AS avg_loser_age, AVG(winner_age) AS avg_winner_age FROM matches
SELECT AVG(winner_rank) AS avg_winner_rank FROM matches
SELECT AVG(winner_rank) AS avg_winner_rank FROM matches
SELECT MIN(loser_rank) AS highest_rank_of_losers FROM matches
SELECT MIN(loser_rank) AS best_loser_rank FROM matches
SELECT COUNT(DISTINCT country_code) AS distinct_country_codes FROM players
SELECT COUNT(DISTINCT country_code) AS distinct_countries FROM players
SELECT COUNT(DISTINCT matches.loser_name) AS distinct_loser_count FROM matches
SELECT COUNT(DISTINCT loser_name) AS different_loser_names FROM matches
SELECT tourney_name FROM matches GROUP BY tourney_name HAVING COUNT(*) > 10
SELECT tourney_name FROM matches GROUP BY tourney_name HAVING COUNT(*) > 10
SELECT DISTINCT p.first_name, p.last_name FROM players p JOIN matches m1 ON p.player_id = m1.winner_id AND m1.year = 2013 JOIN matches m2 ON p.player_id = m2.winner_id AND m2.year = 2016
SELECT DISTINCT p.first_name, p.last_name FROM players p JOIN matches m1 ON p.player_id = m1.winner_id AND m1.year = 2013 JOIN matches m2 ON p.player_id = m2.winner_id AND m2.year = 2016
SELECT COUNT(*) AS match_count FROM matches WHERE year IN (2013, 2016)
SELECT COUNT(*) AS match_count FROM matches WHERE year = 2013 OR year = 2016
SELECT DISTINCT p.country_code, p.first_name FROM players p JOIN matches m1 ON p.player_id = m1.winner_id JOIN matches m2 ON p.player_id = m2.winner_id WHERE m1.tourney_name = 'WTA Championships'   AND m2.tourney_name = 'Australian Open'
SELECT DISTINCT p.first_name, p.country_code FROM players p JOIN matches m1 ON p.player_id = m1.winner_id JOIN matches m2 ON p.player_id = m2.winner_id WHERE m1.tourney_name = 'WTA Championships'   AND m2.tourney_name = 'Australian Open'   AND m1.round = 'F'   AND m2.round = 'F'
SELECT p.first_name, p.country_code FROM players p ORDER BY p.birth_date ASC LIMIT 1
SELECT      p.first_name,     p.country_code FROM players p WHERE p.birth_date = (SELECT MIN(birth_date) FROM players)
SELECT first_name, last_name FROM players ORDER BY birth_date
SELECT first_name || ' ' || last_name AS full_name FROM players ORDER BY birth_date
SELECT first_name, last_name FROM players WHERE hand = 'L' ORDER BY birth_date
SELECT first_name || ' ' || last_name AS full_name FROM players WHERE hand = 'L' ORDER BY birth_date
SELECT p.first_name, p.country_code FROM players p JOIN rankings r ON p.player_id = r.player_id GROUP BY p.player_id ORDER BY SUM(r.tours) DESC LIMIT 1
SELECT p.first_name, p.country_code FROM players p JOIN rankings r ON p.player_id = r.player_id GROUP BY p.player_id ORDER BY SUM(r.tours) DESC LIMIT 1
SELECT year, COUNT(*) AS match_count FROM matches GROUP BY year ORDER BY match_count DESC LIMIT 1
SELECT year, COUNT(*) AS match_count FROM matches GROUP BY year ORDER BY match_count DESC LIMIT 1
SELECT      players.first_name || ' ' || players.last_name AS name,     matches.winner_rank_points AS rank_points FROM matches JOIN players ON matches.winner_id = players.player_id GROUP BY matches.winner_id ORDER BY COUNT(*) DESC LIMIT 1
SELECT      p.first_name || ' ' || p.last_name AS winner_name,     r.ranking_points FROM players p JOIN matches m ON p.player_id = m.winner_id JOIN rankings r ON p.player_id = r.player_id GROUP BY p.player_id ORDER BY COUNT(*) DESC LIMIT 1
SELECT w.winner_name FROM matches w JOIN players p ON w.winner_id = p.player_id WHERE w.tourney_name = 'Australian Open' ORDER BY w.winner_rank_points DESC LIMIT 1
SELECT winner_name FROM matches WHERE tourney_name = 'Australian Open' ORDER BY winner_rank_points DESC LIMIT 1
SELECT      w.first_name || ' ' || w.last_name AS winner_name,     l.first_name || ' ' || l.last_name AS loser_name FROM matches m JOIN players w ON m.winner_id = w.player_id JOIN players l ON m.loser_id = l.player_id WHERE m.minutes = (SELECT MAX(minutes) FROM matches)
SELECT      m.winner_name AS winner_name,     m.loser_name AS loser_name FROM matches m ORDER BY m.minutes DESC LIMIT 1
SELECT      p.first_name,     AVG(r.ranking) AS avg_ranking FROM players p JOIN rankings r ON p.player_id = r.player_id GROUP BY p.player_id, p.first_name
SELECT p.first_name, AVG(r.ranking) AS average_ranking FROM players p JOIN rankings r ON p.player_id = r.player_id GROUP BY p.player_id, p.first_name
SELECT      p.first_name,     SUM(r.ranking_points) AS total_ranking_points FROM players p JOIN rankings r ON p.player_id = r.player_id GROUP BY p.player_id, p.first_name
SELECT p.first_name, SUM(r.ranking_points) AS total_ranking_points FROM players p JOIN rankings r ON p.player_id = r.player_id GROUP BY p.player_id, p.first_name
SELECT      players.country_code,     COUNT(DISTINCT players.player_id) AS number_of_players FROM players GROUP BY players.country_code ORDER BY players.country_code
SELECT country_code, COUNT(*) AS player_count FROM players GROUP BY country_code
SELECT players.country_code FROM players GROUP BY players.country_code ORDER BY COUNT(players.player_id) DESC LIMIT 1
SELECT country_code FROM players GROUP BY country_code ORDER BY COUNT(player_id) DESC LIMIT 1
SELECT country_code FROM players GROUP BY country_code HAVING COUNT(player_id) > 50
SELECT country_code FROM players GROUP BY country_code HAVING COUNT(player_id) > 50
SELECT ranking_date, SUM(tours) AS total_tours FROM rankings GROUP BY ranking_date
SELECT ranking_date, SUM(tours) AS total_tours FROM rankings GROUP BY ranking_date
SELECT year, COUNT(*) AS match_count FROM matches GROUP BY year ORDER BY year
SELECT year, COUNT(*) AS match_count FROM matches GROUP BY year ORDER BY year
SELECT      p.first_name || ' ' || p.last_name AS name,     m.winner_rank AS rank FROM matches m JOIN players p ON m.winner_id = p.player_id ORDER BY m.winner_age ASC LIMIT 3
SELECT      p.first_name || ' ' || p.last_name AS name,     r.ranking FROM matches m JOIN players p ON m.winner_id = p.player_id JOIN rankings r ON p.player_id = r.player_id ORDER BY m.winner_age ASC LIMIT 3
SELECT COUNT(DISTINCT m.winner_id) FROM matches m JOIN players p ON m.winner_id = p.player_id WHERE m.tourney_name = 'WTA Championships'   AND p.hand = 'L'
SELECT COUNT(DISTINCT matches.winner_id) FROM matches JOIN players ON matches.winner_id = players.player_id WHERE players.hand = 'L'   AND matches.tourney_name LIKE '%WTA Championships%'
SELECT      p.first_name,     p.country_code,     p.birth_date FROM players p JOIN matches m ON p.player_id = m.winner_id WHERE m.winner_rank_points = (     SELECT MAX(winner_rank_points) FROM matches ) LIMIT 1
SELECT      p.first_name,     p.country_code,     p.birth_date FROM players p JOIN matches m ON p.player_id = m.winner_id WHERE m.winner_rank_points = (     SELECT MAX(winner_rank_points) FROM matches ) LIMIT 1
SELECT      p.hand,     COUNT(DISTINCT p.player_id) AS player_count FROM players p GROUP BY p.hand
SELECT      p.hand,     COUNT(DISTINCT p.player_id) AS player_count FROM players p GROUP BY p.hand
SELECT COUNT(*) AS captured_ships FROM ship WHERE disposition_of_ship = 'Captured'
SELECT name, tonnage FROM ship ORDER BY name DESC
SELECT name, date, result FROM battle
SELECT      MAX(death.killed) AS max_death_toll,     MIN(death.killed) AS min_death_toll FROM death
SELECT AVG(CAST(injured AS REAL)) AS avg_injuries FROM death
SELECT      death.killed,     death.injured,     death.note FROM death JOIN ship ON death.caused_by_ship_id = ship.id WHERE ship.tonnage = 't'
SELECT name, result FROM battle WHERE bulgarian_commander != 'Boril'
SELECT DISTINCT b.id, b.name FROM battle b JOIN ship s ON b.id = s.lost_in_battle WHERE s.ship_type = 'Brig'
SELECT b.id, b.name FROM battle b JOIN death d ON b.id = d.caused_by_ship_id GROUP BY b.id, b.name HAVING SUM(d.killed) > 10
SELECT      s.id AS ship_id,     s.name AS ship_name FROM death d JOIN ship s ON d.caused_by_ship_id = s.id GROUP BY s.id, s.name ORDER BY SUM(d.injured) DESC LIMIT 1
SELECT DISTINCT name FROM battle WHERE bulgarian_commander = 'Kaloyan'   AND latin_commander = 'Baldwin I'
SELECT COUNT(DISTINCT result) AS different_results_count FROM battle
```sql SELECT COUNT(*) AS battle_count FROM battle WHERE battle.id NOT IN (     SELECT ship.lost_in_battle     FROM ship     WHERE ship.tonnage = '225' )
SELECT name, date  FROM battle  WHERE result LIKE '%lost%'    AND (result LIKE '%Lettice%' OR result LIKE '%HMS Atalanta%')
SELECT b.name, b.result, b.bulgarian_commander FROM battle b WHERE b.id NOT IN (     SELECT s.lost_in_battle     FROM ship s     WHERE s.location = 'English Channel' )
```sql SELECT note  FROM death  WHERE note LIKE '%East%'
SELECT line_1, line_2 FROM Addresses
SELECT line_1, line_2 FROM Addresses
SELECT COUNT(*) FROM Courses
SELECT COUNT(*) FROM Courses
SELECT course_description FROM Courses WHERE course_name = 'math'
SELECT course_description FROM Courses WHERE course_name LIKE '%math%'
SELECT zip_postcode  FROM Addresses  WHERE city = 'Port Chelsea'
SELECT zip_postcode  FROM Addresses  WHERE city = 'Port Chelsea'
SELECT d.department_name, d.department_id FROM Departments d JOIN Degree_Programs dp ON d.department_id = dp.department_id GROUP BY d.department_id, d.department_name ORDER BY COUNT(dp.degree_program_id) DESC LIMIT 1
SELECT d.department_name, d.department_id FROM Departments d JOIN Degree_Programs dp ON d.department_id = dp.department_id GROUP BY d.department_id, d.department_name ORDER BY COUNT(dp.degree_program_id) DESC LIMIT 1
SELECT COUNT(DISTINCT d.department_id) AS department_count FROM Departments d INNER JOIN Degree_Programs dp ON d.department_id = dp.department_id
SELECT COUNT(DISTINCT Departments.department_id) AS number_of_departments FROM Departments JOIN Degree_Programs ON Departments.department_id = Degree_Programs.department_id
SELECT COUNT(DISTINCT degree_summary_name) AS number_of_degree_names FROM Degree_Programs
SELECT COUNT(*) AS degree_count FROM Degree_Programs
SELECT COUNT(*)  FROM Degree_Programs  JOIN Departments ON Degree_Programs.department_id = Departments.department_id  WHERE Departments.department_name = 'Engineering'
SELECT COUNT(*)  FROM Degree_Programs  JOIN Departments ON Degree_Programs.department_id = Departments.department_id  WHERE Departments.department_name = 'Engineering'
SELECT section_name, section_description FROM Sections
SELECT section_name, section_description FROM Sections
SELECT c.course_name, c.course_id FROM Courses c LEFT JOIN Sections s ON c.course_id = s.course_id GROUP BY c.course_id, c.course_name HAVING COUNT(s.section_id) <= 2
SELECT c.course_name, c.course_id FROM Courses c LEFT JOIN Sections s ON c.course_id = s.course_id GROUP BY c.course_id, c.course_name HAVING COUNT(s.section_id) < 2
SELECT section_name FROM Sections ORDER BY section_name DESC
SELECT section_name FROM Sections ORDER BY section_name DESC
SELECT Semesters.semester_name, Semesters.semester_id FROM Semesters JOIN Student_Enrolment ON Semesters.semester_id = Student_Enrolment.semester_id GROUP BY Semesters.semester_id, Semesters.semester_name ORDER BY COUNT(Student_Enrolment.student_enrolment_id) DESC LIMIT 1
SELECT s.semester_name, s.semester_id FROM Semesters s JOIN Student_Enrolment se ON s.semester_id = se.semester_id GROUP BY s.semester_id, s.semester_name ORDER BY COUNT(se.student_enrolment_id) DESC LIMIT 1
SELECT department_description  FROM Departments  WHERE department_name LIKE '%computer%'
SELECT department_description  FROM Departments  WHERE department_name LIKE '%computer%'
SELECT s.first_name, s.middle_name, s.last_name, s.student_id FROM Students s JOIN Student_Enrolment se1 ON s.student_id = se1.student_id JOIN Student_Enrolment se2 ON s.student_id = se2.student_id AND se1.semester_id = se2.semester_id AND se1.degree_program_id <> se2.degree_program_id GROUP BY s.student_id, se1.semester_id HAVING COUNT(DISTINCT se1.degree_program_id) = 2
SELECT s.first_name, s.middle_name, s.last_name, s.student_id FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id JOIN Semesters sem ON se.semester_id = sem.semester_id GROUP BY s.student_id, se.semester_id HAVING COUNT(DISTINCT se.degree_program_id) = 2
SELECT s.first_name, s.middle_name, s.last_name FROM Student_Enrolment se JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id JOIN Students s ON se.student_id = s.student_id WHERE dp.degree_summary_name = 'Bachelor'
SELECT s.first_name, s.middle_name, s.last_name FROM Student_Enrolment se JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id JOIN Students s ON se.student_id = s.student_id WHERE dp.degree_summary_name LIKE '%Bachelor%' OR dp.degree_summary_description LIKE '%Bachelor%'
SELECT d.degree_summary_name FROM Degree_Programs d JOIN Student_Enrolment e ON d.degree_program_id = e.degree_program_id GROUP BY d.degree_program_id, d.degree_summary_name ORDER BY COUNT(e.student_enrolment_id) DESC LIMIT 1
SELECT      dp.degree_summary_name FROM      Degree_Programs dp     JOIN Student_Enrolment se ON dp.degree_program_id = se.degree_program_id GROUP BY      dp.degree_summary_name ORDER BY      COUNT(se.student_enrolment_id) DESC LIMIT 1
SELECT      dp.degree_program_id,     dp.degree_summary_name FROM      Student_Enrolment se     JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id GROUP BY      dp.degree_program_id, dp.degree_summary_name ORDER BY      COUNT(se.student_enrolment_id) DESC LIMIT 1
SELECT      Degree_Programs.degree_program_id,     Degree_Programs.degree_summary_name FROM      Student_Enrolment     JOIN Degree_Programs ON Student_Enrolment.degree_program_id = Degree_Programs.degree_program_id GROUP BY      Degree_Programs.degree_program_id,     Degree_Programs.degree_summary_name ORDER BY      COUNT(Student_Enrolment.student_enrolment_id) DESC LIMIT 1
SELECT      s.student_id AS id,     s.first_name,     s.middle_name,     s.last_name,     COUNT(se.student_enrolment_id) AS number_of_enrollments,     s.student_id FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id GROUP BY s.student_id ORDER BY number_of_enrollments DESC LIMIT 1
SELECT      s.first_name,     s.middle_name,     s.last_name,     s.student_id,     COUNT(se.student_enrolment_id) AS number_of_enrollments FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id GROUP BY s.student_id ORDER BY number_of_enrollments DESC LIMIT 1
SELECT s.semester_name FROM Semesters s LEFT JOIN Student_Enrolment se ON s.semester_id = se.semester_id WHERE se.semester_id IS NULL
SELECT s.semester_name FROM Semesters s LEFT JOIN Student_Enrolment se ON s.semester_id = se.semester_id WHERE se.semester_id IS NULL
SELECT DISTINCT c.course_name FROM Courses c JOIN Student_Enrolment_Courses sec ON c.course_id = sec.course_id
SELECT DISTINCT c.course_name FROM Courses c JOIN Student_Enrolment_Courses sec ON c.course_id = sec.course_id
SELECT c.course_name FROM Courses c JOIN Student_Enrolment_Courses sec ON c.course_id = sec.course_id GROUP BY c.course_id, c.course_name ORDER BY COUNT(sec.student_course_id) DESC LIMIT 1
SELECT c.course_name FROM Courses c JOIN Student_Enrolment_Courses sec ON c.course_id = sec.course_id GROUP BY c.course_id, c.course_name ORDER BY COUNT(sec.student_enrolment_id) DESC LIMIT 1
SELECT s.last_name FROM Students s JOIN Addresses a ON s.current_address_id = a.address_id WHERE a.state_province_county = 'North Carolina'   AND s.date_first_registered IS NULL
SELECT s.last_name FROM Students s JOIN Addresses a ON s.current_address_id = a.address_id WHERE a.state_province_county = 'North Carolina'   AND s.student_id NOT IN (     SELECT student_id FROM Student_Program_Registrations   )
SELECT      t.transcript_date,     t.transcript_id FROM Transcripts t JOIN Transcript_Contents tc ON t.transcript_id = tc.transcript_id GROUP BY t.transcript_id, t.transcript_date HAVING COUNT(tc.student_course_id) >= 2
SELECT      t.transcript_date,     t.transcript_id FROM Transcripts t JOIN Transcript_Contents tc ON t.transcript_id = tc.transcript_id GROUP BY t.transcript_id, t.transcript_date HAVING COUNT(tc.student_course_id) >= 2
SELECT cell_mobile_number  FROM Students  WHERE first_name = 'Timmothy' AND last_name = 'Ward'
SELECT cell_mobile_number  FROM Students  WHERE first_name = 'Timmothy' AND last_name = 'Ward'
SELECT s.first_name, s.middle_name, s.last_name FROM Students s ORDER BY s.date_first_registered ASC LIMIT 1
SELECT first_name, middle_name, last_name FROM Students ORDER BY date_first_registered ASC LIMIT 1
SELECT      s.first_name,     s.middle_name,     s.last_name FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id JOIN Student_Enrolment_Courses sec ON se.student_enrolment_id = sec.student_enrolment_id JOIN Transcript_Contents tc ON sec.student_course_id = tc.student_course_id JOIN Transcripts t ON tc.transcript_id = t.transcript_id ORDER BY t.transcript_date ASC LIMIT 1
SELECT      s.first_name,     s.middle_name,     s.last_name FROM Students s JOIN Student_Enrolment se ON s.student_id = se.student_id JOIN Student_Enrolment_Courses sec ON se.student_enrolment_id = sec.student_enrolment_id JOIN Transcript_Contents tc ON sec.student_course_id = tc.student_course_id JOIN Transcripts t ON tc.transcript_id = t.transcript_id ORDER BY t.transcript_date ASC LIMIT 1
SELECT s.first_name FROM Students s WHERE s.permanent_address_id != s.current_address_id
SELECT s.first_name FROM Students s WHERE s.permanent_address_id != s.current_address_id
SELECT      a.address_id,     a.line_1,     a.line_2,     a.line_3 FROM Addresses a JOIN Students s ON s.permanent_address_id = a.address_id WHERE s.date_left IS NULL OR s.date_left > CURRENT_TIMESTAMP GROUP BY a.address_id ORDER BY COUNT(*) DESC LIMIT 1
SELECT      a.address_id,     a.line_1,     a.line_2 FROM Addresses a JOIN Students s ON s.current_address_id = a.address_id OR s.permanent_address_id = a.address_id GROUP BY a.address_id, a.line_1, a.line_2 ORDER BY COUNT(s.student_id) DESC LIMIT 1
SELECT AVG(transcript_date) AS average_print_date FROM Transcripts
SELECT AVG(transcript_date) AS avg_transcript_date FROM Transcripts
SELECT MIN(Transcripts.transcript_date) AS transcript_date, Transcripts.other_details FROM Transcripts JOIN Transcript_Contents ON Transcripts.transcript_id = Transcript_Contents.transcript_id
SELECT MIN(Transcripts.transcript_date) AS earliest_transcript_date,        Transcripts.other_details FROM Transcripts JOIN Transcript_Contents ON Transcripts.transcript_id = Transcript_Contents.transcript_id GROUP BY Transcripts.other_details ORDER BY earliest_transcript_date LIMIT 1
SELECT COUNT(*) AS transcript_count FROM Transcripts
SELECT COUNT(*) AS transcript_count FROM Transcripts
SELECT MAX(transcript_date) AS last_transcript_release_date FROM Transcripts
SELECT MAX(transcript_date) AS last_transcript_released FROM Transcripts
-- We need to find the maximum number of distinct transcripts that a course enrollment (student_enrolment_id) appears in. -- Since there is no direct join between Student_Enrolment_Courses and Transcripts, and no other tables are provided, -- we cannot determine how course enrollments relate to transcripts. The question likely expects a query on the available tables. -- However, based on the schema, there is no connection to Transcripts. We will assume the question refers to the student_course_id -- as the "course enrollment id" and count how many times it appears in the Student_Enrolment_Courses table (which is the only table available). -- This is the best we can do with the given schema.  SELECT      student_course_id AS course_enrollment_id,     COUNT(*) AS times_in_different_transcripts FROM Student_Enrolment_Courses GROUP BY student_course_id ORDER BY times_in_different_transcripts DESC LIMIT 1
SELECT      sec.student_enrolment_id,     COUNT(DISTINCT t.transcript_id) AS max_times FROM Student_Enrolment_Courses sec JOIN Transcript_Contents tc ON sec.student_course_id = tc.student_course_id JOIN Transcripts t ON tc.transcript_id = t.transcript_id GROUP BY sec.course_id ORDER BY max_times DESC LIMIT 1
SELECT      t.transcript_date,     t.transcript_id FROM Transcripts t JOIN Transcript_Contents tc ON t.transcript_id = tc.transcript_id GROUP BY t.transcript_id, t.transcript_date ORDER BY COUNT(tc.transcript_id) ASC LIMIT 1
SELECT      t.transcript_date,     t.transcript_id FROM Transcripts t JOIN Transcript_Contents tc ON t.transcript_id = tc.transcript_id GROUP BY t.transcript_id, t.transcript_date ORDER BY COUNT(tc.student_course_id) ASC LIMIT 1
SELECT s.semester_name FROM Semesters s JOIN Student_Enrolment se ON s.semester_id = se.semester_id JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id WHERE dp.degree_summary_name IN ('Master', 'Bachelor') GROUP BY s.semester_id, s.semester_name HAVING COUNT(DISTINCT dp.degree_summary_name) = 2
SELECT DISTINCT se.semester_id FROM Student_Enrolment se JOIN Degree_Programs dp ON se.degree_program_id = dp.degree_program_id WHERE dp.degree_summary_name LIKE '%Masters%'    OR dp.degree_summary_name LIKE '%Bachelors%' GROUP BY se.semester_id HAVING COUNT(DISTINCT CASE      WHEN dp.degree_summary_name LIKE '%Masters%' THEN 'Masters'     WHEN dp.degree_summary_name LIKE '%Bachelors%' THEN 'Bachelors' END) = 2
SELECT COUNT(DISTINCT Addresses.address_id)  FROM Students  JOIN Addresses ON Students.current_address_id = Addresses.address_id
SELECT DISTINCT a.line_1, a.line_2, a.line_3, a.city, a.zip_postcode, a.state_province_county, a.country FROM Addresses a JOIN Students s ON s.permanent_address_id = a.address_id
SELECT * FROM Students ORDER BY first_name DESC, middle_name DESC, last_name DESC
SELECT other_student_details FROM Students ORDER BY first_name DESC, middle_name DESC, last_name DESC
SELECT section_description  FROM Sections  WHERE section_name = 'h' OR section_description = 'h' LIMIT 1
SELECT section_description  FROM Sections  WHERE section_name = 'h'
SELECT s.first_name FROM Students s JOIN Addresses a ON s.permanent_address_id = a.address_id WHERE a.country = 'Haiti' OR s.cell_mobile_number = '09700166582'
SELECT DISTINCT s.first_name FROM Students s JOIN Addresses a ON s.permanent_address_id = a.address_id WHERE a.country = 'Haiti'    OR s.cell_mobile_number = '09700166582'
SELECT Title FROM Cartoon ORDER BY Title ASC
SELECT Title FROM Cartoon ORDER BY Title ASC
SELECT Title, Directed_by, Original_air_date, Production_code, Channel FROM Cartoon WHERE Directed_by = 'Ben Jones'
SELECT Title  FROM Cartoon  WHERE Directed_by = 'Ben Jones'
SELECT COUNT(*) FROM Cartoon WHERE Written_by = 'Joseph Kuhr'
SELECT COUNT(*)  FROM Cartoon  WHERE Written_by = 'Joseph Kuhr'
SELECT Title, Directed_by FROM Cartoon ORDER BY Original_air_date
SELECT      c.Title AS name,     c.Directed_by AS directors FROM Cartoon c ORDER BY c.Original_air_date
SELECT Title FROM Cartoon WHERE Directed_by = 'Ben Jones' OR Directed_by = 'Brandon Vietti'
SELECT Title FROM Cartoon WHERE Directed_by IN ('Ben Jones', 'Brandon Vietti')
SELECT Country, COUNT(*) AS number_of_channels FROM TV_Channel GROUP BY Country ORDER BY number_of_channels DESC LIMIT 1
SELECT Country, COUNT(*) AS channel_count FROM TV_Channel GROUP BY Country ORDER BY channel_count DESC LIMIT 1
SELECT COUNT(DISTINCT series_name) AS distinct_series_names,        COUNT(DISTINCT Content) AS distinct_contents FROM TV_Channel
SELECT COUNT(DISTINCT series_name) AS different_series, COUNT(DISTINCT Content) AS different_contents FROM TV_Channel
SELECT Content  FROM TV_Channel  WHERE series_name = 'Sky Radio'
SELECT Content  FROM TV_Channel  WHERE series_name = 'Sky Radio'
SELECT Package_Option FROM TV_Channel WHERE series_name = 'Sky Radio'
SELECT TV_Channel.Package_Option FROM TV_Channel WHERE TV_Channel.series_name = 'Sky Radio'
SELECT COUNT(*)  FROM TV_Channel  WHERE Language = 'English'
SELECT COUNT(*)  FROM TV_Channel  WHERE Language = 'English'
SELECT TV_Channel.Language, COUNT(*) AS number_of_channels FROM TV_Channel GROUP BY TV_Channel.Language ORDER BY number_of_channels ASC LIMIT 1
SELECT Language, COUNT(*) AS channel_count FROM TV_Channel GROUP BY Language HAVING COUNT(*) = (     SELECT MIN(cnt) FROM (         SELECT COUNT(*) AS cnt         FROM TV_Channel         GROUP BY Language     ) ) ORDER BY Language
SELECT Language, COUNT(*) AS channel_count FROM TV_Channel GROUP BY Language
SELECT Language, COUNT(*) AS channel_count FROM TV_Channel GROUP BY Language
SELECT TV_Channel.series_name FROM Cartoon JOIN TV_Channel ON Cartoon.Channel = TV_Channel.id WHERE Cartoon.Title = 'The Rise of the Blue Beetle!'
SELECT TV_Channel.series_name FROM Cartoon JOIN TV_Channel ON Cartoon.Channel = TV_Channel.id WHERE Cartoon.Title LIKE '%The Rise of the Blue Beetle%'
SELECT Cartoon.Title FROM Cartoon JOIN TV_Channel ON Cartoon.Channel = TV_Channel.id WHERE TV_Channel.series_name = 'Sky Radio'
SELECT Cartoon.Title FROM Cartoon JOIN TV_Channel ON Cartoon.Channel = TV_Channel.id WHERE TV_Channel.series_name = 'Sky Radio'
SELECT Episode FROM TV_series ORDER BY Rating
SELECT Episode FROM TV_series ORDER BY Rating
SELECT      TV_series.Episode,     TV_series.Rating FROM TV_series ORDER BY CAST(TV_series.Rating AS REAL) DESC LIMIT 3
SELECT Episode, Rating FROM TV_series ORDER BY CAST(Rating AS REAL) DESC LIMIT 3
SELECT MIN(Share) AS min_share, MAX(Share) AS max_share FROM TV_series
SELECT MAX(Share) AS max_share, MIN(Share) AS min_share FROM TV_series
SELECT Air_Date FROM TV_series WHERE Episode = 'A Love of a Lifetime'
SELECT Air_Date FROM TV_series WHERE Episode = 'A Love of a Lifetime'
SELECT Weekly_Rank  FROM TV_series  WHERE Episode = 'A Love of a Lifetime'
SELECT Weekly_Rank  FROM TV_series  WHERE Episode = 'A Love of a Lifetime'
SELECT TV_Channel.series_name FROM TV_series JOIN TV_Channel ON TV_series.Channel = TV_Channel.id WHERE TV_series.Episode = 'A Love of a Lifetime'
SELECT Episode  FROM TV_series  WHERE Episode = 'A Love of a Lifetime'
SELECT TV_series.Episode FROM TV_series JOIN TV_Channel ON TV_series.Channel = TV_Channel.id WHERE TV_Channel.series_name = 'Sky Radio'
SELECT TV_series.Episode  FROM TV_series  JOIN TV_Channel ON TV_series.Channel = TV_Channel.id  WHERE TV_Channel.series_name = 'Sky Radio'
SELECT Directed_by, COUNT(*) AS number_of_cartoons FROM Cartoon GROUP BY Directed_by
SELECT Directed_by, COUNT(*) AS cartoon_count FROM Cartoon GROUP BY Directed_by
SELECT Production_code, Channel FROM Cartoon ORDER BY Original_air_date DESC LIMIT 1
SELECT      Cartoon.Production_code,      Cartoon.Channel FROM Cartoon ORDER BY Cartoon.Original_air_date DESC LIMIT 1
SELECT Package_Option, series_name FROM TV_Channel WHERE Hight_definition_TV = 'yes'
SELECT Package_Option, series_name FROM TV_Channel WHERE Hight_definition_TV = 'yes'
SELECT DISTINCT TV_Channel.Country FROM Cartoon JOIN TV_Channel ON Cartoon.Channel = TV_Channel.id WHERE Cartoon.Written_by = 'Todd Casey'
SELECT DISTINCT TV_Channel.Country FROM Cartoon JOIN TV_Channel ON Cartoon.Channel = TV_Channel.id WHERE Cartoon.Written_by = 'Todd Casey'
SELECT DISTINCT t.Country FROM TV_Channel t WHERE t.id NOT IN (     SELECT c.Channel     FROM Cartoon c     WHERE c.Written_by = 'Todd Casey' )
SELECT DISTINCT TV_Channel.Country FROM TV_Channel WHERE TV_Channel.id NOT IN (     SELECT Cartoon.Channel     FROM Cartoon     WHERE Cartoon.Written_by = 'Todd Casey' )
SELECT DISTINCT     T.series_name,     T.Country FROM TV_Channel T JOIN Cartoon C ON C.Channel = T.id WHERE C.Directed_by IN ('Ben Jones', 'Michael Chang')
SELECT DISTINCT     TV_Channel.series_name,     TV_Channel.Country FROM TV_Channel JOIN Cartoon ON Cartoon.Channel = TV_Channel.id WHERE Cartoon.Directed_by = 'Ben Jones'    OR Cartoon.Directed_by = 'Michael Chang'
SELECT Pixel_aspect_ratio_PAR AS pixel_aspect_ratio, Country AS nation FROM TV_Channel WHERE Language != 'English'
SELECT      TV_Channel.Pixel_aspect_ratio_PAR,      TV_Channel.Country FROM TV_Channel WHERE TV_Channel.Language != 'English'
SELECT id FROM TV_Channel WHERE Country IN (     SELECT Country     FROM TV_Channel     GROUP BY Country     HAVING COUNT(*) > 2 )
SELECT id FROM TV_Channel GROUP BY id HAVING COUNT(*) > 2
SELECT TV_Channel.id FROM TV_Channel WHERE TV_Channel.id NOT IN (     SELECT Cartoon.Channel     FROM Cartoon     WHERE Cartoon.Directed_by = 'Ben Jones' )
```sql SELECT TV_Channel.id FROM TV_Channel WHERE TV_Channel.id NOT IN (     SELECT DISTINCT Cartoon.Channel     FROM Cartoon     WHERE Cartoon.Directed_by = 'Ben Jones' )
SELECT DISTINCT c.Package_Option FROM TV_Channel c WHERE c.id NOT IN (     SELECT DISTINCT ca.Channel     FROM Cartoon ca     WHERE ca.Directed_by = 'Ben Jones' )
SELECT DISTINCT t.Package_Option FROM TV_Channel t WHERE t.id NOT IN (     SELECT c.Channel     FROM Cartoon c     WHERE c.Directed_by = 'Ben Jones' )
SELECT COUNT(*) FROM poker_player
SELECT COUNT(*) FROM poker_player
SELECT Earnings FROM poker_player ORDER BY Earnings DESC
SELECT Earnings  FROM poker_player  ORDER BY Earnings DESC
SELECT Final_Table_Made, Best_Finish FROM poker_player
SELECT Final_Table_Made, Best_Finish FROM poker_player
SELECT AVG(CAST(Earnings AS REAL)) AS average_earnings FROM poker_player
SELECT AVG(Earnings) FROM poker_player
SELECT Money_Rank  FROM poker_player  WHERE Earnings = (SELECT MAX(Earnings) FROM poker_player)
SELECT Money_Rank  FROM poker_player  ORDER BY Earnings DESC  LIMIT 1
SELECT MAX(Final_Table_Made)  FROM poker_player  WHERE Earnings < 200000
SELECT MAX(Final_Table_Made)  FROM poker_player  WHERE Earnings < 200000
SELECT people.Name FROM people JOIN poker_player ON people.People_ID = poker_player.People_ID
SELECT Name FROM people
SELECT p.Name FROM people p JOIN poker_player pp ON p.People_ID = pp.People_ID WHERE pp.Earnings > 300000
SELECT p.Name FROM people p JOIN poker_player pp ON p.People_ID = pp.People_ID WHERE pp.Earnings > 300000
SELECT people.Name  FROM poker_player  JOIN people ON poker_player.People_ID = people.People_ID  ORDER BY poker_player.Final_Table_Made ASC
SELECT p.Name FROM poker_player AS pp JOIN people AS p ON pp.People_ID = p.People_ID ORDER BY pp.Final_Table_Made ASC
SELECT p.Birth_Date FROM people p JOIN poker_player pp ON p.People_ID = pp.People_ID ORDER BY pp.Earnings ASC LIMIT 1
SELECT people.Birth_Date FROM people JOIN poker_player ON people.People_ID = poker_player.People_ID ORDER BY poker_player.Earnings ASC LIMIT 1
SELECT p.Money_Rank FROM poker_player p JOIN people pe ON p.People_ID = pe.People_ID ORDER BY pe.Height DESC LIMIT 1
SELECT p.Money_Rank FROM poker_player p JOIN people pe ON p.People_ID = pe.People_ID ORDER BY pe.Height DESC LIMIT 1
SELECT AVG(p.Earnings)  FROM poker_player p  JOIN people pe ON p.People_ID = pe.People_ID  WHERE pe.Height > 200
SELECT AVG(p.Earnings)  FROM poker_player p  JOIN people pe ON p.People_ID = pe.People_ID  WHERE pe.Height > 200
SELECT p.Name FROM people p JOIN poker_player pp ON p.People_ID = pp.People_ID ORDER BY pp.Earnings DESC
SELECT people.Name FROM poker_player JOIN people ON poker_player.People_ID = people.People_ID ORDER BY poker_player.Earnings DESC
SELECT people.Nationality, COUNT(*) AS number_of_people FROM people GROUP BY people.Nationality
SELECT Nationality, COUNT(*) AS count FROM people GROUP BY Nationality
SELECT Nationality, COUNT(*) AS count FROM people GROUP BY Nationality ORDER BY count DESC LIMIT 1
SELECT people.Nationality FROM people GROUP BY people.Nationality ORDER BY COUNT(*) DESC LIMIT 1
SELECT Nationality FROM people GROUP BY Nationality HAVING COUNT(*) >= 2
SELECT Nationality FROM people GROUP BY Nationality HAVING COUNT(*) >= 2
SELECT Name, Birth_Date FROM people ORDER BY Name ASC
SELECT Name, Birth_Date FROM people ORDER BY Name ASC
SELECT Name FROM people WHERE Nationality != 'Russia'
SELECT Name FROM people WHERE Nationality != 'Russia'
SELECT p.Name FROM people p WHERE p.People_ID NOT IN (     SELECT pp.People_ID     FROM poker_player pp )
SELECT Name  FROM people  WHERE People_ID NOT IN (     SELECT People_ID      FROM poker_player )
SELECT COUNT(DISTINCT Nationality) FROM people
SELECT COUNT(DISTINCT Nationality) AS nationality_count FROM people
SELECT COUNT(DISTINCT state) AS state_count FROM AREA_CODE_STATE
SELECT contestant_number, contestant_name FROM CONTESTANTS ORDER BY contestant_name DESC
SELECT vote_id, phone_number, state FROM VOTES
SELECT MAX(area_code) AS max_area_code, MIN(area_code) AS min_area_code FROM AREA_CODE_STATE
SELECT MAX(created) AS last_date_created FROM VOTES WHERE state = 'CA'
SELECT contestant_name FROM CONTESTANTS WHERE contestant_name != 'Jessie Alloway'
SELECT DISTINCT state, created FROM VOTES
SELECT c.contestant_number, c.contestant_name FROM CONTESTANTS c JOIN VOTES v ON c.contestant_number = v.contestant_number GROUP BY c.contestant_number, c.contestant_name HAVING COUNT(v.vote_id) >= 2
SELECT c.contestant_number, c.contestant_name FROM CONTESTANTS c JOIN VOTES v ON c.contestant_number = v.contestant_number GROUP BY c.contestant_number, c.contestant_name ORDER BY COUNT(v.vote_id) ASC LIMIT 1
SELECT COUNT(*) AS number_of_votes FROM VOTES WHERE state IN ('NY', 'CA')
SELECT COUNT(*) AS contestants_without_votes FROM CONTESTANTS c LEFT JOIN VOTES v ON c.contestant_number = v.contestant_number WHERE v.vote_id IS NULL
SELECT      AREA_CODE_STATE.area_code FROM      VOTES     JOIN AREA_CODE_STATE ON VOTES.state = AREA_CODE_STATE.state GROUP BY      AREA_CODE_STATE.area_code ORDER BY      COUNT(VOTES.vote_id) DESC LIMIT 1
SELECT v.created, v.state, v.phone_number FROM VOTES v JOIN CONTESTANTS c ON v.contestant_number = c.contestant_number WHERE c.contestant_name = 'Tabatha Gehling'
SELECT DISTINCT a.area_code FROM VOTES v JOIN AREA_CODE_STATE a ON v.state = a.state JOIN CONTESTANTS c ON v.contestant_number = c.contestant_number WHERE c.contestant_name = 'Tabatha Gehling' INTERSECT SELECT DISTINCT a.area_code FROM VOTES v JOIN AREA_CODE_STATE a ON v.state = a.state JOIN CONTESTANTS c ON v.contestant_number = c.contestant_number WHERE c.contestant_name = 'Kelly Clauss'
SELECT contestant_name FROM CONTESTANTS WHERE contestant_name LIKE '%Al%'
SELECT Name  FROM country  WHERE IndepYear > 1950
SELECT Name FROM country WHERE IndepYear > 1950
SELECT COUNT(*)  FROM country  WHERE GovernmentForm LIKE '%Republic%'
SELECT COUNT(*)  FROM country  WHERE GovernmentForm LIKE '%Republic%'
SELECT SUM(SurfaceArea) AS total_surface_area FROM country WHERE Region = 'Caribbean'
SELECT SUM(SurfaceArea) AS total_surface_area FROM country WHERE Region = 'Caribbean'
SELECT Continent FROM country WHERE Name = 'Anguilla' OR LocalName = 'Anguilla'
SELECT Continent FROM country WHERE Name = 'Anguilla' OR LocalName = 'Anguilla'
SELECT country.Region FROM city JOIN country ON city.CountryCode = country.Code WHERE city.Name = 'Kabul'
SELECT c.Region FROM country c JOIN city ci ON ci.CountryCode = c.Code WHERE ci.Name = 'Kabul'
SELECT cl.Language FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code WHERE c.Name = 'Aruba' ORDER BY cl.Percentage DESC LIMIT 1
SELECT cl.Language FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE c.Name = 'Aruba' ORDER BY cl.Percentage DESC LIMIT 1
SELECT Population, LifeExpectancy FROM country WHERE Name = 'Brazil'
SELECT Population, LifeExpectancy FROM country WHERE Name = 'Brazil'
SELECT Region, Population FROM country WHERE Name = 'Angola'
SELECT Region, Population FROM country WHERE Name = 'Angola'
SELECT AVG(LifeExpectancy) AS avg_life_expectancy FROM country WHERE Region = 'Central Africa'
SELECT LifeExpectancy  FROM country  WHERE Name = 'Central African Republic'     OR Region = 'Central Africa'
SELECT Name  FROM country  WHERE Continent = 'Asia'  ORDER BY LifeExpectancy ASC  LIMIT 1
SELECT Name  FROM country  WHERE Continent = 'Asia'  ORDER BY LifeExpectancy ASC  LIMIT 1
SELECT SUM(Population) AS total_population, MAX(GNP) AS max_gnp FROM country WHERE Continent = 'Asia' OR Region = 'Asia'
SELECT SUM(Population) AS total_population, MAX(GNP) AS largest_gnp FROM country WHERE Continent = 'Asia' OR Region = 'Asia'
SELECT AVG(LifeExpectancy)  FROM country  WHERE Continent = 'Africa'    AND GovernmentForm LIKE '%Republic%'
SELECT AVG(LifeExpectancy)  FROM country  WHERE Continent = 'Africa'    AND GovernmentForm LIKE '%Republic%'
SELECT SUM(SurfaceArea) AS total_surface_area FROM country WHERE Continent IN ('Asia', 'Europe')
SELECT SUM(SurfaceArea) AS total_surface_area FROM country WHERE Continent = 'Asia' OR Continent = 'Europe'
SELECT SUM(city.Population) AS total_population FROM city JOIN country ON city.CountryCode = country.Code WHERE city.District = 'Gelderland'
SELECT SUM(city.Population) AS total_population FROM city WHERE city.District = 'Gelderland'
SELECT AVG(GNP) AS average_gnp, SUM(Population) AS total_population FROM country WHERE GovernmentForm = 'US territory'
SELECT AVG(GNP) AS mean_gnp, SUM(Population) AS total_population FROM country WHERE GovernmentForm LIKE '%US territory%' OR GovernmentForm LIKE '%United States territory%'
SELECT COUNT(DISTINCT Language) AS unique_languages FROM countrylanguage
SELECT COUNT(DISTINCT Language) AS distinct_languages FROM countrylanguage
SELECT COUNT(DISTINCT GovernmentForm)  FROM country  WHERE Continent = 'Africa' OR Name = 'Africa' OR Region = 'Africa' OR LocalName = 'Africa'
SELECT COUNT(DISTINCT GovernmentForm)  FROM country  WHERE Continent = 'Africa' OR Region = 'Africa' OR Name = 'Africa' OR LocalName = 'Africa'
SELECT COUNT(*) AS total_languages FROM countrylanguage JOIN country ON countrylanguage.CountryCode = country.Code WHERE country.Name = 'Aruba'
SELECT COUNT(*) AS language_count FROM countrylanguage JOIN country ON countrylanguage.CountryCode = country.Code WHERE country.Name = 'Aruba'
SELECT COUNT(*)  FROM countrylanguage  WHERE CountryCode = 'AFG'    AND IsOfficial = 'T'
SELECT COUNT(*)  FROM countrylanguage  JOIN country ON countrylanguage.CountryCode = country.Code  WHERE country.Name = 'Afghanistan'    AND countrylanguage.IsOfficial = 'T'
SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode GROUP BY c.Code, c.Name ORDER BY COUNT(cl.Language) DESC LIMIT 1
SELECT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode GROUP BY c.Code, c.Name ORDER BY COUNT(cl.Language) DESC LIMIT 1
SELECT      c.Continent,     COUNT(DISTINCT cl.Language) AS language_count FROM      country c     JOIN countrylanguage cl ON c.Code = cl.CountryCode GROUP BY      c.Continent ORDER BY      language_count DESC LIMIT 1
SELECT      c.Continent,     COUNT(DISTINCT cl.Language) AS language_count FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode GROUP BY c.Continent ORDER BY language_count DESC LIMIT 1
SELECT COUNT(DISTINCT c.Code) FROM country c JOIN countrylanguage cl1 ON c.Code = cl1.CountryCode AND cl1.Language = 'English' JOIN countrylanguage cl2 ON c.Code = cl2.CountryCode AND cl2.Language = 'Dutch'
SELECT COUNT(DISTINCT c.Code) AS number_of_nations FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language IN ('English', 'Dutch')
SELECT c.Name FROM country c JOIN countrylanguage cl1 ON c.Code = cl1.CountryCode AND cl1.Language = 'English' JOIN countrylanguage cl2 ON c.Code = cl2.CountryCode AND cl2.Language = 'French'
SELECT c.Name FROM country c JOIN countrylanguage cl1 ON c.Code = cl1.CountryCode AND cl1.Language = 'English' JOIN countrylanguage cl2 ON c.Code = cl2.CountryCode AND cl2.Language = 'French'
SELECT c.Name FROM country c JOIN countrylanguage cl1 ON c.Code = cl1.CountryCode AND cl1.Language = 'English' AND cl1.IsOfficial = 'T' JOIN countrylanguage cl2 ON c.Code = cl2.CountryCode AND cl2.Language = 'French' AND cl2.IsOfficial = 'T'
SELECT c.Name FROM country c JOIN countrylanguage cl1 ON c.Code = cl1.CountryCode JOIN countrylanguage cl2 ON c.Code = cl2.CountryCode WHERE cl1.Language = 'English' AND cl1.IsOfficial = 'T'   AND cl2.Language = 'French' AND cl2.IsOfficial = 'T'
SELECT COUNT(DISTINCT country.Continent) FROM country JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE countrylanguage.Language = 'Chinese'
SELECT COUNT(DISTINCT country.Continent)  FROM country  JOIN countrylanguage ON country.Code = countrylanguage.CountryCode  WHERE countrylanguage.Language = 'Chinese'
SELECT DISTINCT c.Region FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language IN ('English', 'Dutch')
SELECT DISTINCT c.Region FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language IN ('Dutch', 'English')
SELECT DISTINCT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language IN ('English', 'Dutch')   AND cl.IsOfficial = 'T'
SELECT DISTINCT c.Name FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language IN ('English', 'Dutch')   AND cl.IsOfficial = 'T'
SELECT cl.Language FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code WHERE c.Continent = 'Asia' GROUP BY cl.Language ORDER BY SUM(cl.Percentage) DESC LIMIT 1
SELECT cl.Language FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code WHERE c.Continent = 'Asia' GROUP BY cl.Language ORDER BY COUNT(DISTINCT c.Code) DESC LIMIT 1
SELECT cl.Language FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code WHERE c.GovernmentForm LIKE '%Republic%' GROUP BY cl.Language HAVING COUNT(DISTINCT c.Code) = 1
-- Find languages that are spoken in exactly one country that has a republic government SELECT cl.Language FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code WHERE c.GovernmentForm LIKE '%Republic%' GROUP BY cl.Language HAVING COUNT(DISTINCT cl.CountryCode) = 1
SELECT c.Name  FROM city c  JOIN country co ON c.CountryCode = co.Code  JOIN countrylanguage cl ON cl.CountryCode = co.Code  WHERE cl.Language = 'English'  ORDER BY c.Population DESC  LIMIT 1
SELECT c.Name, c.Population FROM city c JOIN country co ON c.CountryCode = co.Code JOIN countrylanguage cl ON co.Code = cl.CountryCode WHERE cl.Language = 'English' ORDER BY c.Population DESC LIMIT 1
SELECT Name, Population, LifeExpectancy FROM country WHERE Continent = 'Asia' ORDER BY SurfaceArea DESC LIMIT 1
SELECT Name, Population, LifeExpectancy FROM country WHERE Continent = 'Asia' ORDER BY SurfaceArea DESC LIMIT 1
SELECT AVG(country.LifeExpectancy) FROM country JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE countrylanguage.Language = 'English' AND countrylanguage.IsOfficial != 'T'
SELECT AVG(c.LifeExpectancy) FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'English' AND cl.IsOfficial = 'T'   AND c.Code NOT IN (     SELECT cl2.CountryCode     FROM countrylanguage cl2     WHERE cl2.Language = 'English' AND cl2.IsOfficial = 'T'   )
SELECT SUM(c.Population) AS total_population FROM country c WHERE c.Code NOT IN (     SELECT cl.CountryCode     FROM countrylanguage cl     WHERE cl.Language = 'English' )
SELECT SUM(country.Population) AS total_population FROM country WHERE country.Code NOT IN (     SELECT DISTINCT countrylanguage.CountryCode     FROM countrylanguage     WHERE countrylanguage.Language = 'English' )
SELECT cl.Language FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE c.HeadOfState = 'Beatrix'   AND cl.IsOfficial = 'T'
SELECT cl.Language FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE c.HeadOfState = 'Beatrix'   AND cl.IsOfficial = 'T'
SELECT COUNT(DISTINCT cl.Language) FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code WHERE cl.IsOfficial = 'T'   AND c.IndepYear < 1930
SELECT COUNT(DISTINCT cl.Language) AS total_official_languages FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE c.IndepYear < 1930   AND cl.IsOfficial = 'T'
SELECT Name  FROM country  WHERE SurfaceArea > (SELECT MAX(SurfaceArea) FROM country WHERE Continent = 'Europe')
SELECT Name  FROM country  WHERE SurfaceArea > (     SELECT MIN(SurfaceArea)      FROM country      WHERE Continent = 'Europe' )
SELECT c.Name FROM country c WHERE c.Continent = 'Africa'   AND c.Population < (     SELECT MIN(c2.Population)     FROM country c2     WHERE c2.Continent = 'Asia'   )
SELECT c.Name  FROM country c  WHERE c.Continent = 'Africa'    AND c.Population < (SELECT MIN(c2.Population) FROM country c2 WHERE c2.Continent = 'Asia')
SELECT c.Name FROM country c WHERE c.Continent = 'Asia'   AND c.Population > (SELECT MAX(c2.Population) FROM country c2 WHERE c2.Continent = 'Africa')
SELECT c.Name FROM country c WHERE c.Continent = 'Asia'   AND c.Population > (     SELECT MAX(c2.Population)     FROM country c2     WHERE c2.Continent = 'Africa'   )
SELECT DISTINCT country.Code FROM country WHERE country.Code NOT IN (     SELECT countrylanguage.CountryCode     FROM countrylanguage     WHERE countrylanguage.Language = 'English' )
SELECT c.Code FROM country c WHERE c.Code NOT IN (     SELECT cl.CountryCode     FROM countrylanguage cl     WHERE cl.Language = 'English' )
SELECT DISTINCT country.Code FROM country JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE countrylanguage.Language != 'English'
SELECT DISTINCT country.Code FROM country JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE countrylanguage.Language != 'English'
SELECT DISTINCT c.Code FROM country c WHERE c.Code NOT IN (     SELECT cl.CountryCode     FROM countrylanguage cl     WHERE cl.Language = 'English' ) AND c.GovernmentForm != 'Republic'
SELECT DISTINCT c.Code FROM country c WHERE c.Code NOT IN (     SELECT cl.CountryCode     FROM countrylanguage cl     WHERE cl.Language = 'English' ) AND c.GovernmentForm NOT LIKE '%Republic%'
SELECT city.Name FROM city JOIN country ON city.CountryCode = country.Code JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Continent = 'Europe'   AND countrylanguage.Language = 'English'   AND countrylanguage.IsOfficial = 'F'
SELECT city.Name FROM city JOIN country ON city.CountryCode = country.Code JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Continent = 'Europe'   AND countrylanguage.Language = 'English'   AND countrylanguage.IsOfficial = 'F'
SELECT DISTINCT city.Name FROM city JOIN country ON city.CountryCode = country.Code JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Continent = 'Asia'   AND countrylanguage.Language = 'Chinese'   AND countrylanguage.IsOfficial = 'T'
SELECT DISTINCT city.Name FROM city JOIN country ON city.CountryCode = country.Code JOIN countrylanguage ON country.Code = countrylanguage.CountryCode WHERE country.Continent = 'Asia'   AND countrylanguage.Language = 'Chinese'   AND countrylanguage.IsOfficial = 'T'
SELECT Name, IndepYear, SurfaceArea FROM country ORDER BY Population ASC LIMIT 1
SELECT Name, IndepYear, SurfaceArea FROM country ORDER BY Population ASC LIMIT 1
SELECT Population, Name, HeadOfState FROM country ORDER BY SurfaceArea DESC LIMIT 1
SELECT Name, Population, HeadOfState FROM country ORDER BY SurfaceArea DESC LIMIT 1
SELECT c.Name, COUNT(cl.Language) AS NumberOfLanguages FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode GROUP BY c.Code, c.Name HAVING COUNT(cl.Language) >= 3
SELECT c.Name, COUNT(cl.Language) AS language_count FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode GROUP BY c.Code, c.Name HAVING COUNT(cl.Language) > 2
SELECT      city.District,     COUNT(*) AS number_of_cities FROM city WHERE city.Population > (SELECT AVG(CAST(Population AS REAL)) FROM city) GROUP BY city.District
SELECT      c.District,     COUNT(*) AS city_count FROM city c WHERE c.Population > (SELECT AVG(CAST(Population AS REAL)) FROM city) GROUP BY c.District
SELECT      GovernmentForm,     SUM(Population) AS total_population FROM country GROUP BY GovernmentForm HAVING AVG(LifeExpectancy) > 72
SELECT GovernmentForm, SUM(Population) AS TotalPopulation FROM country GROUP BY GovernmentForm HAVING AVG(LifeExpectancy) > 72
SELECT      Continent,     AVG(LifeExpectancy) AS avg_life_expectancy,     SUM(Population) AS total_population FROM country GROUP BY Continent HAVING AVG(LifeExpectancy) < 72
SELECT      Continent,     SUM(Population) AS total_population,     AVG(LifeExpectancy) AS average_life_expectancy FROM country GROUP BY Continent HAVING AVG(LifeExpectancy) < 72
SELECT Name, SurfaceArea FROM country ORDER BY SurfaceArea DESC LIMIT 5
SELECT Name, SurfaceArea FROM country ORDER BY SurfaceArea DESC LIMIT 5
SELECT Name  FROM country  ORDER BY Population DESC  LIMIT 3
SELECT Name  FROM country  ORDER BY Population DESC  LIMIT 3
SELECT country.Name  FROM country  ORDER BY country.Population ASC  LIMIT 3
SELECT Name  FROM country  ORDER BY Population ASC  LIMIT 3
SELECT COUNT(*)  FROM country  WHERE Continent = 'Asia' OR Region = 'Asia'
SELECT COUNT(*)  FROM country  WHERE Continent = 'Asia' OR Region = 'Asia'
SELECT Name  FROM country  WHERE Continent = 'Europe'    AND Population >= 80000
SELECT Name  FROM country  WHERE Continent = 'Europe'    AND Population = 80000
SELECT      SUM(Population) AS total_population,     AVG(SurfaceArea) AS average_area FROM country WHERE Continent = 'North America'   AND SurfaceArea > 3000
SELECT      SUM(Population) AS total_population,     AVG(SurfaceArea) AS average_surface_area FROM country WHERE (Continent = 'North America' OR Region = 'North America')   AND SurfaceArea > 3000
SELECT Name  FROM city  WHERE Population BETWEEN 160000 AND 900000
SELECT Name FROM city WHERE Population BETWEEN 160000 AND 900000
SELECT cl.Language FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code GROUP BY cl.Language ORDER BY COUNT(DISTINCT cl.CountryCode) DESC LIMIT 1
SELECT cl.Language FROM countrylanguage cl JOIN country c ON cl.CountryCode = c.Code GROUP BY cl.Language ORDER BY COUNT(DISTINCT cl.CountryCode) DESC LIMIT 1
SELECT      c.Name AS Country,     cl.Language,     cl.Percentage FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Percentage = (     SELECT MAX(cl2.Percentage)     FROM countrylanguage cl2     WHERE cl2.CountryCode = c.Code ) ORDER BY c.Name
SELECT      c.Code AS CountryCode,     cl.Language,     cl.Percentage FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Percentage = (     SELECT MAX(cl2.Percentage)     FROM countrylanguage cl2     WHERE cl2.CountryCode = c.Code ) ORDER BY c.Code
```sql SELECT COUNT(*)  FROM country  WHERE country.Code IN (     SELECT cl.CountryCode      FROM countrylanguage cl      WHERE cl.Language = 'Spanish'      AND cl.Percentage = (         SELECT MAX(cl2.Percentage)          FROM countrylanguage cl2          WHERE cl2.CountryCode = cl.CountryCode     ) )
SELECT COUNT(*)  FROM country  JOIN countrylanguage ON country.Code = countrylanguage.CountryCode  WHERE countrylanguage.Language = 'Spanish'  AND countrylanguage.Percentage > 50.0
SELECT c.Code FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'Spanish' ORDER BY cl.Percentage DESC LIMIT 1
SELECT c.Code FROM country c JOIN countrylanguage cl ON c.Code = cl.CountryCode WHERE cl.Language = 'Spanish'   AND cl.Percentage > 50.0
SELECT COUNT(*) AS conductor_count FROM conductor
SELECT COUNT(*) FROM conductor
SELECT Name FROM conductor ORDER BY Age ASC
SELECT Name FROM conductor ORDER BY Age
SELECT Name FROM conductor WHERE Nationality != 'USA'
SELECT Name  FROM conductor  WHERE Nationality != 'USA'
SELECT Record_Company FROM orchestra ORDER BY Year_of_Founded DESC
SELECT Record_Company FROM orchestra ORDER BY Year_of_Founded DESC
SELECT AVG(Attendance) AS average_attendance FROM show
SELECT AVG(Attendance) AS average_attendance FROM show
SELECT      MAX("Share") AS max_share,     MIN("Share") AS min_share FROM performance WHERE "Type" != 'Live final'
SELECT      MAX("Share") AS max_share,     MIN("Share") AS min_share FROM "performance" WHERE "Type" != 'Live final'
SELECT COUNT(DISTINCT Nationality) AS number_of_nationalities FROM conductor
SELECT COUNT(DISTINCT Nationality) AS number_of_nationalities FROM conductor
SELECT Name  FROM conductor  ORDER BY Year_of_Work DESC
SELECT c.Name FROM conductor c ORDER BY c.Year_of_Work DESC
SELECT Name  FROM conductor  ORDER BY Year_of_Work DESC  LIMIT 1
SELECT c.Name FROM conductor c ORDER BY c.Year_of_Work DESC LIMIT 1
SELECT conductor.Name, orchestra.Orchestra FROM conductor JOIN orchestra ON conductor.Conductor_ID = orchestra.Conductor_ID
SELECT conductor.Name, orchestra.Orchestra FROM conductor JOIN orchestra ON conductor.Conductor_ID = orchestra.Conductor_ID
SELECT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID GROUP BY c.Conductor_ID, c.Name HAVING COUNT(DISTINCT o.Orchestra_ID) > 1
SELECT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID JOIN performance p ON o.Orchestra_ID = p.Orchestra_ID GROUP BY c.Conductor_ID, c.Name HAVING COUNT(DISTINCT o.Orchestra_ID) > 1
SELECT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID GROUP BY c.Conductor_ID, c.Name ORDER BY COUNT(o.Orchestra_ID) DESC LIMIT 1
SELECT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID GROUP BY c.Conductor_ID, c.Name ORDER BY COUNT(o.Orchestra_ID) DESC LIMIT 1
SELECT DISTINCT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID WHERE o.Year_of_Founded > 2008
SELECT DISTINCT c.Name FROM conductor c JOIN orchestra o ON c.Conductor_ID = o.Conductor_ID WHERE o.Year_of_Founded > 2008
SELECT Record_Company, COUNT(*) AS number_of_orchestras FROM orchestra GROUP BY Record_Company
SELECT Record_Company, COUNT(*) AS orchestra_count FROM orchestra GROUP BY Record_Company
SELECT Major_Record_Format, COUNT(*) AS count FROM orchestra GROUP BY Major_Record_Format ORDER BY count ASC
SELECT Major_Record_Format, COUNT(*) AS frequency FROM orchestra GROUP BY Major_Record_Format ORDER BY frequency DESC
SELECT Record_Company FROM orchestra GROUP BY Record_Company ORDER BY COUNT(*) DESC LIMIT 1
SELECT Record_Company FROM orchestra GROUP BY Record_Company ORDER BY COUNT(*) DESC LIMIT 1
SELECT o.Orchestra FROM orchestra o LEFT JOIN performance p ON o.Orchestra_ID = p.Orchestra_ID WHERE p.Performance_ID IS NULL
SELECT o.Orchestra FROM orchestra o LEFT JOIN performance p ON o.Orchestra_ID = p.Orchestra_ID WHERE p.Performance_ID IS NULL
SELECT o1.Record_Company FROM orchestra o1 JOIN orchestra o2 ON o1.Record_Company = o2.Record_Company WHERE o1.Year_of_Founded < 2003 AND o2.Year_of_Founded > 2003 GROUP BY o1.Record_Company
SELECT DISTINCT r1.Record_Company FROM orchestra r1 JOIN orchestra r2 ON r1.Record_Company = r2.Record_Company WHERE r1.Year_of_Founded < 2003 AND r2.Year_of_Founded > 2003
SELECT COUNT(*) AS number_of_orchestras FROM orchestra WHERE Major_Record_Format IN ('CD', 'DVD')
SELECT COUNT(*)  FROM orchestra  WHERE Major_Record_Format IN ('CD', 'DVD')
SELECT DISTINCT o.Year_of_Founded FROM orchestra o JOIN performance p ON o.Orchestra_ID = p.Orchestra_ID GROUP BY o.Orchestra_ID HAVING COUNT(p.Performance_ID) > 1
SELECT o.Year_of_Founded FROM orchestra o JOIN performance p ON o.Orchestra_ID = p.Orchestra_ID GROUP BY o.Orchestra_ID, o.Year_of_Founded HAVING COUNT(p.Performance_ID) > 1
SELECT COUNT(*) FROM Highschooler
SELECT COUNT(*) FROM Highschooler
SELECT name, grade FROM Highschooler
SELECT name, grade FROM Highschooler
SELECT grade FROM Highschooler
SELECT name, grade FROM Highschooler
SELECT grade FROM Highschooler WHERE name = 'Kyle'
SELECT grade FROM Highschooler WHERE name = 'Kyle'
SELECT name FROM Highschooler WHERE grade = 10
SELECT name FROM Highschooler WHERE grade = 10
SELECT ID FROM Highschooler WHERE name = 'Kyle'
SELECT ID FROM Highschooler WHERE name = 'Kyle'
SELECT COUNT(*) AS count FROM Highschooler WHERE grade = 9 OR grade = 10
SELECT COUNT(*)  FROM Highschooler  WHERE grade = 9 OR grade = 10
SELECT grade, COUNT(*) AS number_of_highschoolers FROM Highschooler GROUP BY grade
SELECT grade, COUNT(*) AS num_highschoolers FROM Highschooler GROUP BY grade
SELECT grade FROM Highschooler GROUP BY grade ORDER BY COUNT(*) DESC LIMIT 1
SELECT grade FROM Highschooler GROUP BY grade ORDER BY COUNT(*) DESC LIMIT 1
SELECT grade FROM Highschooler GROUP BY grade HAVING COUNT(*) >= 4
SELECT grade FROM Highschooler GROUP BY grade HAVING COUNT(*) >= 4
SELECT      h.ID AS student_id,     COUNT(f.friend_id) AS number_of_friends FROM Highschooler h LEFT JOIN Friend f ON h.ID = f.student_id GROUP BY h.ID ORDER BY h.ID
SELECT Highschooler.ID, Highschooler.name, COUNT(Friend.friend_id) AS friend_count FROM Highschooler LEFT JOIN Friend ON Highschooler.ID = Friend.student_id GROUP BY Highschooler.ID, Highschooler.name
SELECT h.name, COUNT(f.friend_id) AS number_of_friends FROM Highschooler h LEFT JOIN Friend f ON h.ID = f.student_id GROUP BY h.ID, h.name ORDER BY h.name
SELECT h.name, COUNT(f.friend_id) AS friend_count FROM Highschooler h LEFT JOIN Friend f ON h.ID = f.student_id GROUP BY h.ID, h.name
SELECT h.name FROM Highschooler h JOIN Friend f ON h.ID = f.student_id GROUP BY h.ID, h.name ORDER BY COUNT(f.friend_id) DESC LIMIT 1
SELECT h.name FROM Highschooler h JOIN Friend f ON h.ID = f.student_id OR h.ID = f.friend_id GROUP BY h.ID, h.name ORDER BY COUNT(*) DESC LIMIT 1
SELECT h.name FROM Highschooler h WHERE h.ID IN (     SELECT f1.ID1     FROM Friend f1     GROUP BY f1.ID1     HAVING COUNT(f1.ID2) >= 3 )
SELECT h.name FROM Highschooler h WHERE h.ID IN (     SELECT friend1_id     FROM Friend     GROUP BY friend1_id     HAVING COUNT(friend2_id) >= 3 )
SELECT h2.name FROM Highschooler h1 JOIN Friend f ON h1.ID = f.student_id JOIN Highschooler h2 ON f.friend_id = h2.ID WHERE h1.name = 'Kyle'
SELECT h2.name FROM Highschooler h1 JOIN Friend f ON h1.ID = f.student_id JOIN Highschooler h2 ON f.friend_id = h2.ID WHERE h1.name = 'Kyle'
SELECT COUNT(*)  FROM Friend  JOIN Highschooler ON Friend.friend_id = Highschooler.ID  WHERE Friend.student_id IN (     SELECT ID FROM Highschooler WHERE name = 'Kyle' )
SELECT COUNT(*)  FROM Highschooler AS h1 JOIN Friend AS f ON h1.ID = f.ID1 JOIN Highschooler AS h2 ON f.ID2 = h2.ID WHERE h1.name = 'Kyle'
SELECT ID  FROM Highschooler  WHERE ID NOT IN (SELECT student_id FROM Friend)   AND ID NOT IN (SELECT friend_id FROM Friend)
SELECT ID FROM Highschooler WHERE ID NOT IN (     SELECT student_id FROM Friend     UNION     SELECT friend_id FROM Friend )
SELECT h.name FROM Highschooler h WHERE h.ID NOT IN (     SELECT DISTINCT f.student_id     FROM Friend f     UNION     SELECT DISTINCT f.friend_id     FROM Friend f )
SELECT name FROM Highschooler WHERE ID NOT IN (     SELECT DISTINCT student_id     FROM Friend )
SELECT DISTINCT h.ID FROM Highschooler h WHERE h.ID IN (SELECT ID FROM Friend)   AND h.ID IN (SELECT ID FROM Likes)
SELECT ID FROM Highschooler WHERE ID IN (SELECT ID FROM Highschooler WHERE ID IN (SELECT ID FROM Friend))   AND ID IN (SELECT ID FROM Highschooler WHERE ID IN (SELECT ID FROM Likes))
SELECT DISTINCT h.name FROM Highschooler h WHERE h.ID IN (     -- students who have some friends     SELECT f1.ID1 FROM Friend f1     UNION     SELECT f2.ID2 FROM Friend f2 ) AND h.ID IN (     -- students who are liked by someone else     SELECT l.ID2 FROM Likes l )
SELECT DISTINCT h.name FROM Highschooler h JOIN Friend f ON h.ID = f.student_id JOIN Likes l ON h.ID = l.liked_id
SELECT      student_id,      COUNT(*) AS like_count FROM Likes GROUP BY student_id
SELECT student_id, COUNT(*) AS likes_count FROM Likes GROUP BY student_id
SELECT h.name, COUNT(l.student_id) AS likes_count FROM Highschooler h JOIN Likes l ON h.ID = l.student_id GROUP BY h.ID, h.name
SELECT h.name, COUNT(l.student_id) AS likes_count FROM Highschooler h JOIN Likes l ON h.ID = l.student_id GROUP BY h.ID, h.name
SELECT h.name FROM Highschooler h JOIN Likes l ON h.ID = l.student_id GROUP BY h.ID, h.name ORDER BY COUNT(*) DESC LIMIT 1
SELECT h.name FROM Highschooler h JOIN Likes l ON h.ID = l.liked_id GROUP BY h.ID, h.name ORDER BY COUNT(*) DESC LIMIT 1
SELECT h.name FROM Highschooler h JOIN Likes l ON h.ID = l.liked_id GROUP BY h.ID, h.name HAVING COUNT(l.student_id) >= 2
SELECT name FROM Highschooler WHERE ID IN (     SELECT liked_id     FROM Likes     GROUP BY liked_id     HAVING COUNT(*) >= 2 )
SELECT h.name FROM Highschooler h WHERE h.grade > 5   AND h.ID IN (     SELECT f.student_id     FROM Friend f     GROUP BY f.student_id     HAVING COUNT(f.friend_id) >= 2   )
SELECT DISTINCT h.name FROM Highschooler h JOIN Friend f ON h.ID = f.student_id WHERE h.grade > 5 GROUP BY h.ID, h.name HAVING COUNT(f.friend_id) >= 2
SELECT COUNT(*)  FROM Likes  JOIN Highschooler ON Likes.student_id = Highschooler.ID  WHERE Highschooler.name = 'Kyle'
SELECT COUNT(*)  FROM Likes  JOIN Highschooler ON Likes.student_id = Highschooler.ID  WHERE Highschooler.name = 'Kyle'
SELECT AVG(CAST(Highschooler.grade AS REAL)) FROM Highschooler WHERE Highschooler.ID IN (     SELECT DISTINCT Friend.ID1 FROM Friend     UNION     SELECT DISTINCT Friend.ID2 FROM Friend )
SELECT AVG(CAST(Highschooler.grade AS REAL)) FROM Highschooler WHERE Highschooler.ID IN (     SELECT DISTINCT Friend.ID1 FROM Friend     UNION     SELECT DISTINCT Friend.ID2 FROM Friend )
SELECT MIN(Highschooler.grade) FROM Highschooler WHERE Highschooler.ID NOT IN (     SELECT Friend.student_id FROM Friend     UNION     SELECT Friend.friend_id FROM Friend )
SELECT MIN(grade)  FROM Highschooler  WHERE ID NOT IN (     SELECT ID1 FROM Friend     UNION     SELECT ID2 FROM Friend )
-- We need to find states that have both owners and professionals. -- Since the schema only includes the Owners table and no Professionals table, -- we can only query from Owners. However, the question implies a Professionals table exists, -- but it is not in the grounded schema. Based on the given schema, we can only return states -- from Owners. To satisfy the question, we assume a Professionals table with a similar structure -- (e.g., state column) exists but is not provided. Without it, we cannot answer correctly. -- Given the constraints, we will return states from Owners where there are owners, -- but this does not fulfill "both owners and professionals".  -- Since no Professionals table is available, the query will be incomplete. -- However, following instructions strictly, we use only the grounded schema. -- The best we can do is return distinct states from Owners. SELECT DISTINCT state FROM Owners WHERE state IS NOT NULL
SELECT DISTINCT o.state FROM Owners o WHERE EXISTS (     SELECT 1     FROM Professionals p     WHERE p.state = o.state )
SELECT AVG(CAST(Dogs.age AS REAL)) FROM Dogs INNER JOIN Treatments ON Dogs.dog_id = Treatments.dog_id
SELECT AVG(CAST(Dogs.age AS REAL)) AS average_age FROM Dogs INNER JOIN Treatments ON Dogs.dog_id = Treatments.dog_id
SELECT      p.professional_id,     p.last_name,     p.cell_number FROM Professionals p LEFT JOIN Treatments t ON p.professional_id = t.professional_id GROUP BY p.professional_id, p.last_name, p.cell_number, p.state HAVING p.state = 'Indiana' OR COUNT(t.treatment_id) > 2
SELECT p.professional_id, p.last_name, p.cell_number FROM Professionals p LEFT JOIN Treatments t ON p.professional_id = t.professional_id GROUP BY p.professional_id, p.last_name, p.cell_number, p.state HAVING p.state = 'Indiana' OR COUNT(t.treatment_id) > 2
SELECT d.name FROM Dogs d JOIN Treatments t ON d.dog_id = t.dog_id JOIN Treatment_Types tt ON t.treatment_type_code = tt.treatment_type_code JOIN Owners o ON d.owner_id = o.owner_id GROUP BY d.dog_id, d.name HAVING SUM(t.cost_of_treatment) <= 1000
SELECT d.name FROM Dogs d JOIN Owners o ON d.owner_id = o.owner_id JOIN Treatments t ON d.dog_id = t.dog_id GROUP BY d.dog_id, d.name, o.owner_id HAVING COALESCE(SUM(t.cost_of_treatment), 0) <= 1000
SELECT DISTINCT p.first_name FROM Professionals p WHERE p.first_name NOT IN (     SELECT DISTINCT d.name     FROM Dogs d     WHERE d.name IS NOT NULL ) UNION SELECT DISTINCT o.first_name FROM Owners o WHERE o.first_name NOT IN (     SELECT DISTINCT d.name     FROM Dogs d     WHERE d.name IS NOT NULL )
SELECT DISTINCT p.first_name FROM Professionals p WHERE p.first_name NOT IN (SELECT name FROM Dogs WHERE name IS NOT NULL) UNION SELECT DISTINCT o.first_name FROM Owners o WHERE o.first_name NOT IN (SELECT name FROM Dogs WHERE name IS NOT NULL)
SELECT p.professional_id, p.role_code, p.email_address FROM Professionals p LEFT JOIN Treatments t ON p.professional_id = t.professional_id WHERE t.treatment_id IS NULL
SELECT p.professional_id, p.role_code, p.email_address FROM Professionals p LEFT JOIN Treatments t ON p.professional_id = t.professional_id WHERE t.treatment_id IS NULL
SELECT o.owner_id, o.first_name, o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id GROUP BY o.owner_id, o.first_name, o.last_name ORDER BY COUNT(d.dog_id) DESC LIMIT 1
SELECT o.owner_id, o.first_name, o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id GROUP BY o.owner_id, o.first_name, o.last_name ORDER BY COUNT(d.dog_id) DESC LIMIT 1
SELECT      p.professional_id,     p.role_code,     p.first_name FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id GROUP BY p.professional_id, p.role_code, p.first_name HAVING COUNT(t.treatment_id) >= 2
SELECT p.professional_id AS id, p.role_code AS role, p.first_name FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id GROUP BY p.professional_id, p.role_code, p.first_name HAVING COUNT(t.treatment_id) >= 2
SELECT b.breed_name FROM Breeds b JOIN Dogs d ON b.breed_code = d.breed_code GROUP BY b.breed_code, b.breed_name ORDER BY COUNT(d.dog_id) DESC LIMIT 1
SELECT b.breed_name FROM Dogs d JOIN Breeds b ON d.breed_code = b.breed_code GROUP BY b.breed_code, b.breed_name ORDER BY COUNT(d.dog_id) DESC LIMIT 1
SELECT o.owner_id, o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Treatments t ON d.dog_id = t.dog_id JOIN Charges c ON t.treatment_id = c.charge_id GROUP BY o.owner_id, o.last_name ORDER BY COUNT(t.treatment_id) DESC LIMIT 1
SELECT o.owner_id, o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Treatments t ON d.dog_id = t.dog_id GROUP BY o.owner_id, o.last_name ORDER BY SUM(t.cost_of_treatment) DESC LIMIT 1
SELECT tt.treatment_type_description FROM Treatments t JOIN Treatment_Types tt ON t.treatment_type_code = tt.treatment_type_code GROUP BY tt.treatment_type_code, tt.treatment_type_description ORDER BY SUM(t.cost_of_treatment) ASC LIMIT 1
SELECT tt.treatment_type_description FROM Treatment_Types tt JOIN Treatments t ON tt.treatment_type_code = t.treatment_type_code GROUP BY tt.treatment_type_code, tt.treatment_type_description ORDER BY SUM(t.cost_of_treatment) ASC LIMIT 1
SELECT      o.owner_id,     o.zip_code FROM Owners o JOIN Charges c ON o.owner_id = c.charge_id GROUP BY o.owner_id, o.zip_code ORDER BY SUM(c.charge_amount) DESC LIMIT 1
SELECT o.owner_id, o.zip_code FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Treatments t ON d.dog_id = t.dog_id GROUP BY o.owner_id, o.zip_code ORDER BY SUM(t.cost_of_treatment) DESC LIMIT 1
SELECT      p.professional_id,     p.cell_number FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id JOIN Treatment_Types tt ON t.treatment_type_code = tt.treatment_type_code GROUP BY p.professional_id, p.cell_number HAVING COUNT(DISTINCT t.treatment_type_code) >= 2
SELECT p.professional_id, p.cell_number FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id GROUP BY p.professional_id, p.cell_number HAVING COUNT(DISTINCT t.treatment_type_code) >= 2
SELECT DISTINCT p.first_name, p.last_name FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id WHERE t.cost_of_treatment < (SELECT AVG(cost_of_treatment) FROM Treatments)
SELECT DISTINCT p.first_name, p.last_name FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id WHERE t.cost_of_treatment < (SELECT AVG(cost_of_treatment) FROM Treatments)
SELECT      t.date_of_treatment,     p.first_name FROM Treatments t JOIN Professionals p ON t.professional_id = p.professional_id
SELECT      t.date_of_treatment,     p.first_name FROM Treatments t JOIN Professionals p ON t.professional_id = p.professional_id
SELECT      t.cost_of_treatment,     tt.treatment_type_description FROM Treatments t JOIN Treatment_Types tt ON t.treatment_type_code = tt.treatment_type_code
SELECT      t.cost_of_treatment,     tt.treatment_type_description FROM Treatments t JOIN Treatment_Types tt ON t.treatment_type_code = tt.treatment_type_code
SELECT      o.first_name,     o.last_name,     s.size_description FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Sizes s ON d.size_code = s.size_code
SELECT      o.first_name,     o.last_name,     s.size_description FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id JOIN Sizes s ON d.size_code = s.size_code
SELECT Owners.first_name, Dogs.name FROM Dogs JOIN Owners ON Dogs.owner_id = Owners.owner_id
SELECT o.first_name, d.name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id
SELECT      d.name,     t.date_of_treatment FROM Dogs d JOIN Breeds b ON d.breed_code = b.breed_code JOIN Treatments t ON d.dog_id = t.dog_id WHERE b.breed_code = (     SELECT breed_code     FROM Dogs     GROUP BY breed_code     ORDER BY COUNT(*) ASC     LIMIT 1 )
SELECT d.name, t.date_of_treatment FROM Dogs d JOIN Breeds b ON d.breed_code = b.breed_code JOIN Treatments t ON d.dog_id = t.dog_id WHERE b.breed_code = (     SELECT breed_code     FROM Dogs     GROUP BY breed_code     ORDER BY COUNT(*) ASC     LIMIT 1 )
SELECT      o.first_name,     d.name FROM Dogs d JOIN Owners o ON d.owner_id = o.owner_id WHERE o.state = 'Virginia'
SELECT o.first_name, d.name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id WHERE o.state = 'Virginia'
SELECT DISTINCT d.date_arrived, d.date_departed FROM Dogs d JOIN Treatments t ON d.dog_id = t.dog_id
SELECT DISTINCT d.date_arrived, d.date_departed FROM Dogs d JOIN Treatments t ON d.dog_id = t.dog_id
SELECT o.last_name FROM Owners o JOIN Dogs d ON o.owner_id = d.owner_id ORDER BY d.date_of_birth DESC LIMIT 1
SELECT o.last_name FROM Dogs d JOIN Owners o ON d.owner_id = o.owner_id ORDER BY d.date_of_birth DESC LIMIT 1
SELECT email_address FROM Professionals WHERE state = 'Hawaii' OR state = 'Wisconsin'
SELECT email_address FROM Professionals WHERE state IN ('Hawaii', 'Wisconsin')
SELECT date_arrived, date_departed FROM Dogs
SELECT date_arrived, date_departed FROM Dogs
SELECT COUNT(DISTINCT Dogs.dog_id) AS dog_count FROM Dogs INNER JOIN Treatments ON Dogs.dog_id = Treatments.dog_id
SELECT COUNT(DISTINCT Dogs.dog_id)  FROM Dogs  INNER JOIN Treatments ON Dogs.dog_id = Treatments.dog_id
SELECT COUNT(DISTINCT p.professional_id)  FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id
SELECT COUNT(DISTINCT p.professional_id)  FROM Professionals p  JOIN Treatments t ON p.professional_id = t.professional_id
SELECT role_code, street, city, state FROM Professionals WHERE city LIKE '%West%'
SELECT role_code, street, city, state FROM Professionals WHERE city LIKE '%West%'
SELECT first_name, last_name, email_address FROM Owners WHERE state LIKE '%North%'
SELECT first_name, last_name, email_address FROM Owners WHERE state LIKE '%North%'
SELECT COUNT(*)  FROM Dogs  WHERE CAST(age AS REAL) < (SELECT AVG(CAST(age AS REAL)) FROM Dogs)
SELECT COUNT(*)  FROM Dogs  WHERE CAST(age AS REAL) < (SELECT AVG(CAST(age AS REAL)) FROM Dogs)
SELECT cost_of_treatment FROM Treatments ORDER BY date_of_treatment DESC LIMIT 1
SELECT cost_of_treatment FROM Treatments ORDER BY date_of_treatment DESC LIMIT 1
SELECT COUNT(*) AS dog_count FROM Dogs d LEFT JOIN Treatments t ON d.dog_id = t.dog_id WHERE t.treatment_id IS NULL
SELECT COUNT(*) AS number_of_dogs_without_treatment FROM Dogs d LEFT JOIN Treatments t ON d.dog_id = t.dog_id WHERE t.treatment_id IS NULL
SELECT COUNT(*) AS owners_without_dogs FROM Owners o LEFT JOIN Dogs d ON o.owner_id = d.owner_id WHERE d.owner_id IS NULL
SELECT COUNT(*) AS number_of_owners_without_dogs FROM Owners o LEFT JOIN Dogs d ON o.owner_id = d.owner_id WHERE d.owner_id IS NULL
SELECT COUNT(*) AS professional_count FROM Professionals p WHERE p.professional_id NOT IN (     SELECT DISTINCT t.professional_id     FROM Treatments t )
SELECT COUNT(*) AS number_of_professionals FROM Professionals p LEFT JOIN Treatments t ON p.professional_id = t.professional_id WHERE t.treatment_id IS NULL
SELECT      d.name,     d.age,     d.weight FROM Dogs d WHERE d.abandoned_yn = '1'
SELECT name, age, weight FROM Dogs WHERE abandoned_yn = '1'
SELECT AVG(CAST(age AS REAL)) AS average_age FROM Dogs
SELECT AVG(CAST(age AS REAL)) AS average_age FROM Dogs
SELECT MAX(age) AS oldest_dog_age FROM Dogs
SELECT age FROM Dogs ORDER BY age DESC LIMIT 1
```sql SELECT charge_type, charge_amount FROM Charges
SELECT charge_type, charge_amount FROM Charges
SELECT charge_type, MAX(charge_amount) AS most_expensive_cost FROM Charges GROUP BY charge_type ORDER BY most_expensive_cost DESC LIMIT 1
SELECT charge_amount FROM Charges ORDER BY charge_amount DESC LIMIT 1
SELECT email_address, cell_number, home_phone FROM Professionals
SELECT email_address, cell_number, home_phone FROM Professionals
SELECT Breeds.breed_name, Sizes.size_description FROM Breeds CROSS JOIN Sizes ORDER BY Breeds.breed_name, Sizes.size_description
SELECT DISTINCT b.breed_name, s.size_description FROM Breeds b, Sizes s WHERE b.breed_code IS NOT NULL   AND s.size_code IS NOT NULL
SELECT      p.first_name,     tt.treatment_type_description FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id JOIN Treatment_Types tt ON t.treatment_type_code = tt.treatment_type_code
SELECT      p.first_name,     tt.treatment_type_description FROM Professionals p JOIN Treatments t ON p.professional_id = t.professional_id JOIN Treatment_Types tt ON t.treatment_type_code = tt.treatment_type_code
SELECT COUNT(*) FROM singer
SELECT COUNT(*) AS singer_count FROM singer
SELECT Name FROM singer ORDER BY Net_Worth_Millions ASC
SELECT Name FROM singer ORDER BY Net_Worth_Millions ASC
SELECT Birth_Year, Citizenship FROM singer
SELECT Birth_Year, Citizenship FROM singer
SELECT Name FROM singer WHERE Citizenship != 'France'
SELECT Name  FROM singer  WHERE Citizenship != 'French' OR Citizenship IS NULL
SELECT Name FROM singer WHERE Birth_Year IN (1948, 1949)
SELECT Name FROM singer WHERE Birth_Year IN (1948, 1949)
SELECT Name  FROM singer  ORDER BY Net_Worth_Millions DESC  LIMIT 1
SELECT Name  FROM singer  ORDER BY Net_Worth_Millions DESC  LIMIT 1
SELECT Citizenship, COUNT(*) AS number_of_singers FROM singer GROUP BY Citizenship ORDER BY Citizenship
SELECT Citizenship, COUNT(*) AS singer_count FROM singer GROUP BY Citizenship
SELECT Citizenship, COUNT(*) AS cnt FROM singer GROUP BY Citizenship ORDER BY cnt DESC LIMIT 1
SELECT Citizenship, COUNT(*) AS cnt FROM singer GROUP BY Citizenship ORDER BY cnt DESC LIMIT 1
SELECT Citizenship, MAX(Net_Worth_Millions) AS max_net_worth FROM singer GROUP BY Citizenship
SELECT Citizenship, MAX(Net_Worth_Millions) AS max_net_worth FROM singer GROUP BY Citizenship
SELECT s.Title, si.Name FROM song s JOIN singer si ON s.Singer_ID = si.Singer_ID
SELECT s.Title, si.Name FROM song s JOIN singer si ON s.Singer_ID = si.Singer_ID
SELECT DISTINCT s.Name FROM singer s JOIN song so ON s.Singer_ID = so.Singer_ID WHERE so.Sales > 300000
SELECT DISTINCT s.Name FROM singer s JOIN song so ON s.Singer_ID = so.Singer_ID WHERE so.Sales > 300000
SELECT s.Name FROM singer s JOIN song so ON s.Singer_ID = so.Singer_ID GROUP BY s.Singer_ID, s.Name HAVING COUNT(so.Song_ID) > 1
SELECT s.Name FROM singer s JOIN song so ON s.Singer_ID = so.Singer_ID GROUP BY s.Singer_ID, s.Name HAVING COUNT(so.Song_ID) > 1
SELECT s.Name, SUM(song.Sales) AS total_sales FROM singer s JOIN song ON s.Singer_ID = song.Singer_ID GROUP BY s.Singer_ID, s.Name
SELECT s.Name, SUM(so.Sales) AS total_sales FROM singer s JOIN song so ON s.Singer_ID = so.Singer_ID GROUP BY s.Singer_ID, s.Name
SELECT singer.Name  FROM singer  LEFT JOIN song ON singer.Singer_ID = song.Singer_ID  WHERE song.Song_ID IS NULL
SELECT s.Name  FROM singer s  LEFT JOIN song sg ON s.Singer_ID = sg.Singer_ID  WHERE sg.Song_ID IS NULL
SELECT s.Citizenship FROM singer s WHERE s.Birth_Year < 1945 INTERSECT SELECT s.Citizenship FROM singer s WHERE s.Birth_Year > 1955
SELECT s.Citizenship FROM singer s WHERE s.Birth_Year < 1945 INTERSECT SELECT s.Citizenship FROM singer s WHERE s.Birth_Year > 1955
SELECT COUNT(*) AS total_available_features FROM Other_Available_Features
SELECT rft.feature_type_name FROM Other_Available_Features oaf JOIN Ref_Feature_Types rft ON oaf.feature_type_code = rft.feature_type_code WHERE oaf.feature_name = 'AirCon'
SELECT DISTINCT rpt.property_type_description FROM Properties p JOIN Ref_Property_Types rpt ON p.property_type_code = rpt.property_type_code
SELECT p.property_name FROM Properties p JOIN Ref_Property_Types rpt ON p.property_type_code = rpt.property_type_code WHERE (rpt.property_type_description LIKE '%house%' OR rpt.property_type_description LIKE '%apartment%')   AND p.room_count > 1
