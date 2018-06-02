-- on time departure
-- pct of runs per route and period that depart on time
CREATE OR REPLACE FUNCTION get_otd (start date, term interval)
    RETURNS TABLE(
        route_id text,
        direction_id int,
        weekend int,
        period int,
        count int,
        count_otd int
    )
    AS $$
    SELECT
        route_id,
        c.direction_id,
        (EXTRACT(isodow FROM date) > 5 OR h.holiday IS NOT NULL)::int weekend,
        day_period(wall_time(date, arrival_time, agency_timezone)) AS period,
        count(*)::int count,
        count(nullif(false, c.call_time at time zone agency_timezone - wall_time(date, arrival_time, agency_timezone) <= interval '3 min'))::int count_otd
    FROM get_date_trips("start", ("start" + "term")::DATE) d
        LEFT JOIN gtfs.stop_times USING (feed_index, trip_id)
        INNER JOIN calls c USING (feed_index, trip_id, "date", stop_id)
        LEFT JOIN gtfs.trips USING (feed_index, trip_id)
        LEFT JOIN stat_holidays h USING ("date")
        LEFT JOIN gtfs.agency USING (feed_index)
    WHERE
        stop_sequence = 3
    GROUP BY
        route_id,
        c.direction_id,
        EXTRACT(isodow FROM date) > 5 OR h.holiday IS NOT NULL,
        day_period(wall_time(date, arrival_time, agency_timezone))
    $$
LANGUAGE SQL STABLE;
