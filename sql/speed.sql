-- Speed is given by the distance covered and time elapsed between each call and the previous call
-- Uses only imputed calls.
-- Assumes that trip_id does not repeat across feed_indices.
-- Assumes time zone is US/Eastern.
CREATE OR REPLACE FUNCTION get_speed (start date, term interval)
    RETURNS TABLE(
        "start" date,
        "term" interval,
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
        "start",
        "term" term,
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
            day_period(call_time AT TIME ZONE 'US/Eastern') AS period,
            route_id,
            direction_id,
            stop_id,
            call_time - LAG(call_time) OVER (run) AS elapsed,
            shape_dist_traveled - LAG(shape_dist_traveled) OVER (run) AS dist
        FROM calls as c
            LEFT JOIN gtfs_trips USING (feed_index, trip_id, direction_id)
            LEFT JOIN gtfs_stop_times USING (feed_index, trip_id, stop_id)
            LEFT JOIN stat_holidays h USING ("date")
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

CREATE OR REPLACE FUNCTION get_speed ("start" date)
    RETURNS TABLE(
        "month" date,
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
    SELECT start AS month,
        route_id,
        direction_id,
        stop_id,
        weekend,
        period,
        distance,
        travel_time,
        count
    FROM get_speed("start", INTERVAL '1 MONTH')
    $$
LANGUAGE SQL STABLE;
