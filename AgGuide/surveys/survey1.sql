CREATE VIEW FeatureRank AS
SELECT features1 as feature, count(features1) as count, count(features1)*5 as score FROM survey1 GROUP BY features1
UNION
SELECT features2, count(features2) as count, count(features2)*4 as score FROM survey1 GROUP BY features2
UNION
SELECT features3, count(features3) as count, count(features3)*3 as score FROM survey1 GROUP BY features3
UNION
SELECT features4, count(features4) as count, count(features4)*2 as score FROM survey1 GROUP BY features4
UNION
SELECT features5, count(features5) as count, count(features5)*1 as score FROM survey1 GROUP BY features5
;

CREATE VIEW FeatureScore AS
SELECT feature, Sum(score) as total FROM FeatureRank GROUP BY feature ORDER BY Sum(score) DESC;


CREATE VIEW SearchRank AS
SELECT search1 as search, count(search1) as count, count(search1)*5 as score FROM survey1 GROUP BY search1
UNION
SELECT search2, count(search2) as count, count(search2)*4 as score FROM survey1 GROUP BY search2
UNION
SELECT search3, count(search3) as count, count(search3)*3 as score FROM survey1 GROUP BY search3
UNION
SELECT search4, count(search4) as count, count(search4)*2 as score FROM survey1 GROUP BY search4
UNION
SELECT search5, count(search5) as count, count(search5)*1 as score FROM survey1 GROUP BY search5
;

CREATE VIEW SearchScore AS
SELECT search, Sum(score) as total FROM SearchRank GROUP BY search ORDER BY Sum(score) DESC;
