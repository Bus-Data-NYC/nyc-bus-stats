/*
    Requires all of the tables in create.sql.
*/
-- Set to the first day of the month in question
SET @the_month = '2015-10-01';

-- currently only looking at call times in period=2
SET @the_period = 2;

--- Count up calls at stops, grouped by rds_index
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

-- All day is divided into five parts.
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

DROP TABLE IF EXISTS bunching_averaged;
CREATE TABLE bunching_averaged (
  `route` varchar(5),
  `direction` char(1),
  `stop_id` int(11),
  `period` int(1) NOT NULL,
  `weekend` int(1) NOT NULL,
  `call_count` SMALLINT(21) NOT NULL,
  `bunch_count` SMALLINT(21) NOT NULL,
  KEY rds (route, direction, stop_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- join observed headways to average headways
INSERT INTO bunching_averaged
    (route, direction, stop_id, period, weekend, call_count, bunch_count)
SELECT
    `route`,
    `direction`,
    `stop_id`,
    `period`,
    `weekend`,
    COUNT(*) call_count,
    COUNT(IF(observed_headway < average_scheduled_headway * 0.25, 1, NULL)) bunch_count
FROM (
    SELECT
        c1.`rds_index`,
        r.`route`,
        r.`direction`,
        r.`stop_id`,
        c1.`call_time`,
        TIME_TO_SEC(TIMEDIFF(c1.`call_time`, c2.`call_time`)) - IF(c2.`dwell_time` > 0, c2.`dwell_time`, 0) AS observed_headway,
        3600.0 / s.pickups AS average_scheduled_headway,
        WEEKDAY(c1.`call_time`) >= 5 AS weekend,
        day_period(c1.`call_time`) AS period
    FROM
        calls c1
        LEFT JOIN call_increments n1 ON (n1.`call_id`=c1.`call_id`)
        LEFT JOIN calls c2 ON (c2.`rds_index`=c1.`rds_index`)
        LEFT JOIN call_increments n2 ON (n2.`call_id`=c2.`call_id`)
        LEFT JOIN schedule s ON (
            s.`rds_index` = c1.`rds_index`
            AND s.`date` = DATE(c1.`call_time`)
            AND s.`hour` = HOUR(c1.`call_time`)
        )
        LEFT JOIN rds_indexes r ON (r.`rds_index` = c1.`rds_index`)
    WHERE
        -- restrict to year-month in question
        YEAR(s.`date`) = YEAR(@the_month)
        AND MONTH(s.`date`) = MONTH(@the_month)
        -- currently only looking at call times in period=2
        AND day_period(c1.`call_time`) = @the_period
        -- compare successive stops
        AND n1.`stop_increment` - 1  = n2.`stop_increment`
        -- first stop doesn't have a headway
        AND n1.`stop_increment` > 1
) a
-- group by route, direction, stop, weekend/weekend and day period
GROUP BY `rds_index`, `weekend`, `period`;
