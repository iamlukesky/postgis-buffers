--------------
--Experiment--
--------------
SELECT vl.geom, ak.kommunnamn, ak.lansnamn, vl.gid
FROM vagnet AS vl, ak_riks AS ak
WHERE ST_within(vl.geom, ak.geom) AND ak.kommunnamn = 'Vaxholm';

SELECT ST_linemerge(vl.geom) AS geom, ak.kommunnamn, ak.lansnamn, vl.gid
INTO vaxholm
FROM vagnet AS vl, ak_riks AS ak
WHERE ST_within(vl.geom, ak.geom) AND ak.kommunnamn = 'Vaxholm';

SELECT ST_buffer(geom, 15, 'endcap=flat join=round') AS geom
FROM vaxholm AS vl;

--splittest:
SELECT ST_split(buffer.geom, ST_linemerge(line.geom))
FROM vaxholm AS line, vaxholm_buff_15 AS buffer;

SELECT ST_split(buffer.geom, line.geom)as geom
INTO splitbuff
FROM vaxholm AS line, vaxholm_buff_15 AS buffer;


CREATE TABLE split AS
SELECT ST_split(buffer.geom, line.geom) as geom, 


CREATE TABLE vaxholm AS
SELECT vl.gid, vl.rlid, ak.kommunnamn, ak.lansnamn, vl.geom
FROM vagnet AS vl, ak_riks AS ak
WHERE ST_within(vl.geom, ak.geom) AND ak.kommunnamn = 'Vaxholm';

CREATE TABLE buffer AS
SELECT gid, rlid, kommunnamn, lansnamn, ST_buffer(geom, 15, 'endcap=flat join=mitre quad_segs=2') AS geom
FROM vaxholm;

CREATE TABLE split AS
SELECT 	vl.gid as gid,
	vl.rlid as rlid,
	vl.kommunnamn as kommunnamn,
	vl.lansnamn as lansnamn,
	ST_split(buffer.geom, ST_linemerge(vl.geom)) as geom_collection
FROM vaxholm as vl, buffer
WHERE vl.gid = buffer.gid;

SELECT (ST_dump(geom_collection)).geom as geom, gid, rlid
FROM split;

# SELECT ST_Split(ln.geom,ST_Union(ST_Snap(pt.geom, ln.geom, ST_Distance(pt.geom, ln.geom)*1.01))) FROM points pt, lines ln;

CREATE TABLE split AS
SELECT gid, rlid, kommunnamn, lansnamn, (ST_dump(geom_collection)).geom as geom
FROM (
	SELECT 	vl.gid as gid,
		vl.rlid as rlid,
		vl.kommunnamn as kommunnamn,
		vl.lansnamn as lansnamn,
		ST_Split(buffer.geom, ST_Linemerge(vl.geom)) as geom_collection
	FROM vaxholm as vl, (
		SELECT gid, rlid, kommunnamn, lansnamn,
			ST_buffer(geom, 15, 'endcap=flat join=mitre quad_segs=2') AS geom
		FROM vaxholm) as buffer
	WHERE vl.gid = buffer.gid) as s;

---------
--Final--
---------
CREATE TABLE split AS
SELECT gid, rlid, kommunnamn, lansnamn, (ST_dump(geom_collection)).geom as geom
FROM (
	SELECT 	vl.gid as gid,
		vl.rlid as rlid,
		vl.kommunnamn as kommunnamn,
		vl.lansnamn as lansnamn,
		ST_Split(buffer.geom, ST_Linemerge(vl.geom)) as geom_collection
	FROM 
		(SELECT
			vagnet.gid, vagnet.rlid, ak.kommunnamn, ak.lansnamn, vagnet.geom
			FROM vagnet, ak_riks AS ak
			WHERE ST_within(vagnet.geom, ak.geom) --WHERE ak.kommunnamn/ak.lansnamn = ''
		) as vl, 
		(SELECT gid, rlid,
			ST_buffer(geom, 15, 'endcap=flat join=mitre quad_segs=2') AS geom
		FROM vagnet) as buffer
	WHERE vl.gid = buffer.gid) as s;

