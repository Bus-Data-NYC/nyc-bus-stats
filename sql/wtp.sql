SELECT
  start_date, end_date
FROM start_date INTO @start_date, @end_date;

INSERT perf_wtp
    SELECT
        @start_date AS month,
        route_id,
        direction_id,
        stop_id,
        (WEEKDAY(`date`) >= 5 OR h.`holiday` IS NOT NULL) AS weekend,
        day_period_hour(hour) AS period,
        SUM(1),
        SUM(COALESCE(wait_5, 3600)),
        SUM(COALESCE(wait_10, 3600)),
        SUM(COALESCE(wait_15, 3600)),
        SUM(COALESCE(wait_20, 3600)),
        SUM(COALESCE(wait_30, 3600))
    FROM schedule_hours AS sh
        LEFT JOIN wtp USING (date, rds_index, hour)
        LEFT JOIN holidays h USING (date)
        JOIN ref_rds USING (rds_index)
    WHERE
        sh.date BETWEEN @start_date AND @end_date
        AND sh.pickups >= 5
        AND NOT exception
    GROUP BY
        rds_index,
        weekend,
        period;
