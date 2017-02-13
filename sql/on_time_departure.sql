-- This is done in the Makefile. Uncomment if using the file directly.
-- SET @the_month = '2015-10-01';
SELECT
    `route_id`,
    tg.`trip_headsign`,
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
    AND DATE(c.call_time) BETWEEN '2015-10-01' AND '2015-10-31'
GROUP BY `route_id`
ORDER BY 3 DESC;