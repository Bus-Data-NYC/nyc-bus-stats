SELECT
  start_date, end_date
FROM start_date INTO @start_date, @end_date;

-- 2.6 million rows in 12m on xl
INSERT perf_service
    SELECT
        @start_date AS month,
        route_id,
        direction_id,
        stop_id,
        WEEKDAY(sh.`date`) >= 5 OR h.`holiday` IS NOT NULL AS weekend,
        day_period_hour(hour) AS period,
        SUM(1),
        SUM(sh.pickups),
        COALESCE(SUM(a.observed), 0)
    FROM schedule_hours AS sh
        LEFT JOIN adherence AS a USING (date, rds_index, hour)
        LEFT JOIN ref_holidays h USING (date)
        JOIN ref_rds USING (rds_index)
    WHERE sh.date BETWEEN @start_date AND @end_date
        AND sh.pickups > 0
        AND NOT exception
    GROUP BY rds_index,
        weekend,
        period;
