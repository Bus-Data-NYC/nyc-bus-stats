-- this is sqlite, not mysql
CREATE TABLE stop_spacing AS
WITH stop AS (
    SELECT stop_id id, ST_Point(stop_lon, stop_lat) geom FROM stops
)
SELECT
    r.rds_index,
    r.route,
    r.direction,
    stop.id stop_id,
    CASE
        WHEN r.route = prev.route AND r.direction = prev.direction
        THEN ROUND(ST_Distance(stop.geom, sprev.geom, 1), 1)
        ELSE NULL
    END spacing_m
FROM rds_indexes r
LEFT JOIN stop ON (r.stop_id = stop.id)
LEFT JOIN rds_indexes prev ON (r.ROWID = prev.ROWID + 1)
LEFT JOIN stop sprev ON (prev.stop_id = sprev.id);
