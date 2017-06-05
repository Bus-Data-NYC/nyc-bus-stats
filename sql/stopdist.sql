-- minimum distance from each stop to nearest stop on same route-shape
-- averaged for all stops on the route

SELECT
    stop_id,
    ROUND(SUM(weights.count * dists.spacing) / SUM(weights.count), 2) stopspacing_wavg
FROM (
    SELECT
        feed_index,
        shape_id,
        stop_id,
        LEAST(lead(dist_along_shape) OVER (shape) - dist_along_shape, dist_along_shape - lag(dist_along_shape) OVER (shape)) AS spacing
    FROM gtfs_shape_geoms
        LEFT JOIN gtfs_stop_distances_along_shape s USING (feed_index, shape_id)
    WHERE ARRAY[feed_index] <@ $1
    WINDOW shape AS (PARTITION BY shape_id ORDER BY dist_along_shape)
) dists
    LEFT JOIN (
        SELECT
            feed_index,
            shape_id,
            stop_id,
            COUNT(*) AS count
        FROM gtfs_stop_times
            LEFT JOIN gtfs_trips USING (feed_index, trip_id)
        where ARRAY[feed_index] <@ $1
        GROUP BY
            feed_index,
            shape_id,
            stop_id
    ) weights USING (feed_index, shape_id, stop_id)
GROUP BY stop_id;
