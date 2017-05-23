SELECT
  start_date, end_date
FROM start_date INTO @start_date, @end_date;

-- 7m on xl for 2.1 million rows
INSERT perf_otp SELECT
    @start_date AS month,
    route_id,
    direction_id,
    stop_id,
    (WEEKDAY(`date`) >= 5 OR h.`holiday` IS NOT NULL) AS weekend,
    day_period_hour(hour) AS period,
    COALESCE(SUM(early), 0) early,
    COALESCE(SUM(on_time), 0) on_time,
    COALESCE(SUM(late), 0) late
FROM schedule_hours AS sh
    LEFT JOIN adherence AS a USING (date, rds_index, hour)
    LEFT JOIN ref_holidays h USING (date)
    JOIN ref_rds USING (rds_index)
WHERE date BETWEEN @start_date AND @end_date
    -- AND NOT exception
    AND sh.`pickups` BETWEEN 1 AND 4
GROUP BY
    rds_index,
    weekend,
    period;
