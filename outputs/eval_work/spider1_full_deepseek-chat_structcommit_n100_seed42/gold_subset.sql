SELECT count(*) FROM singer	concert_singer
SELECT song_name ,  song_release_year FROM singer ORDER BY age LIMIT 1	concert_singer
SELECT LOCATION ,  name FROM stadium WHERE capacity BETWEEN 5000 AND 10000	concert_singer
select avg(capacity) ,  max(capacity) from stadium	concert_singer
SELECT name ,  country FROM singer WHERE song_name LIKE '%Hey%'	concert_singer
SELECT weight FROM pets ORDER BY pet_age LIMIT 1	pets_1
SELECT count(*) FROM student AS T1 JOIN has_pet AS T2 ON T1.stuid  =  T2.stuid WHERE T1.age  >  20	pets_1
SELECT petid ,  weight FROM pets WHERE pet_age  >  1	pets_1
SELECT avg(weight) ,  pettype FROM pets GROUP BY pettype	pets_1
SELECT count(*) ,  T1.stuid FROM student AS T1 JOIN has_pet AS T2 ON T1.stuid  =  T2.stuid GROUP BY T1.stuid	pets_1
SELECT count(*) FROM COUNTRIES;	car_1
SELECT T1.FullName ,  T1.Id ,  count(*) FROM CAR_MAKERS AS T1 JOIN MODEL_LIST AS T2 ON T1.Id  =  T2.Maker GROUP BY T1.Id;	car_1
SELECT count(*) FROM MODEL_LIST AS T1 JOIN CAR_MAKERS AS T2 ON T1.Maker  =  T2.Id JOIN COUNTRIES AS T3 ON T2.Country  =  T3.CountryId WHERE T3.CountryName  =  'usa';	car_1
SELECT avg(Weight) ,  YEAR FROM CARS_DATA GROUP BY YEAR;	car_1
SELECT CountryName FROM countries EXCEPT SELECT T1.CountryName FROM countries AS T1 JOIN CAR_MAKERS AS T2 ON T1.countryId  =  T2.Country;	car_1
SELECT count(*) FROM AIRLINES	flight_2
SELECT count(*) FROM AIRLINES WHERE Country  =  "USA"	flight_2
SELECT T1.Airline FROM AIRLINES AS T1 JOIN FLIGHTS AS T2 ON T1.uid  =  T2.Airline WHERE T2.SourceAirport  =  "CVO" EXCEPT SELECT T1.Airline FROM AIRLINES AS T1 JOIN FLIGHTS AS T2 ON T1.uid  =  T2.Airline WHERE T2.SourceAirport  =  "APG"	flight_2
SELECT FlightNo FROM FLIGHTS WHERE SourceAirport  =  "APG"	flight_2
SELECT count(*) FROM Flights AS T1 JOIN Airports AS T2 ON T1.DestAirport  =  T2.AirportCode WHERE T2.city  =  "Aberdeen" OR T2.city  =  "Abilene"	flight_2
SELECT count(*) FROM employee	employee_hire_evaluation
SELECT name FROM employee ORDER BY age	employee_hire_evaluation
SELECT count(*) ,  city FROM employee GROUP BY city	employee_hire_evaluation
SELECT name ,  LOCATION ,  district FROM shop ORDER BY number_products DESC	employee_hire_evaluation
SELECT district FROM shop WHERE Number_products  <  3000 INTERSECT SELECT district FROM shop WHERE Number_products  >  10000	employee_hire_evaluation
SELECT document_id ,  template_id ,  Document_Description FROM Documents WHERE document_name  =  "Robbin CV"	cre_Doc_Template_Mgt
SELECT count(DISTINCT template_id) FROM Documents	cre_Doc_Template_Mgt
SELECT count(*) FROM Documents AS T1 JOIN Templates AS T2 ON T1.Template_ID  =  T2.Template_ID WHERE T2.Template_Type_Code  =  'PPT'	cre_Doc_Template_Mgt
SELECT template_id ,  version_number ,  template_type_code FROM Templates	cre_Doc_Template_Mgt
select other_details from paragraphs where paragraph_text like 'korea'	cre_Doc_Template_Mgt
SELECT count(*) FROM teacher	course_teach
SELECT Hometown ,  COUNT(*) FROM teacher GROUP BY Hometown	course_teach
SELECT Hometown FROM teacher GROUP BY Hometown HAVING COUNT(*)  >=  2	course_teach
SELECT T3.Name FROM course_arrange AS T1 JOIN course AS T2 ON T1.Course_ID  =  T2.Course_ID JOIN teacher AS T3 ON T1.Teacher_ID  =  T3.Teacher_ID WHERE T2.Course  =  "Math"	course_teach
SELECT Name FROM teacher WHERE Teacher_id NOT IN (SELECT Teacher_id FROM course_arrange)	course_teach
SELECT avg(num_of_staff) FROM museum WHERE open_year  <  2009	museum_visit
SELECT Num_of_Staff ,  Open_Year FROM museum WHERE name  =  'Plaza Museum'	museum_visit
SELECT name FROM museum WHERE num_of_staff  >  (SELECT min(num_of_staff) FROM museum WHERE open_year  >  2010)	museum_visit
SELECT sum(t2.Total_spent) FROM visitor AS t1 JOIN visit AS t2 ON t1.id  =  t2.visitor_id WHERE t1.Level_of_membership  =  1	museum_visit
SELECT count(*) FROM visitor WHERE id NOT IN (SELECT t2.visitor_id FROM museum AS t1 JOIN visit AS t2 ON t1.Museum_ID  =  t2.Museum_ID WHERE t1.open_year  >  2010)	museum_visit
SELECT count(DISTINCT country_code) FROM players	wta_1
SELECT count(DISTINCT loser_name) FROM matches	wta_1
SELECT first_name ,  last_name FROM players WHERE hand  =  'L' ORDER BY birth_date	wta_1
SELECT count(*) ,  YEAR FROM matches GROUP BY YEAR	wta_1
SELECT T1.first_name ,  T1.country_code ,  T1.birth_date FROM players AS T1 JOIN matches AS T2 ON T1.player_id  =  T2.winner_id ORDER BY T2.winner_rank_points DESC LIMIT 1	wta_1
SELECT avg(injured) FROM death	battle_death
SELECT T1.killed ,  T1.injured FROM death AS T1 JOIN ship AS t2 ON T1.caused_by_ship_id  =  T2.id WHERE T2.tonnage  =  't'	battle_death
SELECT name ,  RESULT FROM battle WHERE bulgarian_commander != 'Boril'	battle_death
SELECT T1.id ,  T1.name FROM battle AS T1 JOIN ship AS T2 ON T1.id  =  T2.lost_in_battle JOIN death AS T3 ON T2.id  =  T3.caused_by_ship_id GROUP BY T1.id HAVING sum(T3.killed)  >  10	battle_death
SELECT T2.id ,  T2.name FROM death AS T1 JOIN ship AS t2 ON T1.caused_by_ship_id  =  T2.id GROUP BY T2.id ORDER BY count(*) DESC LIMIT 1	battle_death
SELECT name FROM battle WHERE bulgarian_commander  =  'Kaloyan' AND latin_commander  =  'Baldwin I'	battle_death
SELECT line_1 ,  line_2 FROM addresses	student_transcripts_tracking
SELECT semester_name FROM Semesters WHERE semester_id NOT IN( SELECT semester_id FROM Student_Enrolment )	student_transcripts_tracking
SELECT DISTINCT T1.course_name FROM Courses AS T1 JOIN Student_Enrolment_Courses AS T2 ON T1.course_id  =  T2.course_id	student_transcripts_tracking
SELECT first_name ,  middle_name ,  last_name FROM Students ORDER BY date_left ASC LIMIT 1	student_transcripts_tracking
SELECT count(DISTINCT current_address_id) FROM Students	student_transcripts_tracking
SELECT Country ,  count(*) FROM TV_Channel GROUP BY Country ORDER BY count(*) DESC LIMIT 1;	tvshow
SELECT Episode ,  Rating FROM TV_series ORDER BY Rating DESC LIMIT 3;	tvshow
SELECT package_option ,  series_name FROM TV_Channel WHERE hight_definition_TV  =  "yes"	tvshow
SELECT Pixel_aspect_ratio_PAR ,  country FROM tv_channel WHERE LANGUAGE != 'English'	tvshow
SELECT id FROM tv_channel GROUP BY country HAVING count(*)  >  2	tvshow
SELECT count(*) FROM poker_player	poker_player
SELECT T1.Name FROM people AS T1 JOIN poker_player AS T2 ON T1.People_ID  =  T2.People_ID ORDER BY T2.Final_Table_Made	poker_player
SELECT T1.Name FROM people AS T1 JOIN poker_player AS T2 ON T1.People_ID  =  T2.People_ID ORDER BY T2.Earnings DESC	poker_player
SELECT Nationality ,  COUNT(*) FROM people GROUP BY Nationality	poker_player
SELECT Nationality FROM people GROUP BY Nationality HAVING COUNT(*)  >=  2	poker_player
SELECT count(*) FROM area_code_state	voter_1
SELECT max(area_code) ,  min(area_code) FROM area_code_state	voter_1
SELECT contestant_name FROM contestants WHERE contestant_name != 'Jessie Alloway'	voter_1
SELECT T1.contestant_number , T1.contestant_name FROM contestants AS T1 JOIN votes AS T2 ON T1.contestant_number  =  T2.contestant_number GROUP BY T1.contestant_number ORDER BY count(*) ASC LIMIT 1	voter_1
SELECT T1.area_code FROM area_code_state AS T1 JOIN votes AS T2 ON T1.state  =  T2.state GROUP BY T1.area_code ORDER BY count(*) DESC LIMIT 1	voter_1
SELECT Population ,  Region FROM country WHERE Name  =  "Angola"	world_1
SELECT sum(Population) FROM city WHERE District  =  "Gelderland"	world_1
SELECT Name ,  Population ,  LifeExpectancy FROM country WHERE Continent  =  "Asia" ORDER BY SurfaceArea DESC LIMIT 1	world_1
SELECT Name FROM country WHERE Continent  =  "Africa"  AND population  <  (SELECT max(population) FROM country WHERE Continent  =  "Asia")	world_1
SELECT DISTINCT T3.Name FROM country AS T1 JOIN countrylanguage AS T2 ON T1.Code  =  T2.CountryCode JOIN city AS T3 ON T1.Code  =  T3.CountryCode WHERE T2.IsOfficial  =  'T' AND T2.Language  =  'Chinese' AND T1.Continent  =  "Asia"	world_1
SELECT T1.Name FROM conductor AS T1 JOIN orchestra AS T2 ON T1.Conductor_ID  =  T2.Conductor_ID GROUP BY T2.Conductor_ID ORDER BY COUNT(*) DESC LIMIT 1	orchestra
SELECT Record_Company ,  COUNT(*) FROM orchestra GROUP BY Record_Company	orchestra
SELECT Record_Company FROM orchestra GROUP BY Record_Company ORDER BY COUNT(*) DESC LIMIT 1	orchestra
SELECT Orchestra FROM orchestra WHERE Orchestra_ID NOT IN (SELECT Orchestra_ID FROM performance)	orchestra
SELECT Record_Company FROM orchestra WHERE Year_of_Founded  <  2003 INTERSECT SELECT Record_Company FROM orchestra WHERE Year_of_Founded  >  2003	orchestra
SELECT name ,  grade FROM Highschooler	network_1
SELECT name FROM Highschooler WHERE grade  =  10	network_1
SELECT grade FROM Highschooler GROUP BY grade HAVING count(*)  >=  4	network_1
SELECT name FROM Highschooler EXCEPT SELECT T2.name FROM Friend AS T1 JOIN Highschooler AS T2 ON T1.student_id  =  T2.id	network_1
SELECT T2.name FROM Likes AS T1 JOIN Highschooler AS T2 ON T1.student_id  =  T2.id GROUP BY T1.student_id ORDER BY count(*) DESC LIMIT 1	network_1
SELECT first_name FROM Professionals UNION SELECT first_name FROM Owners EXCEPT SELECT name FROM Dogs	dog_kennels
SELECT T1.treatment_type_description FROM Treatment_types AS T1 JOIN Treatments AS T2 ON T1.treatment_type_code  =  T2.treatment_type_code GROUP BY T1.treatment_type_code ORDER BY sum(cost_of_treatment) ASC LIMIT 1	dog_kennels
SELECT T1.owner_id ,  T1.zip_code FROM Owners AS T1 JOIN Dogs AS T2 ON T1.owner_id  =  T2.owner_id JOIN Treatments AS T3 ON T2.dog_id  =  T3.dog_id GROUP BY T1.owner_id ORDER BY sum(T3.cost_of_treatment) DESC LIMIT 1	dog_kennels
SELECT T1.cost_of_treatment ,  T2.treatment_type_description FROM Treatments AS T1 JOIN treatment_types AS T2 ON T1.treatment_type_code  =  T2.treatment_type_code	dog_kennels
SELECT max(age) FROM Dogs	dog_kennels
SELECT Name FROM singer ORDER BY Net_Worth_Millions ASC	singer
SELECT Name FROM singer ORDER BY Net_Worth_Millions DESC LIMIT 1	singer
SELECT Citizenship ,  COUNT(*) FROM singer GROUP BY Citizenship	singer
SELECT DISTINCT T1.Name FROM singer AS T1 JOIN song AS T2 ON T1.Singer_ID  =  T2.Singer_ID WHERE T2.Sales  >  300000	singer
SELECT Citizenship FROM singer WHERE Birth_Year  <  1945 INTERSECT SELECT Citizenship FROM singer WHERE Birth_Year  >  1955	singer
SELECT count(*) FROM Other_Available_Features	real_estate_properties
SELECT T2.feature_type_name FROM Other_Available_Features AS T1 JOIN Ref_Feature_Types AS T2 ON T1.feature_type_code  =  T2.feature_type_code WHERE T1.feature_name  =  "AirCon"	real_estate_properties
SELECT T2.property_type_description FROM Properties AS T1 JOIN Ref_Property_Types AS T2 ON T1.property_type_code  =  T2.property_type_code GROUP BY T1.property_type_code	real_estate_properties
SELECT property_name FROM Properties WHERE property_type_code  =  "House" UNION SELECT property_name FROM Properties WHERE property_type_code  =  "Apartment" AND room_count  >  1	real_estate_properties
