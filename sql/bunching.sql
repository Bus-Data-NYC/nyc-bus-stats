CREATE OR REPLACE FUNCTION get_bunching (start date, term interval)
    RETURNS TABLE(
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
        route_id,
        direction_id,
        stop_id,
        (EXTRACT(isodow FROM "date") > 5 OR h.holiday IS NOT NULL)::int AS weekend,
        sched.period,
        -- number of rows with both kinds of headway recorded
        COUNT(*)::int as count,
        -- number of rows where observed interval is less than 1/4 of scheduled interval
        COUNT(NULLIF(FALSE, COALESCE(obs.headway < sched.headway * 0.25, FALSE)))::int AS bunch_count
    FROM
        stat.headway_scheduled AS sched
        LEFT JOIN stat.headway_observed AS obs USING (trip_id, stop_id, "date")
        LEFT JOIN gtfs.trips USING (feed_index, trip_id)
        LEFT JOIN stat.holidays h USING ("date")
    WHERE
        sched.date >= "start"
        AND sched.date < ("start" + "term")::date
        AND obs.date >= "start"
        AND obs.date < ("start" + "term")::date
        AND sched.headway IS NOT NULL
        AND obs.headway IS NOT NULL
    GROUP BY
        route_id,
        direction_id,
        stop_id,
        EXTRACT(isodow FROM "date") > 5 OR h.holiday IS NOT NULL,
        sched.period
    $$
LANGUAGE SQL STABLE;
