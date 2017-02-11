/*
    Requires all of the tables in create.sql.
*/
-- Set to the first day of the month in question
-- This is done in the Makefile. Uncomment if using the file directly.
-- SET @the_month = '2015-10-01';

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
        o.`rds_index`,
        r.`route`,
        r.`direction`,
        r.`stop_id`,
        o.`datetime`,
        o.`headway` headway_observed,
        g.`headway` headway_scheduled,
        WEEKDAY(o.`datetime`) >= 5 OR 
            DATE(o.`datetime`) IN ('2015-12-24', '2015-12-25', '2016-01-01', '2016-02-15', '2016-05-30') AS weekend,
        day_period(o.`datetime`) period
    FROM
        hw_observed o
        LEFT JOIN hw_gtfs g ON (
          g.`trip_index` = o.`trip_index`
          AND g.`rds_index` = o.`rds_index`
          AND DATE(o.`datetime`) = g.`date`
        )
        LEFT JOIN rds_indexes r ON (r.`rds_index` = o.`rds_index`)
    WHERE
        -- restrict to year-month in question
        YEAR(o.`datetime`) = YEAR(@the_month)
        AND MONTH(o.`datetime`) = MONTH(@the_month)
) a
-- group by route, direction, stop, weekend/weekend and day period
GROUP BY `rds_index`, `weekend`, `period`;
