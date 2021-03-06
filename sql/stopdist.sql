-- For each stop, distance traveled along route-shape from previous stop.
CREATE OR REPLACE FUNCTION get_stopdist(feed integer, srid int default 3627)
    RETURNS TABLE(feed_index integer, route_id text, direction_id int, lead_stop_id text, lag_stop_id text, spacing numeric)
    AS $$
    SELECT feed_index, route_id, direction_id, lead_stop_id, lag_stop_id, min(spacing)
    FROM (
        SELECT
            feed_index
            , route_id
            , direction_id
            , stop_id as lead_stop_id
            , lag(stop_id) over (trip) as lag_stop_id
            , (length * (linelocate - lag(linelocate) over (trip)))::numeric as spacing
        from (
            select
                feed_index
                , route_id
                , trip_id
                , direction_id
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
        WINDOW trip AS (PARTITION BY feed_index, route_id, direction_id, trip_id order by stop_sequence)
    ) b
    WHERE spacing IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_stopdist (feeds int[], srid int default 3627)
    RETURNS TABLE(feed_index integer, route_id text, direction_id int, lead_stop_id text, lag_stop_id text, spacing numeric)
    AS $$
    WITH a (feed) as (SELECT unnest(feeds))
    SELECT b.* FROM a, get_stopdist(feed) b
    $$
LANGUAGE SQL STABLE;
