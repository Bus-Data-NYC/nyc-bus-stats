-- Speed is given by the distance covered and time elapsed between each call and the previous call
-- Uses only imputed calls.
-- Assumes that trip_id does not repeat across feed_indices.
-- Assumes time zone is US/Eastern.

CREATE OR REPLACE FUNCTION get_speed (start_date date)
    RETURNS TABLE(
        "month" date,
        route_id text,
        direction_id int,
        stop_id text,
        period int,
        weekend int,
        distance numeric,
        travel_time double precision
    )
    AS $$
    SELECT
        start_date,
        route_id,
        direction_id,
        stop_id,
        period,
        weekend::int,
        SUM(dist) distance,
        EXTRACT(epoch from SUM(elapsed)) travel_time
    FROM (
        SELECT
            day_period(call_time::time) AS period,
            EXTRACT(DOW FROM call_time) >= 5 OR h.holiday IS NOT NULL weekend,
            vehicle_id,
            route_id,
            direction_id,
            stop_id,
            gtfs_stop_times.shape_dist_traveled,
            call_time - LAG(call_time) OVER (run) AS elapsed,
            shape_dist_traveled - LAG(shape_dist_traveled) OVER (run) AS dist
        FROM calls
            LEFT JOIN gtfs_trips USING (trip_id, direction_id, route_id)
            LEFT JOIN gtfs_stop_times USING (trip_id, stop_id)
            LEFT JOIN stat_holidays h ON (h.date = (call_time AT TIME ZONE 'US/Eastern')::DATE)
        WHERE source = 'I'
            AND (call_time AT TIME ZONE 'US/Eastern')::DATE BETWEEN
                start_date AND start_date + INTERVAL '1 MONTH'
        WINDOW run AS (PARTITION BY vehicle_id, trip_id ORDER BY call_time ASC)
    ) raw
    WHERE elapsed > '00:00'::INTERVAL
        AND dist > 0
    GROUP BY
        route_id,
        direction_id,
        stop_id,
        period,
        weekend
    $$
LANGUAGE SQL STABLE;
