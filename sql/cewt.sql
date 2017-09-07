-- cewt
SELECT
    route_id
    direction_id,
    stop_id,
    day_period(obs.datetime::time) AS period,
    (EXTRACT(isodow FROM obs.datetime) >= 6 OR holiday IS NOT NULL) AS weekend,
    obs.headway AS headway_obs,
    sched.headway AS headway_sched,
    COUNT(*) AS count,
    COUNT(NULLIF(false, a.headway_obs > a.headway_sched)) AS count_cewt,
    ROUND(AVG(minutes(a.headway_obs - a.headway_sched)), 2) AS cewt_avg
FROM
    stat_headway_observed obs
    INNER JOIN stat_headway_scheduled sched USING (trip_id, route_id, direction_id, stop_id)
    LEFT JOIN stat_holidays AS h ON (h.date = obs.datetime::date)
WHERE 
    obs.datetime::date = sched.datetime::date
    AND sched.trip_id IS NOT NULL
    AND obs.datetime BETWEEN $1 and $2
GROUP BY route_id, 4, 5