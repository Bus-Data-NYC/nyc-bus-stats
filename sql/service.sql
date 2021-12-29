-- Counts of scheduled buses, observed buses, per route stop and direction

CREATE OR REPLACE FUNCTION get_service ("start" DATE, term INTERVAL)
    RETURNS TABLE(
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
        route_id,
        t.direction_id,
        stop_id,
        (EXTRACT(isodow FROM sh.date) > 5 OR holiday IS NOT NULL)::int AS weekend,
        day_period(wall_time(sh.date, arrival_time, agency_timezone)) as period,
        day_period_length(day_period(wall_time(sh.date, arrival_time, agency_timezone))) hours,
        COUNT(*)::int scheduled,
        COUNT(nullif(false, c.source = 'I'))::int observed

    FROM get_date_trips("start", ("start" + "term")::date) AS sh
        INNER JOIN gtfs.stop_times USING (feed_index, trip_id)
        LEFT JOIN gtfs.trips t USING (feed_index, trip_id)
        LEFT JOIN inferno.calls c USING (feed_index, date, trip_id, stop_id)
        LEFT JOIN stat.holidays h USING (date)
        LEFT JOIN gtfs.agency USING (feed_index)

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
