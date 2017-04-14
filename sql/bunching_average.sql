SELECT
    start_date,
    end_date
FROM start_date INTO @start_date, @end_date;

-- join observed headways to average headways
INSERT INTO bunching_averaged
    (month, route, direction, stop_id, period, weekend, call_count, bunch_count)
SELECT
    @start_date month,
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
        (WEEKDAY(o.`datetime`) >= 5 OR h.`holiday` IS NOT NULL) AS weekend,
        day_period(TIME(c.`call_time`)) AS period
    FROM
        calls c
        LEFT JOIN hw_observed o ON (o.`call_id` = c.`call_id`)
        LEFT JOIN schedule s ON (
            s.`rds_index` = c.`rds_index`
            AND s.`date` = DATE(c.`call_time`)
            AND s.`hour` = HOUR(c.`call_time`)
        )
        LEFT JOIN ref_rds r ON (r.`rds_index` = c.`rds_index`)
        LEFT JOIN holidays h USING (date)
    WHERE
        -- restrict to year-month in question
        EXTRACT(YEAR_MONTH, o.`datetime`) = EXTRACT(YEAR_MONTH, @start_date)
) a
-- group by route, direction, stop, weekend/weekend and day period
GROUP BY `rds_index`, `weekend`, `period`;
