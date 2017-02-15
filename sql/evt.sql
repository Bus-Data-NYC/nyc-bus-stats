-- This is done in the Makefile. Uncomment if using the file directly.
-- SET @the_month = '2015-10-01';

DROP TABLE IF EXISTS `last_stops`;
CREATE TABLE last_stops (
    `trip_id` VARCHAR(32) PRIMARY KEY,
    `stop_count` INTEGER NOT NULL
);

INSERT last_stops
SELECT
    tg.`trip_id`,
    MAX(stg.`stop_sequence`) stop_count
FROM trips_gtfs tg
    LEFT JOIN `stop_times_gtfs` stg ON (tg.`trip_id` = stg.`trip_id`)
    LEFT JOIN `calendar_gtfs` cg ON (cg.`service_id` = tg.`service_id`)
WHERE
    `monday` = 1
    AND cg.`start_date` <= DATE_ADD(@the_month, INTERVAL 1 MONTH)
    AND cg.`end_date` >= @the_month
GROUP BY (tg.`trip_id`);

SELECT
    tg.`route_id`,
    @the_month month,
    day_period(s1.`arrival_time`) period,
    LEAST(COUNT(c2.`call_time`), COUNT(c1.`call_time`)) count_trips,
    AVG(TIME_TO_SEC(TIMEDIFF(s2.`arrival_time`, s1.`arrival_time`))) / 60 sched_duration_avg,
    AVG(TIME_TO_SEC(TIMEDIFF(
        DATE_ADD(
            IF(c2.`call_time` < c1.`call_time`, ADDDATE(d.date, 1), d.date),
            INTERVAL TIME_TO_SEC(c2.`call_time`) SECOND
        ),
        DATE_ADD(d.`date`, INTERVAL TIME_TO_SEC(c1.`call_time`) SECOND)
    ))) / 60 avg_obs_dur,
    COUNT(IF(TIMEDIFF(s2.`arrival_time`, s1.`arrival_time`) < TIMEDIFF(c2.`call_time`, c1.`call_time`), 1, NULL)) /
        LEAST(COUNT(c2.`call_time`), COUNT(c1.`call_time`)) pct_late
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
WHERE
    s1.`stop_sequence` = 1
    AND s2.`stop_sequence` = ls.`stop_count`
    AND DATE(c1.`call_time`) = d.`date`
    AND DATE(c2.`call_time`) = DATE(DATE_ADD(
        d.`date`,
        INTERVAL TIME_TO_SEC(TIMEDIFF(s2.`arrival_time`, s1.`arrival_time`)) SECOND
    ))
    AND d.`date` BETWEEN @the_month AND DATE_ADD(@the_month, INTERVAL 1 MONTH)
    AND tg.`route_id` = 'B11'
GROUP BY tg.`route_id`, 3;

-- SELECT
--     tg.`route_id`,
--     @the_month month,
--     s1.trip_id, t.trip_index,
--     day_period(s1.`arrival_time`) period,
--     s2.`arrival_time`,
--     s1.`arrival_time`,
--     c2.`call_time`,
--     c1.`call_time`,
--     SEC_TO_TIME((TIME_TO_SEC(TIMEDIFF(s2.`arrival_time`, s1.`arrival_time`)))) avg_sched_dur,
--     SEC_TO_TIME((TIME_TO_SEC(TIMEDIFF(
--         DATE_ADD(
--             IF(c2.`call_time` < c1.`call_time`, ADDDATE(d.date, 1), d.date),
--             INTERVAL TIME_TO_SEC(c2.`call_time`) SECOND
--         ),
--         DATE_ADD(d.`date`, INTERVAL TIME_TO_SEC(c1.`call_time`) SECOND)
--     )))) avg_obs_dur
-- FROM `trips_gtfs` tg
--     LEFT JOIN `trip_indexes` t ON (t.`gtfs_trip` = tg.`trip_id`)
--     LEFT JOIN `date_trips` d ON (d.`trip_index` = t.`trip_index`)
--     LEFT JOIN `stop_times_gtfs` s1 ON (s1.`trip_id` = tg.`trip_id`)
--     LEFT JOIN `last_stops` ls ON (ls.`trip_id` = tg.`trip_id`)
--     LEFT JOIN `stop_times_gtfs` s2 ON (s2.`trip_id` = s1.`trip_id`)
--     LEFT JOIN `rds_indexes` r1 ON (r1.`stop_id` = s1.`stop_id` AND r1.`route` = tg.`route_id`)
--     LEFT JOIN `calls` c1 ON (t.`trip_index` = c1.`trip_index` AND r1.`rds_index` = c1.`rds_index`)
--     LEFT JOIN `rds_indexes` r2 ON (r2.`stop_id` = s2.`stop_id` AND r2.`route` = tg.`route_id` AND r1.`direction` = r2.`direction`)
--     LEFT JOIN `calls` c2 ON (t.`trip_index` = c2.`trip_index` AND r2.`rds_index` = c2.`rds_index`)
-- WHERE
--     s1.`stop_sequence` = 1
--     AND s2.`stop_sequence` = ls.`stop_count`
--     AND DATE(c1.`call_time`) = d.`date`
--     AND DATE(c2.`call_time`) = DATE(DATE_ADD(
--         d.`date`,
--         INTERVAL TIME_TO_SEC(TIMEDIFF(s2.`arrival_time`, s1.`arrival_time`)) SECOND
--     ))
--     AND d.`date` BETWEEN @the_month AND DATE_ADD(@the_month, INTERVAL 1 MONTH)
--     AND tg.`route_id` = 'B11'
--     AND day_period(s1.`arrival_time`) = 5
--     AND t.trip_index=1351767
-- LIMIT 10;
