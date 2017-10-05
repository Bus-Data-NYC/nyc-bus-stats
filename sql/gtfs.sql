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
        ROUND((ST_Length(the_geom) / ST_Distance(ST_StartPoint(the_geom), ST_EndPoint(the_geom)))::numeric, 2) routeratio
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
        wavg numeric
    )
    AS $$
    SELECT
        feed_index,
        route_id,
        direction_id,
        SUM(trip.count)::integer AS trip_count,
        SUM(spacing.avg * trip.count) / SUM(trip.count) AS wavg
    FROM (
        -- distinct route-direction-shape combinations, with count of trips
        SELECT
            feed_index,
            route_id,
            direction_id,
            shape_id,
            COUNT(*) AS count
        FROM gtfs_stop_times
            LEFT JOIN gtfs_trips USING (feed_index, trip_id)
        WHERE feed_index = "feed"
        GROUP BY
            feed_index,
            route_id,
            direction_id,
            shape_id
    ) trip
    LEFT JOIN (
        -- average spacing on each shape
        SELECT
            feed_index,
            shape_id,
            AVG(spacing) AS avg
        FROM (
            -- spacing along each shape
            SELECT
                feed_index,
                shape_id,
                dist_along_shape - lag(dist_along_shape) OVER (shape) AS spacing
            FROM gtfs_shape_geoms
                LEFT JOIN gtfs_stop_distances_along_shape s USING (feed_index, shape_id)
            WHERE feed_index = "feed"
            WINDOW shape AS (PARTITION BY feed_index, shape_id ORDER BY dist_along_shape)
        ) a GROUP BY feed_index, shape_id
    ) spacing
        USING (feed_index, shape_id)
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

-- minimum distance from each stop to nearest stop on same route-shape
-- averaged for all stops on the route
CREATE OR REPLACE FUNCTION get_stopdist(feed integer)
    RETURNS TABLE(feed_index integer, stop_id text, wavg numeric)
    AS $$
    SELECT
        feed_index,
        stop_id,
        ROUND(SUM(weights.count * dists.spacing) / SUM(weights.count), 2) wavg
    FROM (
        SELECT
            feed_index,
            shape_id,
            stop_id,
            LEAST(lead(dist_along_shape) OVER (shape) - dist_along_shape, dist_along_shape - lag(dist_along_shape) OVER (shape)) AS spacing
        FROM gtfs_shape_geoms
            LEFT JOIN gtfs_stop_distances_along_shape s USING (feed_index, shape_id)
        WHERE feed_index = "feed"
        WINDOW shape AS (PARTITION BY feed_index, shape_id ORDER BY dist_along_shape)
    ) dists
    LEFT JOIN (
        SELECT
            feed_index,
            shape_id,
            stop_id,
            COUNT(*) AS count
        FROM gtfs_stop_times
            LEFT JOIN gtfs_trips USING (feed_index, trip_id)
        WHERE feed_index = "feed"
        GROUP BY
            feed_index,
            shape_id,
            stop_id
    ) weights USING (feed_index, shape_id, stop_id)
    GROUP BY feed_index, stop_id;
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_stopdist (feeds int[])
    RETURNS TABLE(feed_index integer, stop_id text, wavg numeric)
    AS $$
    WITH a (feed) as (SELECT unnest(feeds))
    SELECT b.* FROM a, get_stopdist(feed) b
    $$
LANGUAGE SQL STABLE;
