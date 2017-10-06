BEGIN;

-- All day is divided into five parts.
CREATE OR REPLACE FUNCTION day_period (int)
    RETURNS integer AS $$
    SELECT CASE
        WHEN $1 BETWEEN 0 AND 6 THEN 5
        WHEN $1 BETWEEN 7 AND 9 THEN 1
        WHEN $1 BETWEEN 10 AND 15 THEN 2
        WHEN $1 BETWEEN 16 AND 18 THEN 3
        WHEN $1 BETWEEN 19 AND 22 THEN 4
        WHEN $1 >= 23 THEN 5
    END
    $$
LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION day_period (time)
    RETURNS integer AS $$
    SELECT day_period(EXTRACT(HOUR FROM $1)::integer)
    $$
LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION day_period (timestamp)
    RETURNS integer AS $$
    SELECT day_period(EXTRACT(HOUR FROM $1)::integer)
    $$
LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION day_period (timestamp with time zone)
    RETURNS integer AS $$
    SELECT day_period(EXTRACT(HOUR FROM $1 AT TIME ZONE 'US/Eastern')::integer)
    $$
LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION day_period_length(integer)
    RETURNS integer AS $$
    SELECT CASE
        WHEN $1 = 1 THEN 3 * 60 * 60
        WHEN $1 = 2 THEN 6 * 60 * 60
        WHEN $1 = 3 THEN 3 * 60 * 60
        WHEN $1 = 4 THEN 4 * 60 * 60
        WHEN $1 = 5 THEN 8 * 60 * 60
    END
    $$
LANGUAGE SQL IMMUTABLE;

-- generate the timestampz for a gtfs schedule date and time
CREATE OR REPLACE FUNCTION wall_time(d date, t interval, zone text)
    RETURNS timestamp AS $$
        SELECT (
            ("d" + time '12:00')::timestamp without time zone at time zone "zone" - interval '12 HOURS' + "t"
        ) at time zone "zone"
    $$
LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION date_range(start date, length integer)
    RETURNS TABLE("date" date) AS $$
        SELECT "start" + i - 1 as date
        FROM GENERATE_SERIES(1, length) AS a (i)
    $$
LANGUAGE SQL IMMUTABLE;

-- return dates->trip_id lookup rows for dates in range
-- 8s, 2.5m rows for one month
-- Assumes trip-ids not repeated in different feeds
-- "start" is an inclusive lower bound, "finish" is exclusive.
-- So: get_date_trips('2016-01-01', '2016-02-01') will get all trips in January.
CREATE OR REPLACE FUNCTION get_date_trips(start date, finish date)
    RETURNS TABLE(feed_index integer, "date" date, trip_id text)
    AS $$
        SELECT MAX(feed_index) feed_index,
            a.date,
            trip_id
        FROM (
            SELECT feed_index, range.date, trip_id
            FROM date_range("start", "finish" - "start") range
                LEFT JOIN gtfs_calendar c ON (
                    -- address the weekday columns of gtfs_calendar as an array, using the day-of-week as an index
                    (ARRAY[monday, tuesday, wednesday, thursday, friday, saturday, sunday])[extract(isodow from range.date)] = '1'
                    AND range.date BETWEEN c.start_date AND c.end_date
                )
                LEFT JOIN gtfs_calendar_dates USING (feed_index, date, service_id)
                LEFT JOIN gtfs_trips USING (feed_index, service_id)
            WHERE exception_type IS NULL
                AND trip_id IS NOT NULL
            UNION
            SELECT feed_index, date, trip_id
            FROM gtfs_trips
                LEFT JOIN gtfs_calendar_dates USING (feed_index, service_id)
            WHERE exception_type = 1
                AND date >= "start"
                AND date < "finish"
        ) a
        GROUP BY date, trip_id
    $$
LANGUAGE SQL STABLE;

