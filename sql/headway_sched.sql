/* 
 * find scheduled headways
 * Same general strategy as observed headways, except here the date of the scheduled call
 * comes from the `date_trips` table.
*/
-- 6 min
DROP TABLE IF EXISTS `hw_gtfs`;
CREATE TABLE hw_gtfs (
  `trip_index` int(11) NOT NULL,
  `rds_index` INTEGER NOT NULL,
  `datetime` datetime NOT NULL,
  `headway` MEDIUMINT UNSIGNED DEFAULT NULL,
  KEY k (trip_index, rds_index, datetime)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

SET @prev_rds = NULL;

INSERT INTO hw_gtfs (trip_index, rds_index, datetime, headway)
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
            ADDTIME(dt.`date`, st.`time`) call_time
        FROM
            date_trips dt
            LEFT JOIN stop_times st USING (trip_index)
        WHERE
            dt.`date` BETWEEN @the_month AND DATE_ADD(@the_month, INTERVAL 1 MONTH)
            AND pickup_type != 1
        ORDER BY
            rds_index,
            call_time
    ) a
) b;
