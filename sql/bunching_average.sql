-- Set to the first day of the month in question
SET @the_month = '2015-10-01';

-- currently only looking at call times in period=2
SET @the_period = 2;

-- alternative approach: use the average headway to calculate bunching

CREATE TABLE IF NOT EXISTS bunching_averaged (
  `month` date NOT NULL,
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
    (month, route, direction, stop_id, period, weekend, call_count, bunch_count)
SELECT
    @the_month month,
    `route`,
    `direction`,
    `stop_id`,
    `period`,
    `weekend`,
    COUNT(*) call_count,
    COUNT(IF(headway_observed < headway_avg * 0.25, 1, NULL)) bunch_count
FROM (
    SELECT
        r.`route`,
        r.`direction`,
        r.`stop_id`,
        c.`call_time`,
        o.`headway` headway_observed,
        3600.0 / s.`pickups` headway_avg,
        WEEKDAY(s.`date`) >= 5 OR 
            DATE(c.`call_time`) IN ('2015-12-24', '2015-12-25', '2016-01-01', '2016-02-15', '2016-05-30') AS weekend,
        day_period(TIME(c.`call_time`)) AS period
    FROM
        calls c
        LEFT JOIN hw_observed o ON (o.`call_id` = c.`call_id`)
        LEFT JOIN schedule s ON (
            s.`rds_index` = c.`rds_index`
            AND s.`date` = DATE(c.`call_time`)
            AND s.`hour` = HOUR(c.`call_time`)
        )
        LEFT JOIN rds_indexes r ON (r.`rds_index` = c.`rds_index`)
    WHERE
        -- restrict to year-month in question
        YEAR(s.`date`) = YEAR(@the_month)
        AND MONTH(s.`date`) = MONTH(@the_month)
        -- currently only looking at call times in period=2
        AND day_period(TIME(c.`call_time`)) = @the_period
) a
-- group by route, direction, stop, weekend/weekend and day period
GROUP BY `rds_index`, `weekend`, `period`;
