-- SET @the_month = '2015-10-01', @the_route = 'B11';

SELECT
    tg.`route_id`,
    LEFT(@the_month, 7) month,
    day_period(s1.`arrival_time`) period,
    COUNT(*) count_trips,
    ROUND(AVG(TIME_TO_SEC(TIMEDIFF(s2.`arrival_time`, s1.`arrival_time`))) / 60, 2) duration_sched_avg,
    ROUND(AVG(TIME_TO_SEC(TIMEDIFF(
        DATE_ADD(
            IF(c2.`call_time` < c1.`call_time`, ADDDATE(d.`date`, 1), d.`date`),
            INTERVAL TIME_TO_SEC(c2.`call_time`) SECOND
        ),
        DATE_ADD(d.`date`, INTERVAL TIME_TO_SEC(c1.`call_time`) SECOND)
    ))) / 60, 2) duration_obs_avg,
    cewt.sched sched_wait_avg,
    cewt.obs obs_wait_avg,
    cewt.ewt_avg,
    cewt.count_ewt
FROM `trips_gtfs` tg
    LEFT JOIN `trip_indexes` t ON (t.`gtfs_trip` = tg.`trip_id`)
    LEFT JOIN `date_trips` d ON (d.`trip_index` = t.`trip_index`)
    LEFT JOIN `stop_times_gtfs` s1 ON (s1.`trip_id` = tg.`trip_id`)
    LEFT JOIN `last_stops` ls ON (ls.`trip_id` = tg.`trip_id`)
    LEFT JOIN `stop_times_gtfs` s2 ON (s2.`trip_id` = s1.`trip_id`)
    LEFT JOIN `rds_indexes` r1 ON (r1.`stop_id` = s1.`stop_id` AND r1.`route` = tg.`route_id`)
    LEFT JOIN `calls` c1 ON (t.`trip_index` = c1.`trip_index` AND r1.`rds_index` = c1.`rds_index`)
    LEFT JOIN `rds_indexes` r2 ON (r2.`stop_id` = s2.`stop_id` AND r2.`route` = tg.`route_id` AND r1.`direction` = r2.`direction`)
    LEFT JOIN `calls` c2 ON (t.`trip_index` = c2.`trip_index` AND r2.`rds_index` = c2.`rds_index`)
    LEFT JOIN `cewt_avg` cewt ON (cewt.period = day_period(s1.arrival_time) AND tg.route_id = cewt.route)
WHERE
    s1.`stop_sequence` = 1
    AND s2.`stop_sequence` = ls.`stop_count`
    AND DATE(c1.`call_time`) = d.`date`
    AND DATE(c2.`call_time`) = DATE(DATE_ADD(
        d.`date`,
        INTERVAL TIME_TO_SEC(TIMEDIFF(s2.`arrival_time`, s1.`arrival_time`)) SECOND
    ))
    AND d.`date` BETWEEN @the_month AND DATE_ADD(@the_month, INTERVAL 1 MONTH)
    AND tg.`route_id` = @the_route
    AND s2.`arrival_time` IS NOT NULL
    AND s1.`arrival_time` IS NOT NULL
GROUP BY 1, 3;
