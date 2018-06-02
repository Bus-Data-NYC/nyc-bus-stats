-- evt
-- Excess in-vehicle time aka excess trip length
-- Calculated across the duration of trips

CREATE OR REPLACE FUNCTION get_evt (start DATE, term INTERVAL)
    RETURNS TABLE(
        route_id text,
        direction_id int,
        weekend int,
        period integer,
        duration_avg_sched numeric,
        duration_avg_obs numeric,
        count_trips integer,
        count_late integer
    ) AS $$
    SELECT
        route_id,
        direction_id,
        weekend::int as weekend,
        period,
        AVG(EXTRACT(EPOCH FROM sched.duration)::NUMERIC/60.)::NUMERIC(10, 2) duration_avg_sched,
        AVG(EXTRACT(EPOCH FROM obs.duration)::NUMERIC/60.)::NUMERIC(10, 2) duration_avg_obs,
        COUNT(*)::int count_trips,
        COUNT(NULLIF(false, obs.duration > sched.duration))::int count_late
    FROM (
        SELECT
            feed_index,
            x.date,
            trip_id,
            weekend::int weekend,
            period,
            COUNT(*) AS stops,
            MAX(arrival_time) - MIN(arrival_time) AS duration
        FROM (
            SELECT
                feed_index,
                d.date,
                trip_id,
                EXTRACT(isodow FROM d.date) > 5 OR holiday IS NOT NULL as weekend,
                day_period(wall_time(d.date, arrival_time, agency_timezone)) period,
                arrival_time
            FROM
                get_date_trips("start", ("start" + "term")::date) as d
                LEFT JOIN gtfs.trips USING (feed_index, trip_id)
                LEFT JOIN gtfs.stop_times USING (feed_index, trip_id)
                LEFT JOIN stat_holidays USING ("date")
                LEFT JOIN gtfs.agency USING (feed_index)
            ) x
        GROUP BY
            feed_index,
            x.date,
            trip_id,
            weekend,
            period
    ) sched
        LEFT JOIN (
            SELECT
                c.date,
                trip_id,
                COUNT(*) calls,
                MAX(call_time) - MIN(call_time) AS duration
            FROM calls c
            WHERE c.date >= start::DATE
                AND c.date < "start" + "term"
            GROUP BY c.date,
                trip_id
        ) obs USING (date, trip_id)
        LEFT JOIN gtfs.trips USING (feed_index, trip_id)
    WHERE obs.calls = sched.stops
    GROUP BY
        route_id,
        direction_id,
        weekend,
        period
    $$
LANGUAGE SQL STABLE;
