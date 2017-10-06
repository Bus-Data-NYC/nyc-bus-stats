-- evt
-- Excess in-vehicle time aka excess trip length
-- Calculated across the duration of trips

CREATE OR REPLACE FUNCTION get_evt (start DATE, term INTERVAL)
    RETURNS TABLE(
        month date,
        route_id text,
        direction_id int,
        weekend int,
        period integer,
        count_trips integer,
        duration_avg_sched numeric,
        duration_avg_obs numeric,
        pct_late decimal
    ) AS $$
    SELECT
        start_date,
        route_id,
        direction_id,
        weekend::int as weekend,
        period,
        COUNT(*) count_trips,
        AVG(EXTRACT(EPOCH FROM sched.duration)::NUMERIC/60.)::NUMERIC(10, 2) duration_avg_sched,
        AVG(EXTRACT(EPOCH FROM obs.duration)::NUMERIC/60.)::NUMERIC(10, 2) duration_avg_obs,
        COUNT(NULLIF(false, obs.duration > sched.duration))::decimal / COUNT(*)::decimal pct_late
    FROM (
        SELECT d.date,
            trip_id,
            route_id,
            COUNT(*) AS stops,
            EXTRACT(isodow FROM d.date) > 5 OR holiday IS NOT NULL weekend,
            day_period(wall_time(d.date, MIN(arrival_time), 'US/Eastern')) period,
            MAX(arrival_time) - MIN(arrival_time) AS duration
        FROM get_date_trips("start", ("start" + "term")::date) d
            LEFT JOIN gtfs_trips USING (feed_index, trip_id)
            LEFT JOIN gtfs_stop_times USING (feed_index, trip_id)
            LEFT JOIN stat_holidays USING ("date")
        GROUP BY d.date, trip_id
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
        WHERE obs.calls = sched.stops
        GROUP BY
            route_id,
            direction_id,
            weekend,
            period
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_evt (start_date DATE)
    RETURNS TABLE(
        month date,
        route_id text,
        direction_id int,
        weekend int,
        period integer,
        count_trips integer,
        duration_avg_sched numeric,
        duration_avg_obs numeric,
        pct_late decimal
    ) AS $$
        SELECT * FROM get_evt(start_date, INTERVAL '1 MONTH')
    $$
LANGUAGE SQL STABLE;
