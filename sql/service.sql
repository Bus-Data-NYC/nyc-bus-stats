-- Counts of scheduled buses, observed buses, per route stop and direction

CREATE OR REPLACE FUNCTION get_service ("start" DATE, term INTERVAL)
    RETURNS TABLE(
        start date,
        term interval,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        hours int,
        scheduled int,
        observed int
    ) AS $$
    SELECT
        "start" AS start,
        term,
        route_id,
        c.direction_id,
        stop_id,
        (EXTRACT(isodow FROM sh.date) > 5 OR holiday IS NOT NULL)::int AS weekend,
        day_period((call_time - deviation) at time zone 'US/Eastern') AS period,
        day_period_length(day_period((call_time - deviation) at time zone 'US/Eastern')) hours,
        COUNT(*)::int scheduled,
        COUNT(nullif(false, c.source = 'I'))::int observed

    FROM stat_headway_scheduled AS sh
        LEFT JOIN calls c USING (feed_index, date, trip_id, stop_id)
        LEFT JOIN gtfs_trips USING (feed_index, trip_id)
        LEFT JOIN stat_holidays h USING (date)

    WHERE sh.date >= "start"
        AND sh.date < ("start" + "term")::DATE

    GROUP BY
        route_id,
        c.direction_id,
        stop_id,
        EXTRACT(isodow FROM sh.date) > 5 OR holiday IS NOT NULL,
        day_period((call_time - deviation) at time zone 'US/Eastern')
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_service ("start" DATE)
    RETURNS TABLE(
        month date,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        hours int,
        scheduled int,
        observed int
    ) AS $$
    SELECT
        "start" as month,
        route_id,
        direction_id,
        stop_id,
        weekend,
        period,
        hours,
        scheduled,
        observed
    FROM get_service("start", INTERVAL '1 MONTH')
    $$
LANGUAGE SQL STABLE;
