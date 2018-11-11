-- cewt
CREATE OR REPLACE FUNCTION get_cewt (start date, term interval)
    RETURNS TABLE(
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        count int,
        count_cewt int,
        cewt_avg numeric(10, 2)
    )
    AS $$
    SELECT
        route_id,
        direction_id,
        stop_id,
        (EXTRACT(isodow FROM obs.date) > 5 OR holiday IS NOT NULL)::int AS weekend,
        obs.period,
        COUNT(*)::int AS count,
        COUNT(NULLIF(false, obs.headway > sched.headway))::int AS count_cewt,
        (AVG(EXTRACT(EPOCH FROM obs.headway - sched.headway)::NUMERIC / 60.))::numeric(10, 2) AS cewt_avg

    FROM
        stat.headway_observed obs
        INNER JOIN stat.headway_scheduled sched USING (trip_id, stop_id, date)
        LEFT JOIN gtfs.trips USING (feed_index, trip_id)
        LEFT JOIN stat.holidays AS h USING ("date")

    WHERE
        obs.date >= "start"
        and obs.date < ("start" + "term")::DATE
        AND obs.headway IS NOT NULL
        AND sched.headway IS NOT NULL
    GROUP BY
        route_id,
        direction_id,
        stop_id,
        EXTRACT(isodow FROM obs.date) > 5 OR holiday IS NOT NULL,
        obs.period
    $$
LANGUAGE SQL STABLE;
