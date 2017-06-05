-- route-level average stop spacing
/*
 * Calculated for each route-direction in the given feed.
 * Routes se different shape geometries. Avg spacing is calculated for each shape
 * and weighted by the number of trips that use the shape.
 */
SELECT
    $1 AS feed_index,
    route_id,
    direction_id,
    SUM(trip.count) AS trip_count,
    SUM(avg.spacing * trip.count) / SUM(trip.count) AS spacing_wavg
FROM (
    -- distinct route-direction-shape combinations, with count of trips
    SELECT
        route_id,
        direction_id,
        shape_id,
        COUNT(*) AS count
    FROM gtfs_stop_times
        LEFT JOIN gtfs_trips USING (feed_index, trip_id)
    WHERE
        ARRAY[feed_index] <@ $1
    GROUP BY
        route_id,
        direction_id,
        shape_id
    ) trip
    LEFT JOIN (
        -- average spacing on each shape
        SELECT
            shape_id,
            AVG(spacing) AS avg
        FROM (
            -- spacing along each shape
            SELECT
                shape_id,
                dist_along_shape - lag(dist_along_shape) OVER (PARTITION BY shape_id ORDER BY dist_along_shape) AS spacing
            FROM gtfs_shape_geoms
                LEFT JOIN gtfs_stop_distances_along_shape s USING (feed_index, shape_id)
            WHERE
                ARRAY[feed_index] <@ $1
        ) a GROUP BY shape_id
    ) spacing
    USING (shape_id)
GROUP BY route_id, direction_id;
