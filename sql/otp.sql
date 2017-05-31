INSERT perf_otp SELECT
    date_trunc('month', service_date)::date AS month,
    route_id,
    direction_id,
    stop_id,
    (EXTRACT(isodow FROM ****) >= 6 OR h.holiday IS NOT NULL) AS weekend,
    day_period(***:time) AS period,
    COALESCE(SUM(early), 0) early,
    COALESCE(SUM(on_time), 0) on_time,
    COALESCE(SUM(late), 0) late

    SUM(IF(deviation < -60, 1, 0)) AS early,
    SUM(IF(deviation >= -60 AND deviation <= 300, 1, 0)) AS on_time,
    SUM(IF(deviation > 300, 1, 0)) AS late,
FROM calls
    LEFT JOIN ref_holidays h ON (service_date = date)
WHERE
    (call_time + deviation)::date BETWEEN $1 AND $2
GROUP BY
    date_trunc('month', service_date)::date,
    route_id,
    direction_id,
    stop_id,
    weekend,
    period;
