-- Estimate of downloads for 2011 from servers at ICE (2 of 5 servers)
CREATE View byVersion AS 
SELECT "5.0" as version, sum(viewed) as views,sum(entry) as entry ,sum(exit) as exit FROM osgeodowndata2011 WHERE file LIKE "%5.0%"
Union
SELECT "4.5"as version, sum(viewed) as views,sum(entry) as entry,sum(exit) as exit FROM osgeodowndata2011 WHERE file LIKE "%4.5%";

-- By Type
CREATE View byType AS 
SELECT "mini" as type, sum(viewed) as views ,sum(entry) as entry ,sum(exit) as exit FROM osgeodowndata2011 WHERE file LIKE "%mini%"
Union
SELECT "7z",sum(viewed),sum(entry),sum(exit) FROM osgeodowndata2011 WHERE file LIKE "%7z%"
Union
SELECT "fullsize",sum(viewed),sum(entry),sum(exit) FROM osgeodowndata2011 WHERE file NOT LIKE "%7z%" OR file NOT LIKE "%mini%";

-- Sum downloads by country
SELECT Countries,Code,sum(GB) as GB FROM bycountry2011
GROUP BY Countries

-- Join to shp
SELECT ScaleRank, Geometry,Countries as Country, Code, (GB * 1.0) as GB ,People FROM "110m_admin_0_countries" JOIN (
SELECT Countries,upper(Code) as Code,sum(GB) as GB FROM bycountry2011
GROUP BY Countries) 
ON SOVISO LIKE Code
