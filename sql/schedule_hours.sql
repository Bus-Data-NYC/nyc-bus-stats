SELECT
    start_date,
    end_date
FROM start_date INTO @start_date, @end_date;

DROP TABLE IF EXISTS sh_tmp;
CREATE TEMPORARY TABLE sh_tmp (
    `date` date,
    `rds_index` integer,
    `hour` smallint,
    pickup_type tinyint
);

INSERT INTO sh_tmp SELECT
    dt.date,
    rds_index,
    HOUR(departure_time) hour,
    pickup_type
FROM ref_date_trips dt
    LEFT JOIN ref_stop_times st USING (trip_index)
WHERE
    dt.date BETWEEN @start_date AND @end_date
    AND (
        pickup_type != 1
        OR drop_off_type != 1
    );

INSERT IGNORE schedule_hours (date, rds_index, hour, scheduled, pickups)
SELECT date,
    rds_index,
    hour,
    COUNT(*) scheduled,
    COUNT(pickup_type != 1) AS pickups
FROM sh_tmp AS x
    -- unclear where/what exceptions table is supposed to be
    -- JOIN exceptions e USING (date, hour)
WHERE hour < 24
GROUP BY date,
    rds_index,
    hour;

-- update diff from schedule
UPDATE
    calls c,
    ref_stop_times st
    SET deviation = IF(
        TIME_TO_SEC(
            @d := SUBTIME(TIME(convert_tz(call_time, 'EST', 'America/New_York')), IF(pickup_type = 1, arrival_time, departure_time))
        ) > @twelve_hours,
        TIME_TO_SEC(SUBTIME(@d, '24:00:00')),
        IF(
            TIME_TO_SEC(@d) < -@twelve_hours,
            TIME_TO_SEC(ADDTIME(@d, '24:00:00')),
            TIME_TO_SEC(@d)
        )
    )
    WHERE
        deviation = 555
        AND convert_tz(call_time, 'EST', 'America/New_York') BETWEEN @start_date AND @end_date
        AND st.trip_index = c.trip_index
        AND st.stop_sequence = c.stop_sequence;

SET @sched_time = NULL;
INSERT IGNORE adherence SELECT
    DATE(@sched_time:=DATE_SUB(call_time, INTERVAL deviation SECOND)) AS sched_date,
    rds_index, HOUR(@sched_time) AS sched_hour,
    SUM(1) AS observed,
    SUM(IF(deviation < -300 AND source='C', 1, 0)) AS early_5,
    SUM(IF(deviation < -150 AND source='C', 1, 0)) AS early_2,
    SUM(IF(deviation < -60 AND source='C', 1, 0)) AS early,
    SUM(IF(deviation >= -60 AND deviation <= 300 AND source='C', 1, 0)) AS on_time,
    SUM(IF(deviation > 300 AND source='C', 1, 0)) AS late,
    SUM(IF(deviation > 600 AND source='C', 1, 0)) AS late_10,
    SUM(IF(deviation > 900 AND source='C', 1, 0)) AS late_15,
    SUM(IF(deviation > 1200 AND source='C', 1, 0)) AS late_20,
    SUM(IF(deviation > 1800 AND source='C', 1, 0)) AS late_30
FROM calls
WHERE call_time BETWEEN DATE_SUB(CAST(@start_date AS DATETIME), INTERVAL 2 HOUR) AND DATE_ADD(CAST(@end_date AS DATETIME), INTERVAL 2 HOUR)
GROUP BY sched_date, sched_hour, rds_index
HAVING sched_date BETWEEN @start_date AND @end_date;

