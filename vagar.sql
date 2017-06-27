
-- Preparation av NVDB
-- Innan import till PostGIS, spara om shapefilen utan z-values. 



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