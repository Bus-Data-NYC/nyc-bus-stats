CREATE OR REPLACE FUNCTION get_trip_updates("start" DATE, term INTERVAL)
    RETURNS TABLE(
        date date,
        route_id text,
        direction_id int,
        weekend int,
        period int,
        signalled int
    ) AS $$
    SELECT
      tu.trip_start_date date,
      tu.route_id route_id,
      trips.direction_id direction_id,
      (EXTRACT(isodow FROM trip_start_date) > 5 OR h.date IS NOT NULL)::int weekend,
      day_period(EXTRACT(hours FROM st.arrival_time)::int) period,
      count(*)::int signalled
    FROM rt.trip_updates tu
      JOIN gtfs.trips USING (trip_id, route_id)
      JOIN gtfs.stop_times st ON (st.feed_index, st.trip_id, st.stop_sequence) = (trips.feed_index, trips.trip_id, 1)
      LEFT JOIN stat.holidays h ON (h.date = tu.trip_start_date)
    WHERE tu.trip_start_date >= $1 AND tu.trip_start_date < ($1 + $2)
    GROUP BY 1, 2, 3, 4, 5;
    $$
LANGUAGE SQL STABLE;