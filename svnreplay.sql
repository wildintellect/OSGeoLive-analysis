--Useful sql for svnreplay

SELECT c.rev, COUNT(name),time FROM contributors as c, svnversion as v WHERE c.rev = v.rev GROUP BY c.rev


--Create Table to store OSGeo Live release Dates
CREATE TABLE if not Exists release 
( version TEXT, 
  rev INTEGER, --svn version of the tag
  time TEXT,
  codename TEXT,
  iso REAL,
  mini REAL,
  vm REAL,
);
