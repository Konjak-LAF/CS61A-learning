CREATE table newest AS
  SELECT title, year  from titles
  order by year DESC
  LIMIT 10
  ;


CREATE table dog_movies AS 
  SELECT t.title, p.character
  FROM titles as t
  JOIN principals as p ON t.tconst == p.tconst
  WHERE p.character LIKE "%dog%"
  ;


CREATE table leads AS 
  SELECT n.name, count(p.ordering) as lead_roles
  FROM names as n
  JOIN principals as p ON n.nconst == p.nconst
  WHERE p.ordering == 1
  GROUP BY n.nconst
  HAVING count(*) > 10
  ;


CREATE table long_movies AS 
  SELECT ((year / 10 * 10) || "s") AS decade, count(*) AS count
  FROM titles
  WHERE runtime > 180
  GROUP BY (year / 10)
  ;

