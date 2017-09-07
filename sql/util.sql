BEGIN;

-- All day is divided into five parts.
CREATE OR REPLACE FUNCTION day_period (time)
    RETURNS integer AS $$
        WITH a AS (
            SELECT EXTRACT(HOUR FROM $1) AS hour
        ) SELECT CASE
            WHEN hour BETWEEN 0 AND 6 THEN 5
            WHEN hour BETWEEN 7 AND 9 THEN 1
            WHEN hour BETWEEN 10 AND 15 THEN 2
            WHEN hour BETWEEN 16 AND 18 THEN 3
            WHEN hour BETWEEN 19 AND 22 THEN 4
            WHEN hour >= 23 THEN 5
        END FROM a
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
CREATE OR REPLACE FUNCTION get_date_trips(start_date date, end_date date)
    RETURNS TABLE(feed_index integer, "date" date, trip_id text)
    AS $$
        SELECT
            MAX(feed_index), range.date, trip_id
        FROM
            date_range("start_date", "end_date") range
            LEFT JOIN gtfs_calendar c ON (
                -- address the weekday columns of gtfs_calendar as an array, using the day-of-week as an index
                (ARRAY[sunday, monday, tuesday, wednesday, thursday, friday, saturday])[extract(dow from range.date) + 1] = '1'
                AND range.date BETWEEN c.start_date AND c.end_date
            )
            LEFT JOIN gtfs_calendar_dates gcd USING (feed_index, date, service_id)
            LEFT JOIN gtfs_trips USING (feed_index, service_id)
        WHERE exception_type IS NULL
        GROUP BY range.date, trip_id
        UNION
        SELECT
            MAX(feed_index), date, trip_id
        FROM gtfs_trips
            LEFT JOIN gtfs_calendar_dates USING (feed_index, service_id)
        WHERE
            exception_type = 1
            AND date BETWEEN "start_date" AND "end_date"
        GROUP BY date, trip_id
    $$
LANGUAGE SQL STABLE;

/* 
 * find scheduled headways
 * Same general strategy as observed headways, except here the date of the scheduled call
 * comes from the `date_trips` table.
 * 5-10 minutes for a month
*/
CREATE OR REPLACE FUNCTION get_headway_scheduled(start_date date, end_date date)
    RETURNS TABLE (
        feed_index integer,
        trip_id text,
        route_id text,
        direction_id integer,
        stop_id text,
        "date" date,
        "datetime" timestamp with time zone,
        headway interval
    ) AS $$
    SELECT
        feed_index,
        trip_id,
        route_id,
        direction_id,
        stop_id,
        date::date,
        wall_time(date, arrival_time, agency_timezone) AS datetime,
        arrival_time - lag(arrival_time) OVER (PARTITION BY route_id, direction_id, stop_id ORDER BY wall_time(date, arrival_time, agency_timezone)) AS headway
    FROM gtfs_stop_times
        LEFT JOIN gtfs_agency USING (feed_index)
        LEFT JOIN gtfs_trips  USING (feed_index, trip_id)
        INNER JOIN get_date_trips("start_date", "end_date") d USING (feed_index, trip_id)
    $$
LANGUAGE SQL STABLE;

/* 
 * Get observed headways for from inferred calls data
*/
CREATE OR REPLACE FUNCTION get_headway_observed(start_date date, end_date date)
    RETURNS TABLE (
        trip_id text,
        stop_id text,
        service_date date,
        "datetime" timestamp with time zone,
        headway interval
    ) AS $$
    SELECT
        trip_id,
        stop_id,
        service_date date,
        call_time AS datetime,
        call_time - lag(call_time) OVER (PARTITION BY route_id, direction_id, stop_id ORDER BY call_time) AS headway
    FROM calls
        WHERE DATE(call_time) BETWEEN "start_date" AND "end_date";
    $$
LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_adherence(start date, finish date)
    RETURNS TABLE (
        date date,
        route_id text,
        direction_id integer,
        stop_id text,
        hour integer,
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
        service_date,
        date_trunc('hour', service_date) AS hour,
        route_id,
        direction_id,
        stop_id,
        COUNT(*) AS observed,
        COUNT(NULLIF(false, deviation < interval '-5 minutes')) AS early_5,
        COUNT(NULLIF(false, deviation < interval '-2 minutes 30 seconds')) AS early_2,
        COUNT(NULLIF(false, deviation < interval '-1 minutes')) AS early,
        COUNT(NULLIF(false, deviation BETWEEN interval '-1 minutes' AND interval '5 minutes')) AS on_time,
        COUNT(NULLIF(false, deviation > interval '300 seconds')) AS late,
        COUNT(NULLIF(false, deviation > interval '600 seconds')) AS late_10,
        COUNT(NULLIF(false, deviation > interval '900 seconds')) AS late_15,
        COUNT(NULLIF(false, deviation > interval '1200 seconds')) AS late_20,
        COUNT(NULLIF(false, deviation > interval '1800 seconds')) AS late_30
    FROM (
        SELECT *, (call_time + deviation)::date service_date
        FROM calls
        WHERE source = 'I' AND (call_time + deviation)::date BETWEEN "start" AND "finish"
        ) AS c
    GROUP BY
        service_date, 2, route_id, direction_id, stop_id
    $$

LANGUAGE SQL STABLE;

COMMIT;