-- on time departure
-- pct of runs per route and period that depart on time

CREATE OR REPLACE FUNCTION get_otd (start date, term interval)
    RETURNS TABLE(
        "start" date,
        term,
        route_id text,
        direction_id int,
        weekend int,
        period int,
        count int,
        count_otd int
    )
    AS $$
    SELECT
        "start",
        "term",
        route_id,
        direction_id,
        (EXTRACT(isodow FROM call_time AT TIME ZONE 'US/Eastern') > 5 OR h.holiday IS NOT NULL)::int weekend,
        day_period(call_time AT TIME ZONE 'US/Eastern') AS period,
        COUNT(IF(
            TIME_TO_SEC(TIMEDIFF(TIME(c.call_time), st.time)) <= 3 * 60,
            1, NULL
        )) / COUNT(*) pct_otd
    FROM get_date_trips("start", ("start" + "term")::DATE) d
        LEFT JOIN gtfs_trips USING (feed_index, trip_id)
        LEFT JOIN gtfs_calendar cg USING (feed_index, service_id)
        LEFT JOIN gtfs_stop_times USING (feed_index, trip_id)
        LEFT JOIN calls c USING (feed_index, trip_id, "date")
        LEFT JOIN stat_holidays h USING ("date")
    WHERE
        stop_sequence = 3
    GROUP BY
        route_id,
        direction_id,
        EXTRACT(isodow FROM call_time AT TIME ZONE 'US/Eastern') > 5 OR h.holiday IS NOT NULL,
        day_period(call_time AT TIME ZONE 'US/Eastern')
ORDER BY 3 DESC;
