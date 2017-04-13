/*
    Requires all of the tables in create.sql.
*/
-- Set to the first day of the month in question
-- This is done in the Makefile. Uncomment if using the file directly.
-- SET @the_month = '2015-10-01';

-- find observed headways
SET @prev_rds = NULL;

-- sort calls by route/direction/stop and departure time.
-- Use variables to calculate headway between successive fields
-- 5 min
INSERT hw_observed
SELECT
    trip_index,
    rds_index,
    call_time,
    headway
FROM (
    SELECT
        trip_index,
        call_time,
        @headway := IF(`rds_index`=@prev_rds, TIME_TO_SEC(TIMEDIFF(depart_time(call_time, dwell_time), @prev_depart)), NULL) AS headway,
        @prev_rds := rds_index,
        @prev_depart := depart_time(call_time, dwell_time)
    FROM (
        SELECT * FROM calls
        WHERE DATE(call_time) BETWEEN @the_month AND DATE_SUB(DATE_ADD(@the_month, INTERVAL 1 MONTH), INTERVAL 1 DAY)
        ORDER BY
            rds_index,
            depart_time(call_time, dwell_time) ASC
    ) a
) b;
