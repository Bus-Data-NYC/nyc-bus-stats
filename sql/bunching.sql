/*
    Requires all of the tables in create.sql.
*/
-- Set to the first day of the month in question
SET @the_month = '2015-10-01';

-- currently only looking at call times in period=2
SET @the_period = 2;

-- find observed headways
DROP TABLE IF EXISTS hw_observed;
CREATE TABLE hw_observed (
    call_id INTEGER NOT NULL PRIMARY KEY,
    headway SMALLINT UNSIGNED NOT NULL
);

SET @prev_rds = NULL,
    @prev_depart = NULL;

-- 5 min
INSERT hw_observed
SELECT call_id, headway FROM (
    SELECT
        call_id,
        @headway := IF(rds_index=@prev_rds, TIME_TO_SEC(TIMEDIFF(call_time, @prev_depart)), NULL) AS headway,
        @prev_rds := rds_index,
        @prev_depart := IF(`dwell_time` > 0, TIMESTAMPADD(SECOND, `dwell_time`, `call_time`), `call_time`)
    FROM calls
    WHERE
        DATE(call_time) BETWEEN @start_date AND DATE_ADD(@the_month, INTERVAL 1 MONTH)
    ORDER BY
        rds_index,
        IF(`dwell_time` > 0, TIMESTAMPADD(SECOND, `dwell_time`, `call_time`), `call_time`)
) observed;

-- find scheduled headways
-- join schedule to schedule to get scheduled headways (minutes)
-- 6 min
DROP TABLE IF EXISTS `hw_gtfs`;
CREATE TABLE hw_gtfs (
  `trip_index` int(11) NOT NULL,
  `rds_index` INTEGER NOT NULL,
  `date` date NOT NULL,
  `headway` MEDIUMINT UNSIGNED DEFAULT NULL,
  KEY k (trip_index, rds_index, date)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

INSERT INTO hw_gtfs (trip_index, rds_index, date, headway)
SELECT trip_index, rds_index, DATE(call_time) date, headway FROM (
    SELECT
        trip_index,
        @headway := IF(rds_index=@prev_rds, TIME_TO_SEC(TIMEDIFF(call_time, @prev_time)), NULL) headway,
        @prev_rds := rds_index AS rds_index,
        @prev_time := call_time
    FROM (
        SELECT
            rds_index,
            trip_index,
            ADDTIME(dt.`date`, st.`time`) call_time
        FROM
            date_trips dt
            LEFT JOIN stop_times st USING (trip_index)
        WHERE
            dt.`date` BETWEEN @the_month AND DATE_ADD(@the_month, INTERVAL 1 MONTH)
            AND pickup_type != 1
    ) a
    ORDER BY rds_index, call_time
) b;

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

DROP TABLE IF EXISTS bunching;
CREATE TABLE bunching (
  `route` varchar(5),
  `direction` char(1),
  `stop_id` int(11),
  `period` int(1) NOT NULL,
  `weekend` int(1) NOT NULL,
  `call_count` SMALLINT(21) NOT NULL,
  `bunch_count` SMALLINT(21) NOT NULL,
  KEY rds (route, direction, stop_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- join calls to hw_observed and hw_gtfs and compare
-- 12 minutes
INSERT INTO bunching
    (route, direction, stop_id, period, weekend, call_count, bunch_count)
SELECT
    `route`,
    `direction`,
    `stop_id`,
    `period`,
    `weekend`,
    COUNT(*) call_count,
    COUNT(IF(headway_observed < headway_scheduled * 0.25, 1, NULL)) bunch_count
FROM (
    SELECT
        c.`rds_index`,
        r.`route`,
        r.`direction`,
        r.`stop_id`,
        c.`call_time`,
        o.`headway` headway_observed,
        g.`headway` headway_scheduled,
        WEEKDAY(c.`call_time`) >= 5 AS weekend,
        day_period(c.`call_time`) period
    FROM
        calls c
        LEFT JOIN hw_observed o ON (c.`call_id` = o.`call_id`)
        LEFT JOIN hw_gtfs g ON (g.`trip_index` = c.`trip_index` AND g.`rds_index` = c.`rds_index` AND DATE(c.`call_time`) = g.`date`)
        LEFT JOIN rds_indexes r ON (r.`rds_index` = c.`rds_index`)
    WHERE
        -- restrict to year-month in question
        YEAR(c.`call_time`) = YEAR(@the_month)
        AND MONTH(c.`call_time`) = MONTH(@the_month)
        -- currently only looking at call times in period=2
        AND day_period(c.`call_time`) = @the_period
) a
-- group by route, direction, stop, weekend/weekend and day period
GROUP BY `rds_index`, `weekend`, `period`;
