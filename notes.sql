-- Number of distinct rds_index (route-direction-stop) (calls_2015-10): 25262

/*
    General strategy:
        1) Create a table with headway of each scheduled trip in GTFS (`headways_gtfs`).
        2) Create a tracking index for each observed call in `calls`. This index
            counts up for each call at a given stop by a given route in a given service.
        3) Join each call to the previous call to get observed headway (slow!)
        4) Join calls to `headways_gtfs` using trip_index, calculate headway difference. 
    */

-- join schedule to schedule to get scheduled headways (minutes)
DROP TABLE IF EXISTS `headways_gtfs`;
CREATE TABLE `headways_gtfs` (
  `trip_index` int(11) NOT NULL PRIMARY KEY,
  `stop_id` INTEGER NOT NULL,
  `headway` MEDIUMINT UNSIGNED DEFAULT NULL,
  KEY stop (stop_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

SET @month_start = '2015-10-01';
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
        @month_start BETWEEN cg.`start_date` AND cg.`end_date`
        OR DATE_ADD(@month_start, INTERVAL 1 MONTH) BETWEEN cg.`start_date` AND cg.`end_date`
    )
GROUP BY a.`trip_id`, r.`rds_index`;

--- Count up calls at stops, grouped by rds_index
SET @stop = 0, @rds = NULL, @service = NULL;

DROP TABLE IF EXISTS `call_increments`;
CREATE TABLE call_increments (
    call_id INTEGER NOT NULL PRIMARY KEY,
    stop_increment SMALLINT NOT NULL
);

SET @stop = 0, @rds = NULL;
INSERT INTO call_increments (`call_id`, `stop_increment`)
SELECT `call_id`, `stop` FROM (
    SELECT
        `call_id`,
        @stop := IF(@rds = `rds_index`, @stop + 1, 1) AS stop,
        @rds := `rds_index`
    FROM (
        SELECT
            `call_id`,
            `rds_index`
        FROM `calls` 
            LEFT JOIN `trip_indexes` USING (`trip_index`)
        WHERE dwell_time > 0
        ORDER BY
            `rds_index`,
            IF(`dwell_time` > 0, TIMESTAMPADD(SECOND, `dwell_time`, `call_time`), `call_time`) ASC
    ) AS sorted
) AS indexed;

-- join calls to calls to get observed headway
-- not necessary, retained here for demonstration
/*
DROP TABLE IF EXISTS call_headways;
CREATE TABLE call_headways (
    call_id INTEGER NOT NULL PRIMARY KEY,
    headway MEDIUMINT UNSIGNED NOT NULL
);

INSERT INTO call_headways (call_id, headway)
SELECT
    a.`call_id`,
    (TIME_TO_SEC(TIMEDIFF(b.`call_time`, a.`call_time`)) - IF(a.`dwell_time` > 0, a.`dwell_time`, 0)) AS headway
FROM
    calls a
    LEFT JOIN call_increments c1 ON (c1.`call_id`=a.`call_id`)
    JOIN calls b ON (a.`rds_index`=b.`rds_index`)
    LEFT JOIN call_increments c2 ON (c2.`call_id`=b.`call_id`)
WHERE
    c1.`stop_increment` - 1  = c2.`stop_increment`
    AND b.`call_time` > a.`call_time`;
*/

DROP FUNCTION IF EXISTS day_period;
CREATE FUNCTION day_period (d DATETIME)
    RETURNS INTEGER DETERMINISTIC
    RETURN CASE
        WHEN HOUR(d) BETWEEN 0 AND 6 THEN 5
        WHEN HOUR(d) BETWEEN 7 AND 9 THEN 1
        WHEN HOUR(d) BETWEEN 10 AND 15 THEN 2
        WHEN HOUR(d) BETWEEN 16 AND 18 THEN 3
        WHEN HOUR(d) BETWEEN 19 AND 22 THEN 4
        WHEN HOUR(d) BETWEEN 23 AND 24 THEN 5
    END;

-- join calls to itself and headways_gtfs to compare scheduled
-- and observed headways
SELECT
    r.`route`,
    r.`direction`,
    r.`stop_id`,
    (TIME_TO_SEC(TIMEDIFF(c1.`call_time`, c2.`call_time`)) - IF(c2.`dwell_time` > 0, c2.`dwell_time`, 0)) AS observed_headway,
    h.`headway` scheduled_headway,
    WEEKDAY(c1.`call_time`) >= 5 weekend,
    day_period(c1.`call_time`) period,
    COUNT(c1.*) call_count,
    COUNT(
        IF(observed.`headway` < h.`headway` * 0.25, 1, NULL)
    ) bunch_count
FROM
    calls c1
    LEFT JOIN call_increments n1 ON (n1.`call_id`=c1.`call_id`)
    LEFT JOIN calls c2 ON (c2.`rds_index`=c1.`rds_index`)
    LEFT JOIN call_increments n2 ON (n2.`call_id`=c2.`call_id`)
    LEFT JOIN headways_gtfs h ON (h.`trip_index` = c1.`trip_index`)
    LEFT JOIN rds_indexes r ON (r.`rds_index` = c1.`rds_index`)
WHERE
    -- currently only looking at call time
    day_period(c1.`call_time`) = 2
    -- compare successive stops
    AND n1.`stop_increment` - 1  = n2.`stop_increment`
    -- first stop doesn't have a headway
    AND n1.`stop_increment` > 1
GROUP BY
    -- route, direction, stop, weekend/weekend and day period
    r.`rds_index`,
    WEEKDAY(c1.`call_time`) >= 5,
    day_period(c1.`call_time`)

