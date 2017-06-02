---------------------------------
--- orginalet för vägbuffern-----
---------------------------------


CREATE TABLE split2 AS
SELECT gid, rlid, lansnamn, (ST_dump(geom_collection)).geom as geom
FROM (
	SELECT 	vl.gid as gid,
		vl.rlid as rlid,
		vl.lansnamn as lansnamn,
		ST_Split(buffer.geom, ST_Linemerge(vl.geom)) as geom_collection
	FROM 
		(SELECT
			vagnet.gid, vagnet.rlid, ak.lansnamn, vagnet.geom
			FROM vagnet, an_riks AS ak
			WHERE ST_within(vagnet.geom, ak.geom) --WHERE ak.kommunnamn/ak.lansnamn = ''
		) as vl, 
		(SELECT gid, rlid,
			ST_buffer(geom, 15, 'endcap=flat join=mitre quad_segs=2') AS geom
		FROM vagnet) as buffer
	WHERE vl.gid = buffer.gid) as s;



-- karlskoga
-------
-- init/clear
DROP TABLE vag, bufferlarge, buffersmall, diffbuff, tradvidvag, tradbuff;

-- 1. gör väglinjerna till en geometri
CREATE TABLE vag AS
SELECT ST_union(vagnet.geom) AS geom, kommunnamn
FROM vagnet, ak_riks
WHERE ST_within(vagnet.geom, ak_riks.geom) AND ak_riks.kommunnamn = 'Karlskoga'
GROUP BY kommunnamn;
CREATE INDEX vag_gix ON vag USING GIST (geom);

-- 2. stor och liten buffer runt vägen
CREATE TABLE bufferlarge AS
SELECT ST_buffer(geom, 15, 'endcap=flat') as geom, kommunnamn
FROM vag;
CREATE INDEX bufferlarge_gix ON bufferlarge USING GIST (geom);

CREATE TABLE buffersmall AS
SELECT ST_buffer(geom, 1, 'endcap=square') as geom, kommunnamn
FROM vag;
CREATE INDEX buffersmall_gix ON buffersmall USING GIST (geom);

-- 3. differens mellan buffrarna för att få vardera sida om vägen
CREATE TABLE diffbuff AS
SELECT (ST_dump(ST_difference(bufferlarge.geom, buffersmall.geom))).geom as geom, bufferlarge.kommunnamn
FROM bufferlarge, buffersmall;
ALTER TABLE diffbuff ADD COLUMN gid SERIAL PRIMARY KEY;
CREATE INDEX diffbuff_gix ON diffbuff USING GIST (geom);

-- 4. klipp ut de träd som befinner sig inom buffern
CREATE TABLE tradvidvag AS
SELECT diffbuff.gid, trad.geom, kommunnamn
FROM diffbuff, tree_65_4_7550_vid_vag as trad
WHERE ST_within(trad.geom, diffbuff.geom);
CREATE INDEX tradvidvag_gix ON tradvidvag USING GIST (geom);

-- 5. buffra träden
CREATE TABLE tradbuff AS
SELECT (ST_dump(ST_buffer(ST_union(geom), 10))).geom as geom, kommunnamn
FROM tradvidvag
GROUP BY gid, kommunnamn;
ALTER TABLE tradbuff ADD COLUMN gid SERIAL PRIMARY KEY;
CREATE INDEX tradbuff_gix ON tradbuff USING GIST (geom);

-- 6. räkna antal träd inom varje trädbufferenhet
CREATE TABLE antalinomtradbuff AS
SELECT tradbuff.gid, count(tradvidvag.geom) AS antal
FROM tradbuff LEFT JOIN tradvidvag
ON st_contains(tradbuff.geom, tradvidvag.geom)
GROUP BY tradbuff.gid;

-- 7. plocka ut där det är mer än 5 träd (todo: ska plocka ut trädbuffenheterna, inte träden)
SELECT trad.geom, buff.gid
FROM(
	SELECT tradbuff.gid
	FROM tradbuff INNER JOIN antalinomtradbuff
	ON tradbuff.gid = antalinomtradbuff.gid
	WHERE antal >= 5;
) as buff,
tradvidvag as trad
WHERE ST_within(trad.geom, buff.geom);

-- 8. buffra trädbuffern lite till

-- 9. klipp väglinjer med trädbuffern

-- 10. ta bort vägsegemnt kortare än 45-50 m (vilken ska det vara?)








-- CREATE TABLE tradbuffdiff AS
-- SELECT (ST_dump(ST_difference(tradbuff.geom, buffersmall.geom))).geom as geom, tradbuff.kommunnamn
-- FROM buffersmall, tradbuff;
-- ALTER TABLE tradbuffdiff ADD COLUMN id SERIAL PRIMARY KEY;
-- CREATE INDEX tradbuffdiff_gix ON tradbuffdiff USING GIST (geom);




