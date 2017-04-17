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
    d AS month,
    r.route_id,
    r.direction_id,
    r.stop_id,
    day_period_hour(hour) period,
    SUM(dist) distance,
    SUM(dur) AS travel_time
FROM (
    SELECT
        DATE(@prev_time) AS d,
        (WEEKDAY(@prev_time) >= 5 OR h.`holiday` IS NOT NULL) AS weekend,
        -- For stop S0,
        @prev_rds AS rds,
        HOUR(@prev_time) AS hour,
        -- IF(c.trip_index=@prev_trip,IF(stop_sequence=@prev_seq+1,round(shape_dist_traveled-@prev_dist,2),-1),-1) AS dist,
        -- Allowing distances between non-sequential stops since calls where no pickup or dropoff are not being captured yet.
        -- Really only want measures from stops with a pickup to next pickup (or terminal) if we want to match rds with other metrics...
        -- However, still want to know time to some dropoff only before terminal (e.g., express work bus)
        IF(vehicle_id=@prev_vehicle AND c.trip_index=@prev_trip AND stop_sequence>@prev_seq, round(shape_dist_traveled - @prev_dist, 2), -1) AS dist,
        -- measure time between departure from S0 and departure from S1
        TIMESTAMPDIFF(SECOND, @prev_time, call_time) AS dur,
        -- TIME_TO_SEC(TIMEDIFF(call_time, @prev_time)) AS dur,
        -- until calls inferrer fixed, record S0 dwell time of zero
        0 AS dwell,
        @prev_time:=call_time,
        @prev_vehicle:=vehicle_id,
        @prev_rds:=c.rds_index,
        @prev_dist:=shape_dist_traveled,
        @prev_trip:=c.trip_index,
        @prev_seq:=stop_sequence
    FROM calls c
        JOIN ref_trips t ON c.trip_index=t.trip_index
        JOIN ref_rds ON c.rds_index=ref_rds.rds_index
        JOIN ref_stop_distances sd ON (t.feed_index=sd.feed_index AND t.shape_id=sd.shape_id AND ref_rds.stop_id=sd.stop_id)
        LEFT JOIN ref_holidays h ON (h.date = DATE(c.call_time))
    WHERE
        call_time BETWEEN DATE_SUB(CAST(@start_date AS DATETIME), INTERVAL 1 HOUR) AND DATE_ADD(CAST(@end_date AS DATETIME), INTERVAL 26 HOUR)
    ORDER BY
        vehicle_id,
        call_time
) AS x -- TODO what is appropriate duration cutoff?
LEFT JOIN ref_rds r ON (r.rds_index = x.rds)
WHERE dist >= 0
GROUP BY
    d, rds, h
HAVING
    d BETWEEN @start_date AND @end_date;
