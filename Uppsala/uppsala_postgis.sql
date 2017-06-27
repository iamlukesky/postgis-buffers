
-------
-- init/clear

-- prep:

drop table 
tradvidvag,
tradvidvagoppenmark,
tradbuff,
antalinomtradbuff,
allebuffrar,
alletrad,
potallevag,
potallevagcollect,
allevagcollect;

-- oppenmarkmask
-- CREATE TABLE traduppsalaoppenmark AS
-- SELECT traduppsala.geom, traduppsala.krona_dm as krondiameter, traduppsala.maxh_dm as maxhojd, traduppsala.meanh_dm as meanhojd
-- FROM oppenmark_uppsala, traduppsala
-- WHERE ST_Intersects(traduppsala.geom, oppenmark_uppsala.geom);
-- CREATE INDEX traduppsalaoppenmark_gix ON traduppsalaoppenmark USING GIST (geom);
-- -- 

-- CREATE TABLE traduppsalaoppenmark AS
-- SELECT traduppsala.krona_dm as krondiameter, traduppsala.maxh_dm as maxhojd, traduppsala.meanh_dm as meanhojd, ST_Value(rast, geom, true) as oppenmark, geom
-- FROM uppsala_oppenmark, traduppsala
-- WHERE ST_Intersects(rast, geom);
-- CREATE INDEX traduppsalaoppenmark_gix ON traduppsalaoppenmark USING GIST (geom);
-- 11 mi

-- 4. klipp ut de träd som befinner sig inom buffern
CREATE TABLE tradvidvag AS
SELECT diffbuff.gid, traduppsala.geom, namn, krona_dm, maxh_dm, meanh_dm
FROM diffbuff, traduppsala
WHERE ST_within(traduppsala.geom, diffbuff.geom);
CREATE INDEX tradvidvag_gix ON tradvidvag USING GIST (geom);
-- 10 min

CREATE TABLE tradvidvagoppenmark AS
SELECT gid, krona_dm, maxh_dm, meanh_dm, ST_Value(rast, geom, true) as oppenmark, geom
FROM uppsala_oppenmark, tradvidvag
WHERE ST_Intersects(rast, geom);
CREATE INDEX tradvidvagoppenmark_gix ON tradvidvagoppenmark USING GIST (geom);
-- 1 min

-- 5. buffra träden
CREATE TABLE tradbuff AS
SELECT tradvidvagoppenmark.gid as diffbuffgid, (ST_dump(ST_buffer(ST_union(geom), 10))).geom as geom, oppenmark
FROM tradvidvagoppenmark
WHERE oppenmark IS NULL or oppenmark = 1
GROUP BY gid, oppenmark;
ALTER TABLE tradbuff ADD COLUMN gid SERIAL PRIMARY KEY;
CREATE INDEX tradbuff_gix ON tradbuff USING GIST (geom);
-- 1 min

-- 6. räkna antal träd inom varje trädbufferenhet
CREATE TABLE antalinomtradbuff AS
SELECT tradbuff.gid, count(tradvidvagoppenmark.geom) AS antal
FROM tradbuff LEFT JOIN tradvidvagoppenmark
ON st_contains(tradbuff.geom, tradvidvagoppenmark.geom) AND tradvidvagoppenmark.gid = diffbuffgid
GROUP BY tradbuff.gid;
-- 10 sek

-- 7. plocka ut där det är mer än 5 träd 
CREATE TABLE allebuffrar AS
SELECT tradbuff.gid, diffbuffgid, antal, ST_buffer(tradbuff.geom, 10) as geom, namn
FROM tradbuff
INNER JOIN antalinomtradbuff ON tradbuff.gid = antalinomtradbuff.gid
WHERE antal >= 5;
CREATE INDEX allebuffrar_gix ON allebuffrar USING GIST (geom);
-- 50 sek

CREATE TABLE alletrad AS
SELECT allebuffrar.gid, antal, tradvidvagoppenmark.geom as geom, krona_dm, maxh_dm, meanh_dm
FROM allebuffrar, tradvidvagoppenmark
WHERE ST_Contains(allebuffrar.geom, tradvidvagoppenmark.geom)
AND tradvidvagoppenmark.gid = diffbuffgid;
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
-- 1 sek

-- 9. ta bort vägsegemnt kortare än 45-50 m (vilken ska det vara?)
-- CREATE TABLE allevag AS
-- SELECT gid, len, antal, geom
-- FROM potallevag
-- WHERE len > 50;

CREATE TABLE allevagcollect AS
SELECT gid, length, antal, geom
FROM potallevagcollect
WHERE length > 50;
-- 0.5 sek