CREATE OR REPLACE FUNCTION get_otp (start date, term interval)
    RETURNS TABLE(
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        early int,
        on_time int,
        late int
    )
    AS $$
    SELECT
        route_id,
        c.direction_id,
        stop_id,
        (EXTRACT(isodow FROM date) > 5 OR h.holiday IS NOT NULL)::int AS weekend,
        day_period(call_time at time zone agency_timezone) AS period,
        COUNT(NULLIF(false, deviation < interval '-1 min'))::int AS early,
        COUNT(NULLIF(false, deviation >= interval '-1 min' AND deviation <= interval '5 min'))::int AS on_time,
        COUNT(NULLIF(false, deviation > interval '5 min'))::int AS late
    FROM calls c
        LEFT JOIN gtfs_trips USING (feed_index, trip_id)
        LEFT JOIN stat_holidays h using ("date")
        LEFT JOIN gtfs_agency USING (feed_index)
    WHERE c.date >= "start"
        AND c.date < "start" + "term"
    GROUP BY
        route_id,
        c.direction_id,
        stop_id,
        EXTRACT(isodow FROM date) > 5 OR h.holiday IS NOT NULL,
        day_period(call_time at time zone agency_timezone)
    $$
LANGUAGE SQL STABLE;
