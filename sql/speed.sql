SELECT
    start_date,
    end_date
FROM start_date INTO @start_date, @end_date;
SET @prev_time = NULL, @prev_rds = NULL;

DROP TABLE IF EXISTS perf_speed_raw;
CREATE TEMPORARY TABLE perf_speed_raw AS
    SELECT
        DATE(@prev_time) AS d,
        (WEEKDAY(@prev_time) >= 5 OR h.`holiday` IS NOT NULL) AS weekend,
        -- For stop S0,
        @prev_rds AS rds_index,
        day_period(@prev_time) AS period,
        -- IF(c.trip_index=@prev_trip,IF(stop_sequence=@prev_seq+1,round(shape_dist_traveled-@prev_dist,2),-1),-1) AS dist,
        -- Allowing distances between non-sequential stops since calls where no pickup or dropoff are not being captured yet.
        -- Really only want measures from stops with a pickup to next pickup (or terminal) if we want to match rds with other metrics...
        -- However, still want to know time to some dropoff only before terminal (e.g., express work bus)
        IF(vehicle_id=@prev_vehicle AND c.trip_index=@prev_trip AND stop_sequence>@prev_seq, round(shape_dist_traveled - @prev_dist, 2), -1) AS dist,
        -- measure time between departure from S0 and departure from S1
        TIMESTAMPDIFF(SECOND, @prev_time, call_time) AS dur,
        -- TIME_TO_SEC(TIMEDIFF(call_time, @prev_time)) AS dur,
        -- until calls inferrer fixed, record S0 dwell time of zero
        -- 0 AS dwell,
        @prev_time:=call_time call_time,
        @prev_vehicle:=vehicle_id vehicle_id,
        @prev_rds:=c.rds_index r0,
        @prev_dist:=shape_dist_traveled d0,
        @prev_trip:=c.trip_index trip_index,
        @prev_seq:=stop_sequence s0
    FROM (
        SELECT * FROM calls101
        WHERE
            call_time BETWEEN DATE_SUB(@start_date, INTERVAL 1 HOUR) AND DATE_ADD(@end_date, INTERVAL 25 HOUR)
            ORDER BY
                vehicle_id, call_time
        ) c
        JOIN ref_trips t USING (trip_index)
        JOIN ref_rds USING (rds_index)
        JOIN ref_stop_distances sd USING (feed_index, shape_id, stop_id)
        LEFT JOIN ref_holidays h ON (h.date = DATE(c.call_time))
    WHERE
        call_time BETWEEN DATE_SUB(@start_date, INTERVAL 1 HOUR) AND DATE_ADD(@end_date, INTERVAL 25 HOUR)
    ORDER BY
        vehicle_id,
        call_time;

-- perf_speed schema:
    -- month date NOT NULL,
    -- route_id varchar(255) NOT NULL,
    -- direction_id tinyint(4) NOT NULL,
    -- stop_id int(11) NOT NULL,
    -- weekend tinyint(4) NOT NULL,
    -- period tinyint(4) NOT NULL,
    -- distance int(11) NOT NULL,
    -- travel_time int(11) NOT NULL,

INSERT perf_speed SELECT
    d month,
    route_id,
    direction_id,
    stop_id,
    period,
    weekend,
    SUM(dist) distance,
    SUM(dur) AS travel_time
FROM perf_speed_raw -- TODO what is appropriate duration cutoff?
    LEFT JOIN ref_rds USING (rds_index)
WHERE dist >= 0
GROUP BY
    EXTRACT(YEAR_MONTH FROM d),
    rds_index,
    period,
    weekend
HAVING
    d BETWEEN @start_date AND @end_date;
