-- For each stop, distance traveled along route-shape from previous stop.
CREATE OR REPLACE FUNCTION get_stopdist(feed integer, srid int default 3627)
    RETURNS TABLE(feed_index integer, route_id text, stop_id text, spacing numeric)
    AS $$
    SELECT feed_index, route_id, stop_id, min(spacing)
    FROM (
        SELECT
            feed_index
            , route_id
            , trip_id
            , stop_id
            , (length * (linelocate - lag(linelocate) over (trip)))::numeric(5,2) as spacing
        from (
            select
                feed_index
                , route_id
                , trip_id
                , stop.stop_id
                , stop.the_geom
                , stop_sequence
                , shape.length
                , ST_LineLocatePoint(ST_Transform(shape.the_geom, srid), ST_Transform(stop.the_geom, srid)) linelocate
            from gtfs.routes
                left join gtfs.trips using (feed_index, route_id)
                left join gtfs.stop_times using (feed_index, trip_id)
                left join gtfs.stops stop using (feed_index, stop_id)
                left join gtfs.shape_geoms shape using (feed_index, shape_id)
            where feed_index = feed
            order by stop_sequence
        ) a
        WINDOW trip AS (PARTITION BY feed_index, route_id, trip_id order by stop_sequence)
    ) b
    GROUP BY feed_index, route_id, stop_id
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_stopdist (feeds int[], srid int default 3627)
    RETURNS TABLE(feed_index integer, route_id text, stop_id text, spacing numeric)
    AS $$
    WITH a (feed) as (SELECT unnest(feeds))
    SELECT b.* FROM a, get_stopdist(feed) b
    $$
LANGUAGE SQL STABLE;
