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
SELECT sovereignt, name_long,GEOMETRY FROM ne_10m_admin_0_countries WHERE name NOT LIKE "France"
UNION
SELECT sovereignt, name_long,GEOMETRY FROM ne_10m_admin_0_map_units WHERE  sovereignt LIKE "France";

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

-- CREATE VIEW
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
