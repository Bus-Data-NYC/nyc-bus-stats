-- on time departure
-- pct of runs per route and period that depart on time
CREATE OR REPLACE FUNCTION get_otd (start date, term interval)
    RETURNS TABLE(
        "start" date,
        term interval,
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
        (EXTRACT(isodow FROM date AT TIME ZONE 'US/Eastern') > 5 OR h.holiday IS NOT NULL)::int weekend,
        day_period(wall_time(date, arrival_time, 'US/Eastern')) AS period,
        count(*)::int count,
        count(nullif(false, c.call_time at time zone 'US/Eastern' - wall_time(date, arrival_time, 'US/Eastern') <= interval '3 min'))::int count_otd
    FROM get_date_trips("start", ("start" + "term")::DATE) d
        LEFT JOIN gtfs_stop_times USING (feed_index, trip_id)
        LEFT JOIN calls c USING (feed_index, trip_id, "date", stop_id)
        LEFT JOIN stat_holidays h USING ("date")
    WHERE
        stop_sequence = 3
    GROUP BY
        route_id,
        direction_id,
        EXTRACT(isodow FROM date AT TIME ZONE 'US/Eastern') > 5 OR h.holiday IS NOT NULL,
        day_period(wall_time(date, arrival_time, 'US/Eastern'))
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_otd (start date)
    RETURNS TABLE(
        "month" date,
        route_id text,
        direction_id int,
        weekend int,
        period int,
        count int,
        count_otd int
    )
    AS $$
    SELECT
        start,
        route_id,
        direction_id,
        weekend,
        period,
        count,
        count_otd
    FROM get_otd ("start", interval '1 month');
    $$
LANGUAGE SQL STABLE;
