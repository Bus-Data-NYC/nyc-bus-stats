-- Number of distinct rds_index (route-direction-stop) (calls_2015-10): 25262

-- number each trip over each route on a given service
-- used for tracking headways
SET @id = 0,
    @service_id = NULL,
    @trip_id = NULL;
SELECT
    IF(
        @service_id = t.`service_id` && @trip_id = t.`trip_id`,
        NULL,
        @id := 0 || @service_id := t.`service_id` || @trip_id := t.`trip_id`
    ) AS _,
    @id := @id + 1 id,
    t.`service_id`,
    t.`trip_id`,
    MIN(stg.`arrival_time`) first_depart
FROM `trips_gtfs` t
JOIN `stop_times_gtfs` stg USING (`trip_id`)
GROUP BY t.`service_id`, t.`trip_id`
ORDER BY t.`service_id`, MIN(stg.`arrival_time`)

-- attempt at scheduled headways table

CREATE TABLE headways_gtfs AS
SELECT DISTINCT
    r.`rds_index`,
    a.`trip_id`,
    60 * (
        a.`arrival_time` - GROUP_CONCAT(
            z.`arrival_time` ORDER BY z.`arrival_time` DESC,
            ', '
        )
    ) / 10000 AS headway
FROM
    `stop_times_gtfs` a
    LEFT JOIN `stop_times_gtfs` z  ON (a.`stop_id`  = z.`stop_id`)
    LEFT JOIN `trips_gtfs` t1 ON (t1.`trip_id` = a.`trip_id`)
    LEFT JOIN `trips_gtfs` t2 ON (t2.`trip_id` = z.`trip_id`)
    LEFT JOIN `rds_indexes` r ON (
        r.`direction` = t1.`direction_id`
        AND r.`route` = t1.`route_id`
        AND r.`stop_id` = a.`stop_id`
    )
WHERE
    z.`arrival_time` < a.`arrival_time`
    AND t1.`trip_id` != t2.`trip_id`
    AND t1.`route_id` = t2.`route_id`
    AND t1.`service_id` = t2.`service_id`
    AND t1.`direction_id` = t2.`direction_id`
GROUP BY r.`rds_index`, a.`trip_id`;

-- Give an index to every stop by rds. Will enable joining calls to calls.
SET
    @stop = 0,
    @rds_index = NULL;
SELECT
    IF(
        @rds_index = rds_index,
        NULL,
        @stop := 0 || @rds_index := rds_index
    ) AS _,
    @rds_index rdsvar,
    rds_index,
    call_time,
    @stop stopiiiddd,
    @stop := @stop + 1 as stop_id
    FROM calls
    ORDER BY rds_index, call_time ASC
    ;

-- join calls to stop_times_gtfs