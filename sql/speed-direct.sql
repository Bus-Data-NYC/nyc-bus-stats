INSERT INTO stat.speed_direct (month, route_id, direction_id, stop_id, weekend, period, distance, travel_time, count)
SELECT
  :'month',
  route_id,
  direction_id,
  stop_id,
  weekend AS weekend,
  period,
  SUM(dist)::int distance,
  SUM(elapsed)::int travel_time,
  COUNT(*)::int count
FROM (
  SELECT
    route_id,
    direction_id,
    stop_id,
    (EXTRACT(isodow FROM trip_start_date) > 5)::int AS weekend,
    day_period(timestamp) period,
    ST_Distance(ST_MakePoint(longitude, latitude)::geography, lag(ST_MakePoint(longitude, latitude)::geography) over (run)) dist,
    EXTRACT(epoch FROM timestamp - lag(timestamp) OVER (run)) as elapsed
  FROM rt.vehicle_positions
    LEFT JOIN stat.stop_direction USING (route_id, stop_id)
  WHERE trip_start_date >= '2021-10-01'::date AND trip_start_date < '2021-11-01'::date
  WINDOW run AS (PARTITION BY trip_start_date, vehicle_id, trip_id ORDER BY timestamp)
) raw
WHERE elapsed > 0 AND dist > 0
GROUP BY
  route_id,
  direction_id,
  stop_id,
  weekend,
  period;
