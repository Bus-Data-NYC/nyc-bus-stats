CREATE OR REPLACE FUNCTION get_routeratio (feed integer)
    RETURNS TABLE (
        feed_index integer,
        route_id text,
        direction_id int,
        shape_id text,
        routeratio numeric
    )
    AS $$
    SELECT
        feed_index,
        route_id,
        direction_id,
        shape_id,
        (length / ST_Distance(ST_StartPoint(the_geom)::geography, ST_EndPoint(the_geom)::geography))::numeric(10, 2) routeratio
    FROM gtfs_shape_geoms
        LEFT JOIN gtfs_trips using (feed_index, shape_id)
    WHERE feed_index = "feed"
        AND route_id IS NOT NULL
    GROUP BY feed_index, route_id, direction_id, shape_id
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_routeratio (feeds int[])
    RETURNS TABLE (
        feed_index integer,
        route_id text,
        direction_id int,
        shape_id text,
        routeratio numeric
    )
    AS $$
    WITH a (feed) as (SELECT unnest(feeds))
    SELECT b.* FROM a, get_routeratio(feed) b
    $$
LANGUAGE SQL STABLE;

-- route-level average stop spacing
/*
 * Calculated for each route-direction in the given feed.
 * Routes se different shape geometries. Avg spacing is calculated for each shape
 * and weighted by the number of trips that use the shape.
 */
CREATE OR REPLACE FUNCTION get_spacing(feed integer)
    RETURNS TABLE(
        feed_index integer,
        route_id text,
        direction_id integer,
        trip_count integer,
        avg numeric
    )
    AS $$
    SELECT
        feed_index,
        route_id,
        direction_id,
        COUNT(DISTINCT trip_id)::int as trip_count,
        AVG(spacing)::numeric(10, 2) as avg
    FROM (
        SELECT
            feed_index,
            route_id,
            direction_id,
            trip_id,
            shape_dist_traveled - lag(shape_dist_traveled) OVER (shape) as spacing
        FROM gtfs_stop_times
            LEFT JOIN gtfs_trips USING (feed_index, trip_id)
            LEFT JOIN gtfs_routes USING (feed_index, route_id)
        WHERE feed_index = "feed"
        WINDOW shape AS (PARTITION BY feed_index, trip_id ORDER BY stop_sequence)
    ) spacing
    GROUP BY feed_index, route_id, direction_id
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_spacing (feeds int[])
    RETURNS TABLE(
        feed_index integer,
        route_id text,
        direction_id integer,
        trip_count integer,
        wavg numeric
    )
    AS $$
    WITH a (feed) as (SELECT unnest(feeds))
    SELECT b.* FROM a, get_spacing(feed) b
    $$
LANGUAGE SQL STABLE;
