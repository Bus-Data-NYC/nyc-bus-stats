/*
    Requires all of the tables in create.sql.
*/
-- Set to the first day of the month in question
SELECT
    start_date,
    end_date
FROM start_date INTO @start_date, @end_date;

-- find observed headways
SET @prev_rds = NULL;

DROP TABLE IF EXISTS hw_observed_raw;
CREATE TEMPORARY TABLE hw_observed_raw AS
    SELECT
        trip_index,
        call_time,
        @headway := IF(`rds_index`=@prev_rds, TIME_TO_SEC(TIMEDIFF(call_time, @prev_depart)), NULL) AS headway,
        @prev_rds := rds_index AS rds_index,
        @prev_depart := call_time AS datetime
    FROM (
        SELECT * FROM calls
        WHERE DATE(call_time) BETWEEN @start_date AND @end_date
        ORDER BY
            rds_index,
            call_time ASC
    ) a

-- sort calls by route/direction/stop and departure time.
-- Use variables to calculate headway between successive fields
-- 5-10 min for one month
INSERT hw_observed
SELECT
    `trip_index`,
    `rds_index`,
    `datetime`,
    YEAR(`datetime`) AS year,
    MONTH(`datetime`) AS month,
    headway
FROM hw_observed_raw;