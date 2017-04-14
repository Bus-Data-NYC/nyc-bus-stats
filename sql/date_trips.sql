-- 2 min for one month

SELECT start_date, end_date
FROM start_date INTO @start_date, @end_date;

-- populate ref_dates table with list of dates between min and max
CALL add_dates(@start_date, @end_date);

-- add dates->trip_index lookup for dates in range
INSERT IGNORE ref_date_trips (date, trip_index)
    SELECT
        date,
        trip_index
    FROM ref_dates d
    -- Concatenate weekday fields and match day of week
    LEFT JOIN gtfs_calendar c ON (
        d.date BETWEEN c.start_date AND c.end_date
        AND MID(
            CONCAT(monday, tuesday, wednesday, thursday, friday, saturday, sunday),
            WEEKDAY(d.date) + 1,
            1)
        )
    JOIN ref_trips USING (service_id)
    LEFT JOIN gtfs_calendar_dates gcd USING (date, service_id)
    WHERE
        d.date BETWEEN @start_date AND @end_date
        AND exception_type IS NULL
    -- Include exceptions that add service
    UNION
    SELECT date,
        service_id
    FROM gtfs_calendar_dates
    WHERE exception_type = 1
        AND date BETWEEN @start_date AND @end_date;
