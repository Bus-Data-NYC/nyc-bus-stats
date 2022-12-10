INSERT INTO stat.position_trip_count (date, route_id, direction_id, trips)
SELECT
    trip_start_date,
    a.route_id,
    direction_id,
    count(distinct trip_id)
FROM rt.vehicle_positions AS a
    LEFT JOIN gtfs.trips AS b USING (trip_id)
GROUP BY 1, 2, 3;