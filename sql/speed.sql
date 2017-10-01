-- Speed is given by the distance covered and time elapsed between each call and the previous call
-- Uses only imputed calls.
-- Assumes that trip_id does not repeat across feed_indices.
-- Assumes time zone is US/Eastern.

CREATE OR REPLACE FUNCTION get_speed (start date, term interval)
    RETURNS TABLE(
        "month" date,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        distance numeric,
        travel_time numeric,
        count int
    )
    AS $$
    SELECT
        "start" as month,
        route_id,
        direction_id,
        stop_id,
        weekend::int,
        period,
        ROUND(SUM(dist)::numeric, 3) distance,
        ROUND(EXTRACT(epoch from SUM(elapsed))::numeric, 1) travel_time,
        COUNT(*)::integer count
    FROM (
        SELECT
            day_period(call_time::time) AS period,
            EXTRACT(DOW FROM call_time) >= 5 OR h.holiday IS NOT NULL weekend,
            route_id,
            direction_id,
            stop_id,
            call_time - LAG(call_time) OVER (run) AS elapsed,
            shape_dist_traveled - LAG(shape_dist_traveled) OVER (run) AS dist
        FROM calls
            LEFT JOIN gtfs_trips USING (trip_id, direction_id, route_id)
            LEFT JOIN gtfs_stop_times USING (trip_id, stop_id)
            LEFT JOIN stat_holidays h ON (h.date = (call_time AT TIME ZONE 'US/Eastern')::DATE)
        WHERE source = 'I'
            AND (call_time AT TIME ZONE 'US/Eastern')::DATE >= "start"
            AND (call_time AT TIME ZONE 'US/Eastern')::DATE < ("start" + "term")::DATE
        WINDOW run AS (PARTITION BY vehicle_id, trip_id ORDER BY call_time ASC)
    ) raw
    WHERE elapsed > '00:00'::INTERVAL
        AND dist > 0
    GROUP BY
        route_id,
        direction_id,
        stop_id,
        weekend,
        period
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_speed ("start" date)
    RETURNS TABLE(
        "month" date,
        route_id text,
        direction_id int,
        stop_id text,
        period int,
        weekend int,
        distance numeric,
        travel_time numeric,
        count int
    )
    AS $$
    SELECT * FROM get_speed("start", INTERVAL '1 MONTH')
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_speed (start_date date, term interval, route text)
    RETURNS TABLE(
        "month" date,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        distance numeric,
        travel_time numeric,
        count int
    )
    AS $$
    SELECT
        start_date,
        route_id,
        direction_id,
        stop_id,
        weekend::int,
        period,
        ROUND(SUM(dist)::numeric, 3) distance,
        ROUND(EXTRACT(epoch from SUM(elapsed))::numeric, 1) travel_time,
        COUNT(*)::integer count
    FROM (
        SELECT
            day_period(call_time::time) AS period,
            EXTRACT(DOW FROM call_time) >= 5 OR h.holiday IS NOT NULL weekend,
            route_id,
            direction_id,
            stop_id,
            call_time - LAG(call_time) OVER (run) AS elapsed,
            shape_dist_traveled - LAG(shape_dist_traveled) OVER (run) AS dist
        FROM calls
            LEFT JOIN gtfs_trips USING (trip_id, direction_id, route_id)
            LEFT JOIN gtfs_stop_times USING (trip_id, stop_id)
            LEFT JOIN stat_holidays h ON (h.date = (call_time AT TIME ZONE 'US/Eastern')::DATE)
        WHERE source = 'I'
            AND (call_time AT TIME ZONE 'US/Eastern')::DATE BETWEEN
                start_date AND start_date + term
            AND route_id = route
        WINDOW run AS (PARTITION BY vehicle_id, trip_id ORDER BY call_time ASC)
    ) raw
    WHERE elapsed > '00:00'::INTERVAL
        AND dist > 0
    GROUP BY
        route_id,
        direction_id,
        stop_id,
        weekend,
        period
    SELECT * FROM get_speed("start", INTERVAL '1 MONTH')
    $$
LANGUAGE SQL STABLE;
