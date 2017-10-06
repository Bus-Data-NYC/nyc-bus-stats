CREATE OR REPLACE FUNCTION get_otp (start date, term interval)
    RETURNS TABLE(
        start date,
        term interval,
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
        "start",
        "term",
        route_id,
        direction_id,
        stop_id,
        (EXTRACT(isodow FROM call_time at time zone 'US/Eastern') > 5 OR h.holiday IS NOT NULL)::int AS weekend,
        day_period(call_time at time zone 'US/Eastern') AS period,
        COUNT(NULLIF(false, deviation < interval '-60'))::int AS early,
        COUNT(NULLIF(false, deviation >= interval '-60' AND deviation <= interval '300'))::int AS on_time,
        COUNT(NULLIF(false, deviation > interval '300'))::int AS late
    FROM calls
        LEFT JOIN stat_holidays h ON (trip_start_date = h.date)
    WHERE trip_start_date >= "start"
        AND trip_start_date < "start" + "term"
    GROUP BY
        route_id,
        direction_id,
        stop_id,
        EXTRACT(isodow FROM call_time at time zone 'US/Eastern') > 5 OR h.holiday IS NOT NULL,
        day_period(call_time at time zone 'US/Eastern')
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_otp (start date)
    RETURNS TABLE(
        month date,
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
    SELECT start AS month, route_id, direction_id, stop_id,
        weekend, period, early, on_time, late
    FROM get_otp(start, '1 MONTH'::INTERVAL)
    $$
LANGUAGE SQL STABLE;
