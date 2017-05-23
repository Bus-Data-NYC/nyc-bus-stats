/*
    Requires all of the tables in create.sql.
*/
-- Set to the first day of the month in question
SELECT
    start_date,
    end_date
FROM start_date INTO @start_date, @end_date;

DROP TABLE IF EXISTS bunching_raw;
CREATE TEMPORARY TABLE bunching_raw AS
    SELECT
        o.`rds_index`,
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
          AND DATE(o.`datetime`) = DATE(g.`datetime`)
        )
        LEFT JOIN ref_holidays h ON (h.date = DATE(o.`datetime`))
    WHERE
        -- restrict to year-month in question
        o.`year` = YEAR(@start_date)
        AND o.`month` = MONTH(@start_date);

-- join calls to hw_observed and hw_gtfs and compare
-- 10-20 minutes
INSERT INTO bunching
    (month, route_id, direction_id, stop_id, period, weekend, call_count, bunch_count)
SELECT
    @start_date month,
    `route_id`,
    `direction_id`,
    `stop_id`,
    `period`,
    `weekend`,
    COUNT(*) call_count,
    COUNT(IF(headway_observed < headway_scheduled * 0.25, 1, NULL)) bunch_count
FROM bunching_raw
    LEFT JOIN ref_rds USING (rds_index)
GROUP BY `rds_index`, `weekend`, `period`;
