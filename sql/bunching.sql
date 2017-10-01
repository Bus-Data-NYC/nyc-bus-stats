CREATE OR REPLACE FUNCTION get_bunching (start date, term interval)
    RETURNS TABLE(
        start date,
        interval interval,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        count int,
        bunch_count int
    )
    AS $$
    SELECT
        start,
        interval,
        route_id,
        direction_id,
        stop_id,
        EXTRACT(isodow FROM "date") > 5 OR h.holiday IS NOT NULL AS weekend,
        period,
        -- number of rows with both kinds of headway recorded
        COUNT(NULLIF(TRUE, sched.headway IS NULL OR obs.headway IS NULL))::int as count,
        -- number of rows where observed interval is less than 1/4 of scheduled interval
        COUNT(NULLIF(FALSE, COALESCE(obs.headway < sched.headway * 0.25, FALSE)))::int AS bunch_count
    FROM
        stat_headway_scheduled AS sched
        LEFT JOIN stat_headway_observed AS obs USING (trip_id, stop_id, "date")
        LEFT JOIN gtfs_trips USING (feed_index, trip_id)
        LEFT JOIN stat_holidays h USING ("date")
    WHERE
        "date" >= "start"
        AND "date" < ("start" + "term")::date
    GROUP BY
        route_id,
        direction_id,
        stop_id,
        EXTRACT(isodow FROM "date") > 5 OR h.holiday IS NOT NULL,
        period
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_bunching (start date)
    RETURNS TABLE(
        "month" date,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        count int,
        bunch_count int
    )
    AS $$
    SELECT start AS month, route_id, direction_id, stop_id,
        weekend, period, count, bunch_count
    FROM get_bunching(start, INTERVAL '1 MONTH')
    $$
LANGUAGE SQL STABLE;
