INSERT INTO stat_headway_scheduled
    SELECT *
    FROM get_headway_scheduled($1, $2)
    ON CONFLICT DO NOTHING;

INSERT INTO stat_headway_observed
    SELECT *
    FROM get_headway_observed($1, $2)
    ON CONFLICT DO NOTHING;

SELECT
    date_trunc('month', service_date)::date AS month,
    route_id,
    direction_id,
    stop_id,
    (EXTRACT(isodow FROM service_date) >= 6 OR h.holiday IS NOT NULL) AS weekend,
    day_period(obs.datetime::time) AS period,
    COUNT(*) AS call_count,
    COUNT(NULLIF(false, obs.headway < sched.headway * 0.25)) AS bunch_count
FROM
    stat_headway_observed AS obs
    LEFT JOIN stat_headway_scheduled sched USING (trip_id, stop_id, service_date)
    LEFT JOIN gtfs_trips USING (feed_index, trip_id)
    LEFT JOIN stat_holidays h ON (h.date = obs.datetime::date)
GROUP BY
    date_trunc('month', service_date)::date,
    route_id,
    direction_id,
    stop_id,
    5, 6;
