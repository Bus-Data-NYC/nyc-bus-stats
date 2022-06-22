-- Speed is given by the distance covered and time elapsed between each call and the previous call
-- Uses only imputed calls.
-- Assumes that trip_id does not repeat across feed_indices.
CREATE OR REPLACE FUNCTION get_speed (start date, term interval)
    RETURNS TABLE(
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        distance int,
        travel_time int,
        count int
    )
    AS $$
    SELECT
        route_id,
        direction_id,
        stop_id,
        weekend::int AS weekend,
        period,
        SUM(dist)::int distance,
        EXTRACT(epoch from SUM(elapsed))::int travel_time,
        COUNT(*)::int count
    FROM (
        SELECT
            EXTRACT(isodow FROM date) > 5 OR h.holiday IS NOT NULL weekend,
            day_period(call_time AT TIME ZONE agency_timezone) AS period,
            route_id,
            c.direction_id,
            stop_id,
            call_time - LAG(call_time) OVER (run) AS elapsed,
            coalesce(st.shape_dist_traveled, sdt.shape_dist_traveled) - LAG(coalesce(st.shape_dist_traveled, sdt.shape_dist_traveled)) OVER (run) AS dist
        FROM inferno.calls as c
            LEFT JOIN gtfs.trips USING (feed_index, trip_id)
            LEFT JOIN gtfs.stop_times st USING (feed_index, trip_id, stop_id)
            LEFT JOIN stat.holidays h USING ("date")
            LEFT JOIN gtfs.agency USING (feed_index)
            LEFT JOIN stat.shape_dist_traveled AS sdt USING (feed_index, route_id, shape_id, stop_id)
        WHERE source = 'I'
            AND date >= "start"
            AND date < ("start" + "term")::DATE
        WINDOW run AS (PARTITION BY run_index ORDER BY call_time ASC)
    ) raw
    WHERE elapsed > INTERVAL '0'
        AND dist > 0
    GROUP BY
        route_id,
        direction_id,
        stop_id,
        weekend,
        period
    $$
LANGUAGE SQL STABLE;
