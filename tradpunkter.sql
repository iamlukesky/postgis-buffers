
-------

-- 4. klipp ut de träd som befinner sig inom buffern
CREATE TABLE tradvidvag AS
SELECT diffbuff.gid, trad.geom, namn, krondiamet as krona_dm, max_pixel_ as maxh_dm
FROM diffbuff, trad
WHERE ST_within(trad.geom, diffbuff.geom) AND class_name != 'träd i skog gt 1ha';
CREATE INDEX tradvidvag_gix ON tradvidvag USING GIST (geom);
-- 12 min

-- 5. buffra träden
CREATE TABLE tradbuff AS
SELECT tradvidvag.gid as diffbuffgid, (ST_dump(ST_buffer(ST_union(geom), 10))).geom as geom, namn
FROM tradvidvag
GROUP BY gid, namn;
ALTER TABLE tradbuff ADD COLUMN gid SERIAL PRIMARY KEY;
CREATE INDEX tradbuff_gix ON tradbuff USING GIST (geom);
-- 4 min


-- 6. räkna antal träd inom varje trädbufferenhet
CREATE TABLE antalinomtradbuff AS
SELECT tradbuff.gid, count(tradvidvag.geom) AS antal
FROM tradbuff LEFT JOIN tradvidvag
ON st_contains(tradbuff.geom, tradvidvag.geom) AND tradvidvag.gid = diffbuffgid
GROUP BY tradbuff.gid;
-- 37 sek

-- 7. plocka ut där det är mer än 5 träd 
CREATE TABLE allebuffrar AS
SELECT tradbuff.gid, diffbuffgid, antal, ST_buffer(tradbuff.geom, 10) as geom, namn
FROM tradbuff INNER JOIN antalinomtradbuff
ON tradbuff.gid = antalinomtradbuff.gid
WHERE antal >= 5;
CREATE INDEX allebuffrar_gix ON allebuffrar USING GIST (geom);
-- 1 min

-- Klipp up alletraden
CREATE TABLE alletrad AS
SELECT allebuffrar.gid, antal, tradvidvag.geom as geom, krona_dm, maxh_dm
FROM allebuffrar, tradvidvag
WHERE ST_Contains(allebuffrar.geom, tradvidvag.geom)
AND tradvidvag.gid = diffbuffgid;
-- 7 sek

-- 8. klipp väglinjer med trädbuffern
CREATE TABLE potallevag AS
SELECT v.gid, ST_length(v.geom) AS len, v.antal, v.geom
FROM(
	SELECT a.gid, (ST_dump(ST_intersection(vagnet.geom, a.geom))).geom as geom, a.antal
	FROM allebuffrar as a, vagnet
  WHERE ST_Intersects(vagnet.geom, a.geom)
) AS v;
CREATE INDEX potallevag_gix ON potallevag USING GIST (geom);
-- 1 min


CREATE TABLE potallevagcollect AS
SELECT c.gid, c.geom, ST_length(c.geom) as length, c.antal
FROM(
  SELECT gid, ST_multi(ST_collect(potallevag.geom)) as geom, antal
  FROM potallevag
  GROUP BY gid, antal
) as c;

--
CREATE TABLE allevagcollect AS
SELECT gid, length, antal, geom
FROM potallevagcollect
WHERE length > 50;

DROP TABLE potallevag, potallevagcollect;