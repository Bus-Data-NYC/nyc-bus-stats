/* 
 * find scheduled headways
 * Same general strategy as observed headways, except here the date of the scheduled call
 * comes from the `date_trips` table.
*/
SELECT
    start_date,
    end_date
FROM start_date INTO @start_date, @end_date;

CREATE TEMPORARY TABLE tmp_date_stop_times (
    `rds_index` INTEGER NOT NULL,
    `trip_index` int(11) NOT NULL,
    `datetime` datetime NOT NULL,
    INDEX (`rds_index`, `datetime`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

INSERT tmp_date_stop_times
    SELECT
        rds_index,
        trip_index,
        ADDTIME(dt.`date`, st.`departure_time`) call_time
    FROM ref_stop_times st
        LEFT JOIN ref_date_trips dt USING (trip_index)
    WHERE
        dt.`date` BETWEEN @start_date AND @end_date
        AND pickup_type != 1;

SET @prev_rds = NULL;
-- 10 mins
REPLACE INTO hw_gtfs
    (trip_index, rds_index, datetime, headway)
SELECT
    trip_index,
    rds_index,
    datetime,
    headway
FROM (
    SELECT
        trip_index,
        @headway := IF(rds_index=@prev_rds, TIME_TO_SEC(TIMEDIFF(datetime, @prev_time)), NULL) headway,
        @prev_rds := rds_index AS rds_index,
        @prev_time := datetime datetime
    FROM tmp_date_stop_times
    ORDER BY
        rds_index,
        datetime
) a;
