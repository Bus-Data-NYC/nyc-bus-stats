-- This is done in the Makefile. Uncomment if using the file directly.
-- SET @the_month = '2015-10-01';
SELECT
    `route_id`,
    tg.`trip_headsign`,
    day_period(TIME(c.call_time)) AS day_period,
    COUNT(IF(
        TIME_TO_SEC(TIMEDIFF(TIME(c.`call_time`), st.`time`)) <= 3 * 60,
        1, NULL
    )) / COUNT(*) pct_otd
FROM 
    `trips_gtfs` tg 
    LEFT JOIN `calendar_gtfs` cg ON (tg.`service_id` = cg.`service_id`)
    LEFT JOIN `trip_indexes` t ON (t.`gtfs_trip` = tg.`trip_id`)
    LEFT JOIN `stop_times` st ON (t.`trip_index` = st.`trip_index`)
    LEFT JOIN `calls` c ON (c.`trip_index` = t.`trip_index`)
WHERE
    cg.`monday` = 1
    AND st.`stop_sequence` = 3
    AND c.`stop_sequence` = 3
    AND DATE(c.call_time) BETWEEN @the_month AND DATE_SUB(DATE_ADD(@the_month, INTERVAL 1 MONTH), INTERVAL 1 DAY)
    AND WEEKDAY(c.call_time) < 5
    AND DATE(c.call_time) NOT IN ('2015-12-24', '2015-12-25', '2016-01-01', '2016-02-15', '2016-05-30')
GROUP BY
    tg.route_id,
    day_period(TIME(c.call_time))
ORDER BY 3 DESC;
