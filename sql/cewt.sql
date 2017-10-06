-- cewt
CREATE OR REPLACE FUNCTION get_cewt (start date, term interval)
    RETURNS TABLE(
        start date,
        term interval,
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
        start,
        term,
        route_id
        direction_id,
        stop_id,
        (EXTRACT(isodow FROM obs.date) > 5 OR holiday IS NOT NULL)::int AS weekend,
        obs.period,
        COUNT(*) AS count,
        COUNT(NULLIF(false, a.headway_obs > a.headway_sched)) AS count_cewt,
        ROUND(AVG(EXTRACT(EPOCH FROM a.headway_obs - a.headway_sched)::NUMERIC / 60.), 2) AS cewt_avg
    FROM
        stat_headway_observed obs
        INNER JOIN stat_headway_scheduled sched USING (trip_id, stop_id, date)
        LEFT JOIN stat_holidays AS h USING ("date")
    WHERE 
        sched.trip_id IS NOT NULL
        AND date >= "start"
        AND date < ("start" + "term")::DATE
    GROUP BY route_id, 4, 5
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_cewt (start_date DATE)
    RETURNS TABLE(
        start date,
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        count int,
        count_cewt int,
        cewt_avg numeric(10, 2)
    ) AS $$
    SELECT
        start,
        route_id,
        direction_id,
        stop_id,
        weekend,
        period,
        count,
        count_cewt,
        cewt_avg
    FROM get_cewt(start_date, interval '1 month')
    $$
LANGUAGE SQL STABLE;
