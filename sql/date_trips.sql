-- 2 min for one month

SELECT start_date, end_date
FROM start_date INTO @min_date, @max_date;

CALL add_dates(@min_date, @max_date);

INSERT IGNORE ref_date_service (date, service_id)
    SELECT date, service_id FROM (
        SELECT
            d.date,
            c.service_id
        FROM ref_dates d
        LEFT JOIN gtfs_calendar c ON (
            d.date BETWEEN c.start_date AND c.end_date
            AND MID(
                CONCAT(monday, tuesday, wednesday, thursday, friday, saturday, sunday),
                WEEKDAY(d.date) + 1,
                1)
        )
        WHERE d.date BETWEEN @min_date AND @max_date
    ) a
    LEFT JOIN gtfs_calendar_dates gcd USING (date, service_id)
    WHERE gcd.exception_type IS NULL
UNION
    SELECT date,
        service_id
    FROM gtfs_calendar_dates
    WHERE exception_type = 1
        AND date BETWEEN @min_date AND @max_date;

INSERT IGNORE ref_date_service
SELECT DATE_ADD(date, INTERVAL 1 day),
       service_id,
       1 AS date_offset
FROM ref_date_service
WHERE date_offset = 0
    AND date BETWEEN @min_date AND @max_date;

INSERT IGNORE ref_date_trips
    SELECT date,
        trip_index,
        date_offset
    FROM ref_date_service
    JOIN ref_trips USING (service_id);
