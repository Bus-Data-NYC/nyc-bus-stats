-- evt
-- Excess -invehicle time
-- Calculated acros the duration of trips

DROP TABLE IF EXISTS seq;
CREATE TEMPORARY TABLE seq (
    trip_id text PRIMARY KEY,
    first INTEGER NOT NULL,
    last integer not null
);

INSERT INTO seq
SELECT
    trip_id,
    MIN(stop_sequence) AS first,
    MAX(stop_sequence) AS last
FROM gtfs_trips
    LEFT JOIN gtfs_stop_times USING (feed_index, trip_id)
    LEFT JOIN gtfs_calendar USING (feed_index, service_id)
WHERE
    (start_date, end_date) OVERLAPS ($1, $2)
GROUP BY trip_id;

SELECT
    route_id,
    direction_id,
    day_period(arrival_time) period,
    COUNT(*) count_trips,
    AVG(minutes(s2.arrival_time - s1.arrival_time)) duration_avg_sched,
    AVG(minutes(s2.call_time - s1.call_time)) duration_avg_obs,
    COUNT(NULLIF(false, s2.arrival_time - s1.arrival_time < c2.call_time - c1.call_time)) pct_late
FROM   
    gtfs_trips
    INNER JOIN get_date_trips($1, $2) d USING (feed_index, trip_id)
    LEFT JOIN seq USING (trip_id)
    LEFT JOIN gtfs_stop_times_gtfs s1 USING (feed_index, trip_id)
    LEFT JOIN calls c1 USING (trip_index, route_id, direction_id, stop_id)
    LEFT JOIN gtfs_stop_times_gtfs s2 USING (feed_index, trip_id)
    LEFT JOIN calls c2 USING (trip_id, stop_id, service_date)
WHERE
    s1.stop_sequence = seq.first
    AND s2.stop_sequence = seq.last
    AND service_date = d.date;
GROUP BY
    route_id, 2;