/* 
 * find scheduled headways
 * Same general strategy as observed headways, except here the date of the scheduled call
 * comes from the `date_trips` table.
 * 5-10 minutes for a month
*/
CREATE OR REPLACE FUNCTION get_headway_scheduled(start date, term interval)
    RETURNS TABLE (
        feed_index int,
        trip_id text,
        stop_id text,
        "date" date,
        period int,
        headway interval
    ) AS $$
    SELECT *
    FROM (
        SELECT
            feed_index,
            trip_id,
            stop_id,
            wall_time(d.date, arrival_time, agency_timezone)::date AS date,
            day_period(EXTRACT(hours from arrival_time)::int) AS period,
            /*
             There exist duplicate dummy trips: two trips with same stoptime pattern.
             One of the trips is a ghost, one is real. We don't know which one, so when
             that happens, we give each the same headway by LAG-ing back one more step in the WINDOW.
             */
            CASE WHEN arrival_time != lag(arrival_time) over (rds)
                THEN wall_time(d.date, arrival_time, agency_timezone) - wall_time(lag(d.date) over (rds), lag(arrival_time) over (rds), agency_timezone)
                ELSE wall_time(d.date, arrival_time, agency_timezone) - wall_time(lag(d.date, 2) over (rds), lag(arrival_time, 2) over (rds), agency_timezone)
            END AS headway
        FROM  -- list of dates beginning just before our interval
            get_date_trips(("start" - INTERVAL '1 day')::DATE, ("start" + "term")::DATE) d
            LEFT JOIN gtfs_agency USING (feed_index)
            LEFT JOIN gtfs_trips  USING (feed_index, trip_id)
            LEFT JOIN gtfs_stop_times USING (feed_index, trip_id)
        WINDOW rds AS (PARTITION BY route_id, direction_id, stop_id ORDER BY wall_time(date, arrival_time, agency_timezone))
    ) a WHERE a.date >= "start"
    $$
LANGUAGE SQL STABLE;

/* 
 * Get observed headways from inferred calls data
*/
CREATE OR REPLACE FUNCTION get_headway_observed(start date, term interval)
    RETURNS TABLE (
        trip_id text,
        stop_id text,
        "date" date,
        period int,
        headway interval
    ) AS $$
    SELECT
        trip_id,
        stop_id,
        c.date,
        day_period((call_time - deviation) AT TIME ZONE 'US/Eastern') as period,
        call_time - LAG(call_time) OVER (rds) AS headway
    FROM calls as c
    WHERE c.date >= "start"
        AND c.date < ("start" + "term")::DATE
    WINDOW rds AS (PARTITION BY route_id, direction_id, stop_id ORDER BY call_time)
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_adherence(start date, term interval)
    RETURNS TABLE (
        date date,
        hour int,
        route_id text,
        direction_id integer,
        stop_id text,
        observed integer,
        early_5 integer,
        early_2 integer,
        early integer,
        on_time integer,
        late integer,
        late_10 integer,
        late_15 integer,
        late_20 integer,
        late_30 integer
    ) AS $$
    SELECT
        (call_time AT TIME ZONE 'US/Eastern' + deviation)::date AS date,
        EXTRACT(HOUR FROM call_time AT TIME ZONE 'US/Eastern')::integer AS hour,
        route_id,
        direction_id,
        stop_id,
        COUNT(*)::int AS observed,
        COUNT(NULLIF(false, deviation < interval '-5 minutes'))::int AS early_5,
        COUNT(NULLIF(false, deviation < interval '-2 minutes 30 seconds'))::int AS early_2,
        COUNT(NULLIF(false, deviation < interval '-1 minutes'))::int AS early,
        COUNT(NULLIF(false, deviation BETWEEN interval '-1 minutes' AND interval '5 minutes'))::int AS on_time,
        COUNT(NULLIF(false, deviation > interval '300 seconds'))::int AS late,
        COUNT(NULLIF(false, deviation > interval '600 seconds'))::int AS late_10,
        COUNT(NULLIF(false, deviation > interval '900 seconds'))::int AS late_15,
        COUNT(NULLIF(false, deviation > interval '1200 seconds'))::int AS late_20,
        COUNT(NULLIF(false, deviation > interval '1800 seconds'))::int AS late_30
    FROM calls
    WHERE source = 'I'
        AND (call_time AT TIME ZONE 'US/Eastern')::date + deviation
            BETWEEN "start" AND "start" + "term"
    GROUP BY
        1,
        2,
        route_id,
        direction_id,
        stop_id
    $$
LANGUAGE SQL STABLE;

COMMIT;