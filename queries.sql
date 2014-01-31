--Spatial Queries

--Join data based on country
SELECT a.country,a.downloads, b.name FROM 
    (SELECT country, sum(downloads) as downloads 
    FROM sfcountries 
    GROUP BY country) as a, 
  ne_10m_admin_0_countries as b 
  WHERE country = name;
--check the misses
SELECT country, downloads FROM (  
    SELECT a.country,a.downloads, b.name_long FROM 
    (SELECT country, sum(downloads) as downloads 
    FROM sfcountries 
    GROUP BY country) as a
    LEFT JOIN ne_10m_admin_0_countries as b 
    ON country = name_long
    )
WHERE name_long IS NULL;
--fix the easy ones
UPDATE sfcountries SET country="Vietnam" WHERE country LIKE "%Viet Nam%";
UPDATE sfcountries SET country="Russian Federation" WHERE country LIKE "%Russia%";
UPDATE sfcountries SET country="Republic of Korea" WHERE country LIKE "%Korea%";
UPDATE sfcountries SET country="Lao PDR" WHERE country LIKE "%Lao%";
UPDATE sfcountries SET country="Democratic Republic of the Congo" WHERE country LIKE "%Kinshasa%";
UPDATE sfcountries SET country="Côte d'Ivoire" WHERE country LIKE "%Ivory Coast%";

--'

-- Map Units from Natural Earth didn't pan out
-- However splitting France does help
-- Get France subunits and replace main France in new view that can be mapped and linked to other data
CREATE VIEW mapcountries AS
SELECT sovereignt,name,name_long,iso_a2,GEOMETRY FROM ne_10m_admin_0_countries WHERE name NOT LIKE "France"
UNION
SELECT sovereignt,name,name_long,iso_a2,GEOMETRY FROM ne_10m_admin_0_map_units WHERE  sovereignt LIKE "France";

-- Join the data for a map, VIEW doesn't carry column type correctly
-- What about % of population
CREATE TABLE sfdownbycountry as
SELECT a.country,a.downloads,b.geometry FROM 
    (SELECT country, sum(downloads) as downloads 
    FROM sfcountries 
    GROUP BY country) as a
    JOIN mapcountries as b 
    ON country = name_long

--
-- Now to map contributors and translators
--

-- Higher the count the longer+more people from a given country
SELECT country, count(a.name) as count 
FROM contributors as a 
LEFT JOIN ne_10m_admin_0_countries as b
ON country = b.name
GROUP BY country;   

--True count
SELECT country, count(distinct(a.name)) as count 
FROM contributors as a 
LEFT JOIN ne_10m_admin_0_countries as b
ON country = b.name
GROUP BY country;

--Join with map data
-- Join the rev dates first
SELECT country, name, a.rev, time 
FROM contributors as a,svnversion as b
WHERE a.rev = b.rev;

--Check that countries match
SELECT country, a.name,b.geometry 
FROM contributors as a 
LEFT JOIN ne_10m_admin_0_countries as b
ON country = b.name
GROUP BY country;


-- CREATE VIEW mapContribTime As
CREATE VIEW mapContribTime AS
SELECT a.rev,country,a.count,a.time,b.geometry  
FROM (SELECT country, a.rev,count(distinct(name)) as count, min(time) as time 
    FROM contributors as a,svnversion as b
    WHERE a.rev = b.rev
    GROUP BY country, a.rev
    ) as a 
LEFT JOIN ne_10m_admin_0_countries as b
ON country = b.name
ORDER BY rev, country;
--register it as spatial
INSERT INTO views_geometry_columns
(view_name, view_geometry, view_rowid, f_table_name, f_geometry_column)
VALUES ('mapContribTime', 'geometry', 'ROWID', 'ne_10m_admin_0_countries', 'geometry');


--Create Table 1st then insert records ensures right column types
CREATE TABLE mapContribTimeT2(
  rev INT,
  country TEXT,
  count INT,
  time timestamp,
  Geometry NUM
);
--Insert
INSERT INTO mapContribTimeT2 
SELECT "rev", "country", "count", substr("time",1,16), "Geometry"
FROM "mapContribTime";



---- Import of NetIndex data from Ookla
--Find countries that don't match natural earth (used as the standard)
SELECT DISTINCT a.country,a.country_code
FROM country_daily_speeds as a 
WHERE a.country_code NOT IN (SELECT iso_a2 FROM mapcountries);
--result 1 Netherlands Islands

----Import data from ITU
--Cleanup country code
SELECT DISTINCT a.country, b.name, b.name_long, b.iso_a2
FROM "ITU-Internet" as a, mapcountries as b
WHERE a.country LIKE b.name OR replace(a.country,'&','and') LIKE b.name_long;

--Add iso code column to imports
ALTER TABLE "ITU-Internet"
ADD Column 'iso_a2';
--update matches
UPDATE "ITU-Internet" SET iso_a2 = (SELECT b.iso_a2
FROM mapcountries as b
WHERE country LIKE b.name OR replace(country,'&','and') LIKE b.name_long);
--fix nulls
UPDATE "ITU-Internet" SET iso_a2 = (SELECT b.iso_a2
FROM ITUtoNEmap as b
WHERE "ITU-Internet".country LIKE b.country)
WHERE iso_a2 IS NULL;

--Add iso code column to imports
ALTER TABLE "ITU-Subscriptions"
ADD Column 'iso_a2';

--repeat for other ITU data
--update matches
UPDATE "ITU-Subscriptions" SET iso_a2 = (SELECT b.iso_a2
FROM mapcountries as b
WHERE country LIKE b.name OR replace(country,'&','and') LIKE b.name_long);

--fix nulls
UPDATE "ITU-Subscriptions" SET iso_a2 = (SELECT b.iso_a2
FROM ITUtoNEmap as b
WHERE "ITU-Subscriptions".country LIKE b.country)
WHERE iso_a2 IS NULL;

---- Analysis, how long does it take someone to download
-- Calculate download times per country
SELECT DISTINCT "country","country_code", max(download_kbps) as kbps, 
((4.7*8000000)/((max(download_kbps)*3600)) as hours
FROM country_daily_speeds
GROUP BY "Country"

--With broadband subscriptions (broadband is > ISDN?)
SELECT DISTINCT a."country","country_code", max(download_kbps) as kbps,((4.7*8000000)/((max(download_kbps)*3600))) as hours, b."2012" as users
FROM country_daily_speeds as a
JOIN "ITU-Subscriptions" as b
ON b.iso_a2 = a.country_code 
GROUP BY a."Country"


---- Analysis, what influence does internet speed, % of people with internet(broadband)