-- slow:
-- CREATE TABLE tradbuffinomdiffbuff AS
-- SELECT ST_intersection(tradbuff.geom, diffbuff.geom) as geom, tradbuff.kommunnamn
-- FROM tradbuff, diffbuff;
-- CREATE INDEX tradbuffinomdiffbuff_gix ON tradbuffinomdiffbuff USING GIST (geom);


-- 1. buffra vaeg
CREATE TABLE kgabuffer AS
SELECT ST_dump(ST_difference(bufferlarge, buffersmall)) as geom, kommunnamn
FROM(
	SELECT
		ST_buffer( vl.geom, 15, 'endcap=flat join=mitre quad_segs=2' ) as bufferlarge,
		ST_buffer( vl.geom, 1, 'endcap=square join=mitre quad_segs=2') as buffersmall,
    kommunnamn
	FROM(
		SELECT ST_union(geom)AS geom, kommunnamn
		FROM(
			SELECT vagnet.geom AS geom, kommunnamn
			FROM vagnet, ak_riks
			WHERE ST_within(vagnet.geom, ak_riks.geom) AND ak_riks.kommunnamn = 'Karlskoga'
		) AS vl GROUP BY kommunnamn
	) AS vl
) as vl;

-- 2. klipp trädpunkter inom buff
CREATE TABLE kgatradvidvag AS
SELECT trad.geom, kommunnamn  FROM kgabuffer, tree_65_4_7550_vid_vag as trad
WHERE ST_within(trad.geom, kgabuffer.geom);


CREATE TABLE kgatradvidvagbuff AS
SELECT (ST_dump(ST_buffer(trad.geom, 10))).geom as geom, kommunnamn
FROM(
	SELECT ST_union(trad.geom) as geom, kommunnamn
    FROM kgabuffer, tree_65_4_7550_vid_vag as trad
		WHERE ST_within(trad.geom, kgabuffer.geom)
    GROUP BY kommunnamn
) as trad
WHERE ST_intersects(geom, kgabuffer.geom);

-- 3. buffra träd 10m

-- 4. 


-- CREATE TABLE uniontest AS
-- SELECT ST_union(geom)AS geom
-- FROM(
-- 		SELECT vagnet.geom AS geom, kommunnamn
-- 		FROM vagnet, ak_riks
-- 		WHERE ST_within(vagnet.geom, ak_riks.geom) AND ak_riks.kommunnamn = 'Karlskoga'
-- ) AS vl;


-- CREATE TABLE kgabuffer AS
-- SELECT ST_difference(bufferlarge, buffersmall) as geom, kommunnamn
-- FROM(

-- 	SELECT
-- 		ST_buffer( vl.geom, )

-- ) as diff;


-- FUNKAR:
CREATE TABLE kgabuffer AS
SELECT ST_difference(bufferlarge, buffersmall) as geom, kommunnamn
FROM(
	SELECT
		ST_buffer( vl.geom, 15, 'endcap=flat join=mitre quad_segs=2' ) as bufferlarge,
		ST_buffer( vl.geom, 1, 'endcap=square join=mitre quad_segs=2') as buffersmall,
    kommunnamn
	FROM(
		SELECT ST_union(geom)AS geom, kommunnamn
		FROM(
			SELECT vagnet.geom AS geom, kommunnamn
			FROM vagnet, ak_riks
			WHERE ST_within(vagnet.geom, ak_riks.geom) AND ak_riks.kommunnamn = 'Karlskoga'
		) AS vl GROUP BY kommunnamn
	) AS vl
) as diff;


-- CREATE TABLE kgaBuffer AS
-- SELECT gid, rlid, lansnamn, (ST_dump(geom_collection)).geom as geom
-- FROM (
-- 	SELECT 	vl.gid as gid,
-- 		vl.rlid as rlid,
-- 		vl.lansnamn as lansnamn,
-- 		ST_Split(buffer.geom, ST_Linemerge(vl.geom)) as geom_collection
-- 	FROM 
-- 		(SELECT
-- 			vagnet.gid, vagnet.rlid, ak.lansnamn, vagnet.geom
-- 			FROM vagnet, an_riks AS ak
-- 			WHERE ST_within(vagnet.geom, ak.geom) WHERE ak.kommunnamn = 'Karlskoga'
-- 		) as vl, 
-- 		(SELECT gid, rlid,
-- 			ST_buffer(geom, 15, 'endcap=flat join=mitre quad_segs=2') AS geom
-- 		FROM vagnet) as buffer
-- 	WHERE vl.gid = buffer.gid) as s;

	-- merge buffer
-- CREATE TABLE kgamergebuffer AS
-- SELECT
--    lansnamn, ST_Multi(ST_Union(f.geom)) as geom
-- 	 FROM kgabuffer As f
-- 	 GROUP BY lansnamn;