/*
    Requires all of the tables in create.sql.
*/
-- Set to the first day of the month in question
-- This is done in the Makefile. Uncomment if using the file directly.
-- SET @the_month = '2015-10-01';

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
        (WEEKDAY(o.`datetime`) >= 5 OR h.`holiday` IS NOT NULL) AS weekend,
        day_period(TIME(o.`datetime`)) period
    FROM
        hw_observed o
        LEFT JOIN hw_gtfs g ON (
          g.`trip_index` = o.`trip_index`
          AND g.`rds_index` = o.`rds_index`
          AND DATE(o.`datetime`) = g.`date`
        )
        LEFT JOIN rds r ON (r.`rds_index` = o.`rds_index`)
        LEFT JOIN ref_holidays h USING (date)
    WHERE
        -- restrict to year-month in question
        EXTRACT(YEAR_MONTH, o.`datetime`) = EXTRACT(YEAR_MONTH, @start_date)
) a
-- group by route, direction, stop, weekend/weekend and day period
GROUP BY `rds_index`, `weekend`, `period`;
