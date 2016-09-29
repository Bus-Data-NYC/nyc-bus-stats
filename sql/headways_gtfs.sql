/*
    The `headways_gtfs` table joins each scheduled call by a particular
    route at a given stop to the previous call by that route at that stop.
    Then it calculates the difference in time between the two calls. The
    query controls for changes in service, so the first calls on the morning
    of each service do not have a headway.
*/

-- Set to the first day of the month in question
SET @the_month = '2015-10-01';

-- join schedule to schedule to get scheduled headways (minutes)
DROP TABLE IF EXISTS `headways_gtfs`;
CREATE TABLE `headways_gtfs` (
  `trip_index` int(11) NOT NULL PRIMARY KEY,
  `stop_id` INTEGER NOT NULL,
  `headway` MEDIUMINT UNSIGNED DEFAULT NULL,
  KEY tripstop (trip_index, stop_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

INSERT INTO headways_gtfs (trip_index, stop_id, headway)
SELECT
    i.`trip_index`,
    a.`stop_id`,
    TIME_TO_SEC(TIMEDIFF(
        a.`arrival_time`,
        CAST(
            GROUP_CONCAT(z.`arrival_time` ORDER BY z.`arrival_time` DESC, '|')
            AS TIME
        )
    )) AS headway
FROM
    `stop_times_gtfs` a
    LEFT JOIN `stop_times_gtfs` z ON (
        a.`stop_id` = z.`stop_id`
        AND a.`stop_sequence` = z.`stop_sequence`
    )
    LEFT JOIN `trips_gtfs` t1 ON (t1.`trip_id` = a.`trip_id`)
    LEFT JOIN `trips_gtfs` t2 ON (t2.`trip_id` = z.`trip_id`)
    LEFT JOIN `rds_indexes` r ON (
        r.`direction` = t1.`direction_id`
        AND r.`route` = t1.`route_id`
        AND r.`stop_id` = a.`stop_id`
    )
    LEFT JOIN `trip_indexes` i ON (t1.`trip_id` = i.`gtfs_trip`)
    LEFT JOIN `calendar_gtfs` cg ON (cg.`service_id` = t1.`service_id`)
WHERE
    z.`arrival_time` < a.`arrival_time`
    AND t1.`trip_id` != t2.`trip_id`
    AND t1.`route_id` = t2.`route_id`
    AND t1.`service_id` = t2.`service_id`
    AND t1.`direction_id` = t2.`direction_id`
    AND (
        @the_month BETWEEN cg.`start_date` AND cg.`end_date`
        OR DATE_ADD(@the_month, INTERVAL 1 MONTH) BETWEEN cg.`start_date` AND cg.`end_date`
    )
GROUP BY a.`trip_id`, r.`rds_index`;
