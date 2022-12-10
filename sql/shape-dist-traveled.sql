/*
 Populate stat.shape_dist_traveled table, a fallback when gtfs.stop_times (shape_dist_traveled) is empty
 */
INSERT INTO stat.shape_dist_traveled
SELECT
    DISTINCT ON (feed_index, route_id, shape_id, stop_id)
    feed_index,
    route_id,
    shape_id,
    stop_id,
    ST_LineLocatePoint(route_geom, ST_Transform(stops.the_geom, 3627)) * length AS shape_dist_traveled
FROM gtfs.stop_times AS st
    JOIN gtfs.stops USING (feed_index, stop_id)
    JOIN gtfs.trips AS t USING (feed_index, trip_id)
    JOIN gtfs.shape_geoms AS sg USING (feed_index, shape_id),
    ST_Transform(sg.the_geom, 3627) route_geom
ON CONFLICT DO NOTHING;
