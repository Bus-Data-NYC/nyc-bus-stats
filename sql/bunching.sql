/*
    Requires all of the tables in create.sql.
*/
-- Set to the first day of the month in question
-- This is done in the Makefile. Uncomment if using the file directly.
-- SET @the_month = '2015-10-01';

-- find observed headways
DROP TABLE IF EXISTS hw_observed;
CREATE TABLE hw_observed (
    call_id INTEGER NOT NULL PRIMARY KEY,
    headway SMALLINT UNSIGNED NOT NULL
);

SET @prev_rds = NULL;

-- sort calls by route/direction/stop and departure time.
-- Use variables to calculate headway between successive fields
-- 5 min
INSERT hw_observed
SELECT call_id, headway FROM (
    SELECT
        call_id,
        @headway := IF(`rds_index`=@prev_rds, TIME_TO_SEC(TIMEDIFF(depart_time(call_time, dwell_time), @prev_depart)), NULL) AS headway,
        @prev_rds := rds_index,
        @prev_depart := depart_time(call_time, dwell_time)
    FROM (
        SELECT * FROM calls
        WHERE DATE(call_time) BETWEEN @the_month AND DATE_ADD(@the_month, INTERVAL 1 MONTH)
        ORDER BY
            rds_index,
            depart_time(call_time, dwell_time) ASC
    ) a
) b;

/* 
 * find scheduled headways
 * Same general strategy as observed headways, except here the date of the scheduled call
 * comes from the `date_trips` table.
*/
-- 6 min
DROP TABLE IF EXISTS `hw_gtfs`;
CREATE TABLE hw_gtfs (
  `trip_index` int(11) NOT NULL,
  `rds_index` INTEGER NOT NULL,
  `date` date NOT NULL,
  `headway` MEDIUMINT UNSIGNED DEFAULT NULL,
  KEY k (trip_index, rds_index, date)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

SET @prev_rds = NULL;

INSERT INTO hw_gtfs (trip_index, rds_index, date, headway)
SELECT trip_index, rds_index, DATE(call_time) date, headway FROM (
    SELECT
        trip_index,
        @headway := IF(rds_index=@prev_rds, TIME_TO_SEC(TIMEDIFF(call_time, @prev_time)), NULL) headway,
        @prev_rds := rds_index AS rds_index,
        @prev_time := call_time AS call_time
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
        ORDER BY
            rds_index,
            call_time
    ) a
) b;

-- bunching table
CREATE TABLE IF NOT EXISTS bunching (
  `month` date NOT NULL,
  `route_id` varchar(5),
  `direction_id` char(1),
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
    (month, route_id, direction_id, stop_id, period, weekend, call_count, bunch_count)
SELECT
    @the_month month,
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
        WEEKDAY(c.`call_time`) >= 5 OR 
            DATE(c.`call_time`) IN ('2015-12-24', '2015-12-25', '2016-01-01', '2016-02-15', '2016-05-30') AS weekend,
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
) a
-- group by route, direction, stop, weekend/weekend and day period
GROUP BY `rds_index`, `weekend`, `period`;
