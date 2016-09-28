-- Number of distinct rds_index (route-direction-stop) (calls_2015-10): 25262

-- join schedule to schedule to get scheduled headways (minutes)
DROP TABLE IF EXISTS `headways_gtfs`;
CREATE TABLE `headways_gtfs` (
  `trip_index` int(11) NOT NULL PRIMARY KEY,
  `stop_id` INTEGER NOT NULL,
  `headway` MEDIUMINT UNSIGNED DEFAULT NULL,
  KEY stop (stop_id)
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
    LEFT JOIN `stop_times_gtfs` z ON (a.`stop_id` = z.`stop_id` AND a.stop_sequence = z.stop_sequence)
    LEFT JOIN `trips_gtfs` t1 ON (t1.`trip_id` = a.`trip_id`)
    LEFT JOIN `trips_gtfs` t2 ON (t2.`trip_id` = z.`trip_id`)
    LEFT JOIN `rds_indexes` r ON (
        r.`direction` = t1.`direction_id`
        AND r.`route` = t1.`route_id`
        AND r.`stop_id` = a.`stop_id`
    )
    LEFT JOIN `trip_indexes` i ON (t1.`trip_id` = i.`gtfs_trip`)
WHERE
    z.`arrival_time` < a.`arrival_time`
    AND t1.`trip_id` != t2.`trip_id`
    AND t1.`route_id` = t2.`route_id`
    AND t1.`service_id` = t2.`service_id`
    AND t1.`direction_id` = t2.`direction_id`
    AND a.`stop_sequence` = 1
    AND z.`stop_sequence` = 1
GROUP BY r.`rds_index`, a.`trip_id`;

-- join calls to calls to get observed headway
SELECT
    *,
    (TIME_TO_SEC(TIMEDIFF(a.`call_time`, b.`call_time`)) + a.`dwell_time`) / 60. headway
FROM
    `calls` a
    LEFT JOIN `trip_indexes` m ON (m.`trip_index` = a.`trip_index`)
    LEFT JOIN `trips_gtfs` t1 ON (t1.`trip_id` = m.`gtfs_trip`)
    LEFT JOIN `calls` b ON (a.`rds_index` = b.`rds_index`)
    LEFT JOIN `trip_indexes` n ON (n.`trip_index` = b.`trip_index`)
    LEFT JOIN `trips_gtfs` t2 ON (t2.`trip_id` = n.`gtfs_trip`)
WHERE
    b.`call_time` < a.`call_time`
    AND t2.`service_id` = t1.`service_id`;

-- join calls to stop_times_gtfs and headways_gtfs

SELECT
    *
FROM
    calls
    LEFT JOIN headways_gtfs h ON (
        h.`rds_index` = calls.`rds_index`
        AND h.`trip_index` = calls.`trip_index`
    )


--- Other approach:
--- Indexing calls and stop_times by service, rds_index
SET @stop = 0, @rds = NULL, @service = NULL;

CREATE TABLE calls_by_service (
    service_id varchar(64) DEFAULT NULL,
    rds_index INTEGER NOT NULL,
    stop SMALLINT NOT NULL,
    KEY (rds_index, stop),
    KEY (service_id)
);

SET @stop = 0, @rds = NULL, @service = NULL;

INSERT INTO calls_by_service (`stop`, `service_id`, `rds_index`)
SELECT
    @stop := IF(
        @service_id = `service_id` && @rds = `rds_index`,
        @stop + 1,
        1
    ) AS "stop",
    @service_id := `service_id`,
    @rds := `rds_index`
FROM (
    SELECT `service_id`, `rds_index`, `call_time`
    FROM `calls` AS c
        LEFT JOIN `trip_indexes` i ON (i.`trip_index` = c.`trip_index`)
        LEFT JOIN `trips_gtfs` t ON (t.`trip_id` = i.`gtfs_trip`)
    ORDER BY
        `service_id`,
        c.`rds_index`,
        c.`call_time` ASC
) a;

-- stop times

CREATE TABLE stop_times_by_service (
    service_id varchar(64) DEFAULT NULL,
    rds_index INTEGER NOT NULL,
    stop SMALLINT NOT NULL,
    KEY (rds_index, stop),
    KEY (service_id)
);

SET @stop = 0, @rds = NULL, @service = NULL;
INSERT INTO stop_times_by_service (stop, service_id, rds_index)
SELECT
    @stop := IF(
        @service_id = `service_id` && @rds = `rds_index`,
        @stop + 1,
        1
    ) AS "stop",
    @service_id := `service_id`,
    @rds := `rds_index`
FROM (
    SELECT `service_id`, `rds_index`, `arrival_time`
        FROM `stop_times_gtfs` AS a
            LEFT JOIN `trips_gtfs` t ON (a.`trip_id` = t.`trip_id`)
            LEFT JOIN `rds_indexes` r ON (
                r.`route` = t.`route_id`
                AND r.`stop_id` = a.`stop_id`
                AND r.`direction` = t.`direction_id`
            )
        ORDER BY
            `service_id`,
            r.`rds_index`,
            `arrival_time` ASC
) B;
