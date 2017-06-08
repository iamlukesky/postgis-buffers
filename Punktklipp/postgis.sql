
-------
-- init/clear
DROP TABLE vag, bufferlarge, buffersmall, diffbuff, tradvidvag, tradbuff, allevag, allebuffrar;

-- prep:
-- ignorera evt. höjddata eller geometrier som är angivna i olika plan
ALTER TABLE vagnet
ALTER COLUMN geom TYPE geometry(MultiLineString, 3006)
USING ST_Force2D(geom);

-- 1. gör väglinjerna till en geometri
CREATE TABLE vag AS
SELECT ST_Multi(ST_Collect(vagnet.geom)) AS geom, namn
FROM vagnet, rutor
WHERE ST_intersects(vagnet.geom, rutor.geom)-- AND namn = 'THL_65_6_5025'
GROUP BY namn;
CREATE INDEX vag_gix ON vag USING GIST (geom);
-- st_union: 42 min (sthlm län, nästa steg krashade)
-- st_union: 25 min (alla rutor alla län)
-- st_collect: 2 min (alla rutor alla län)
-- st_collect + st_intersects: 43 sec (alla rutor alla län)

-- 2. stor och liten buffer runt vägen
CREATE TABLE bufferlarge AS
SELECT ST_buffer(geom, 15, 'endcap=flat') as geom, namn
FROM vag;
CREATE INDEX bufferlarge_gix ON bufferlarge USING GIST (geom);

CREATE TABLE buffersmall AS
SELECT ST_buffer(geom, 1, 'endcap=square') as geom, namn
FROM vag;
CREATE INDEX buffersmall_gix ON buffersmall USING GIST (geom);
-- 30 min (alla rutor)

-- 3. differens mellan buffrarna för att få vardera sida om vägen
CREATE TABLE diffbuff AS
SELECT (ST_dump(ST_difference(bufferlarge.geom, buffersmall.geom))).geom as geom, bufferlarge.namn
FROM bufferlarge, buffersmall
WHERE bufferlarge.namn = buffersmall.namn;
ALTER TABLE diffbuff ADD COLUMN gid SERIAL PRIMARY KEY;
CREATE INDEX diffbuff_gix ON diffbuff USING GIST (geom);
-- 52 min (allla rutor)

-- 4. klipp ut de träd som befinner sig inom buffern
CREATE TABLE tradvidvag AS
SELECT diffbuff.gid, trad.geom, namn, trad.krondiamet as krondiameter
FROM diffbuff, trad
WHERE ST_within(trad.geom, diffbuff.geom);
CREATE INDEX tradvidvag_gix ON tradvidvag USING GIST (geom);

-- 5. buffra träden
CREATE TABLE tradbuff AS
SELECT (ST_dump(ST_buffer(ST_union(geom), 10))).geom as geom, namn
FROM tradvidvag
GROUP BY gid, namn;
ALTER TABLE tradbuff ADD COLUMN gid SERIAL PRIMARY KEY;
CREATE INDEX tradbuff_gix ON tradbuff USING GIST (geom);

-- 6. räkna antal träd inom varje trädbufferenhet
CREATE TABLE antalinomtradbuff AS
SELECT tradbuff.gid, count(tradvidvag.geom) AS antal
FROM tradbuff LEFT JOIN tradvidvag
ON st_contains(tradbuff.geom, tradvidvag.geom)
GROUP BY tradbuff.gid;

-- 7. plocka ut där det är mer än 5 träd 
CREATE TABLE allebuffrar AS
SELECT tradbuff.gid, antal, ST_buffer(tradbuff.geom, 10) as geom
FROM tradbuff INNER JOIN antalinomtradbuff
ON tradbuff.gid = antalinomtradbuff.gid
WHERE antal >= 5;
CREATE INDEX allebuffrar_gix ON allebuffrar USING GIST (geom);

-- 8. klipp väglinjer med trädbuffern
CREATE TABLE potallevag AS
SELECT v.gid, ST_length(v.geom) AS len, v.antal, v.geom
FROM(
	SELECT a.gid, (ST_dump(ST_intersection(vag.geom, a.geom))).geom as geom, a.antal
	FROM allebuffrar as a, vag
) AS v;

-- 9. ta bort vägsegemnt kortare än 45-50 m (vilken ska det vara?)
CREATE TABLE allevag AS
SELECT gid, len, antal, geom
FROM potallevag
WHERE len > 50;