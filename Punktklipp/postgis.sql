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
DROP TABLE kgaBuffer
-- making the buffer


CREATE TABLE kgabuffer AS
SELECT ST_difference(bufferlarge, buffersmall) as geom, kommunnamn
FROM(
	SELECT
		ST_buffer( vl.geom, 15, 'endcap=flat join=mitre quad_segs=2' ) as bufferlarge,
		ST_buffer( vl.geom, 1, 'endcap=square join=mitre quad_segs=2') as buffersmall,
    kommunnamn
	FROM(
		SELECT vagnet.geom AS geom, kommunnamn
		FROM vagnet, ak_riks
		WHERE ST_within(vagnet.geom, ak_riks.geom) AND ak_riks.kommunnamn = 'Karlskoga'
	) AS vl
) AS diff;


CREATE TABLE uniontest AS
SELECT ST_union(geom)AS geom
FROM(
		SELECT vagnet.geom AS geom, kommunnamn
		FROM vagnet, ak_riks
		WHERE ST_within(vagnet.geom, ak_riks.geom) AND ak_riks.kommunnamn = 'Karlskoga'
) AS vl;


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