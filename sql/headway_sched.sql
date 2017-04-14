/* 
 * find scheduled headways
 * Same general strategy as observed headways, except here the date of the scheduled call
 * comes from the `date_trips` table.
*/
SELECT
    start_date,
    end_date
FROM start_date INTO @start_date, @end_date;

-- 18 mins

SET @prev_rds = NULL;

INSERT REPLACE INTO hw_gtfs (trip_index, rds_index, datetime, headway)
SELECT trip_index, rds_index, call_time datetime, headway FROM (
    SELECT
        trip_index,
        @headway := IF(rds_index=@prev_rds, TIME_TO_SEC(TIMEDIFF(call_time, @prev_time)), NULL) headway,
        @prev_rds := rds_index AS rds_index,
        @prev_time := call_time AS call_time
    FROM (
        SELECT
            rds_index,
            trip_index,
            ADDTIME(dt.`date`, st.`departure_time`) call_time
        FROM
            ref_date_trips dt
            LEFT JOIN ref_stop_times st USING (trip_index)
        WHERE
            dt.`date` BETWEEN @start_date AND @end_date
            AND pickup_type != 1
        ORDER BY
            rds_index,
            call_time
    ) a
) b
