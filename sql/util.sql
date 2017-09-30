BEGIN;

CREATE OR REPLACE FUNCTION text2int(text[])
    RETURNS integer[] AS $$
        SELECT array_agg(n::integer) FROM unnest($1) AS n;
    $$
LANGUAGE SQL IMMUTABLE;

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

-- give an interval in the number of elapsed minutes
CREATE OR REPLACE FUNCTION minutes(interval)
    RETURNS integer AS $$
        SELECT ((DATE_PART('day', $1) * 24 + DATE_PART('hour', $1)) * 60 + DATE_PART('minute', $1) +
        CASE WHEN DATE_PART('second', $1) > 30 THEN 1 ELSE 0 END)::integer;
    $$
LANGUAGE SQL IMMUTABLE;

-- generate the timestampz for a gtfs schedule date and time
CREATE OR REPLACE FUNCTION wall_time(d date, t interval, zone text)
    RETURNS timestamp with time zone AS $$
        SELECT ("d" + '12:00'::time)::timestamp without time zone at time zone "zone" - interval '12 HOURS' + "t"
    $$
LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION date_range(start_date date, end_date date)
    RETURNS TABLE("date" date) AS $$
        WITH RECURSIVE t(n) AS (
            VALUES ("start_date")
            UNION
            SELECT (n + INTERVAL '1 day')::date FROM t WHERE n < "end_date"

        )
        SELECT * FROM t
    $$
LANGUAGE SQL IMMUTABLE;

-- return dates->trip_id lookup rows for dates in range
-- 8s, 2.5m rows for one month
-- Assumes trip-ids not repeated in different feeds
CREATE OR REPLACE FUNCTION get_date_trips(start_date date, end_date date)
    RETURNS TABLE(feed_index integer, "date" date, trip_id text)
    AS $$
        SELECT
            feed_index, range.date, trip_id
        FROM
            date_range("start_date", "end_date") range
            LEFT JOIN gtfs_calendar c ON (
                -- address the weekday columns of gtfs_calendar as an array, using the day-of-week as an index
                (ARRAY[sunday, monday, tuesday, wednesday, thursday, friday, saturday])[extract(dow from range.date) + 1] = '1'
                AND range.date BETWEEN c.start_date AND c.end_date
            )
            LEFT JOIN gtfs_calendar_dates USING (feed_index, date, service_id)
            LEFT JOIN gtfs_trips USING (feed_index, service_id)
        WHERE exception_type IS NULL
        UNION
        SELECT
            feed_index, date, trip_id
        FROM gtfs_trips
            LEFT JOIN gtfs_calendar_dates USING (feed_index, service_id)
        WHERE
            exception_type = 1
            AND date BETWEEN "start_date" AND "end_date"
    $$
LANGUAGE SQL STABLE;

/* 
 * find scheduled headways
 * Same general strategy as observed headways, except here the date of the scheduled call
 * comes from the `date_trips` table.
 * 5-10 minutes for a month
*/
CREATE OR REPLACE FUNCTION get_headway_scheduled(start_date date, term interval)
    RETURNS TABLE (
        trip_id text,
        stop_id text,
        "date" date,
        headway interval
    ) AS $$
    SELECT * FROM (
        SELECT
            trip_id,
            stop_id,
            wall_time(date, arrival_time, agency_timezone)::date AS date,
            arrival_time - LAG(arrival_time) OVER (rds) AS headway
        FROM gtfs_stop_times
            LEFT JOIN gtfs_agency USING (feed_index)
            LEFT JOIN gtfs_trips  USING (feed_index, trip_id)
            -- join with a list of dates beginning just before our interval
            INNER JOIN get_date_trips(("start_date" - INTERVAL '1 day')::DATE, ("start_date" + term)::DATE) d USING (feed_index, trip_id)
        WINDOW rds AS (PARTITION BY route_id, direction_id, stop_id ORDER BY wall_time(date, arrival_time, agency_timezone))
    ) a WHERE a.date >= "start_date"
    $$
LANGUAGE SQL STABLE;

/* 
 * Get observed headways from inferred calls data
*/
CREATE OR REPLACE FUNCTION get_headway_observed(start_date date, term interval)
    RETURNS TABLE (
        trip_id text,
        stop_id text,
        "date" date,
        headway interval
    ) AS $$
    SELECT
        trip_id,
        stop_id,
        -- The "date" of a call is the scheduled calendar date, so take deviation into account.
        ((call_time - deviation) AT TIME ZONE 'US/Eastern')::date AS date,
        call_time - LAG(call_time) OVER (rds) AS headway
    FROM calls
    WHERE (call_time AT TIME ZONE 'US/Eastern')::date
        BETWEEN "start_date"
        AND ("start_date" + term)::TIMESTAMP WITHOUT TIME ZONE AT TIME ZONE 'US/Eastern'
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
            BETWEEN "start" AND "start" + term
    GROUP BY
        1,
        2,
        route_id,
        direction_id,
        stop_id
    $$
LANGUAGE SQL STABLE;

COMMIT;