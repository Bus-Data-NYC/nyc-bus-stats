/* Assumes that stat.date_trips is populated */

INSERT INTO stat.position_trip_list (date, trip_id)
SELECT distinct trip_start_date, trip_id
FROM rt.vehicle_positions
WHERE trip_start_date is not null;

INSERT INTO stat.schedule_observed (date, route_id, direction_id, weekend, period, scheduled)
SELECT
  a.date,
  route_id,
  direction_id,
  (EXTRACT(isodow FROM a.date) > 5 OR h.date IS NOT NULL)::int weekend,
  day_period(EXTRACT(hours FROM st.arrival_time)::int) period,
  count(*)
FROM stat.date_trips a
  JOIN gtfs.trips USING (feed_index, trip_id)
  JOIN gtfs.stop_times st ON (st.feed_index, st.trip_id, st.stop_sequence) = (trips.feed_index, trips.trip_id, 1)
  LEFT JOIN stat.holidays h ON (h.date = a.date)
WHERE a.date BETWEEN '2022-10-01' AND '2022-10-31'
GROUP BY 1, 2, 3, 4, 5;

INSERT INTO stat.schedule_observed (date, route_id, direction_id, weekend, period, observed)
SELECT
  a.date,
  route_id,
  direction_id,
  (EXTRACT(isodow FROM a.date) > 5 OR h.date IS NOT NULL)::int weekend,
  day_period(EXTRACT(hours FROM st.arrival_time)::int) period,
  count(*)
FROM stat.date_trips a
  JOIN stat.position_trip_list USING (date, trip_id)
  JOIN gtfs.trips USING (trip_id)
  JOIN gtfs.stop_times st ON (st.feed_index, st.trip_id, st.stop_sequence) = (trips.feed_index, a.trip_id, 1)
  LEFT JOIN stat.holidays h ON (h.date = a.date)
WHERE a.date BETWEEN '2022-10-01' AND '2022-10-31'
GROUP BY 1, 2, 3, 4, 5
ON CONFLICT (date, route_id, direction_id, weekend, period) DO UPDATE SET observed = EXCLUDED.observed;
