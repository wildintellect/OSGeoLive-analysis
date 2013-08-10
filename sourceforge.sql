--Percentage of downloads from sourceforge (6,6.5) by OS
SELECT sum(win)/b.total as win,sum(mac)/b.total as mac,sum(lin)/b.total as lin, sum(other)/b.total as other FROM sfosbycountry, (SELECT sum(win+mac+lin+other)*1.0 as total FROM sfosbycountry) as b
