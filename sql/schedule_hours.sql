SELECT
    date,
    hour,
    route_id,
    direction_id,
    stop_id,
    COUNT(*) scheduled,
    COUNT(NULLIF(false, pickup_type != 1 OR drop_off_type != 1)) AS pickups
FROM (
    SELECT
        wall_time(date, arrival_time)::date date,
        extract(hour from wall_time(date, arrival_time)) AS hour,
        *
    FROM
        get_date_trips($1, $2)
        LEFT JOIN gtfs.stop_times USING (feed_index, trip_index)
) a
GROUP BY
    date,
    hour,
    route_id,
    direction_id,
    stop_id;
