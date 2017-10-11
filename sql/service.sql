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
        "term",
        route_id,
        t.direction_id,
        stop_id,
        (EXTRACT(isodow FROM sh.date) > 5 OR holiday IS NOT NULL)::int AS weekend,
        day_period(wall_time(sh.date, arrival_time, agency_timezone)) as period,
        day_period_length(day_period(wall_time(sh.date, arrival_time, agency_timezone))) hours,
        COUNT(*)::int scheduled,
        COUNT(nullif(false, c.source = 'I'))::int observed

    FROM get_date_trips("start", ("start" + "term")::date) AS sh
        INNER JOIN gtfs_stop_times USING (feed_index, trip_id)
        LEFT JOIN gtfs_trips t USING (feed_index, trip_id)
        LEFT JOIN calls c USING (feed_index, date, trip_id, stop_id)
        LEFT JOIN stat_holidays h USING (date)
        LEFT JOIN gtfs_agency USING (feed_index)

    WHERE sh.date >= "start"
        AND sh.date < ("start" + "term")::DATE

    GROUP BY
        route_id,
        t.direction_id,
        stop_id,
        EXTRACT(isodow FROM sh.date) > 5 OR holiday IS NOT NULL,
        day_period(wall_time(sh.date, arrival_time, agency_timezone))
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
