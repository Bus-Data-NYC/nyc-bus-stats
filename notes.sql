-- Number of distinct rds_index (route-direction-stop) (calls_2015-10): 25262

-- join calls to calls to get observed headway
-- not necessary, retained here for testing
/*
DROP TABLE IF EXISTS call_headways;
CREATE TABLE call_headways (
    call_id INTEGER NOT NULL PRIMARY KEY,
    headway MEDIUMINT UNSIGNED NOT NULL
);

INSERT INTO call_headways (call_id, headway)
SELECT
    a.`call_id`,
    (TIME_TO_SEC(TIMEDIFF(b.`call_time`, a.`call_time`)) - IF(a.`dwell_time` > 0, a.`dwell_time`, 0)) AS headway
FROM
    calls a
    LEFT JOIN call_increments c1 ON (c1.`call_id`=a.`call_id`)
    JOIN calls b ON (a.`rds_index`=b.`rds_index`)
    LEFT JOIN call_increments c2 ON (c2.`call_id`=b.`call_id`)
WHERE
    c1.`stop_increment` - 1  = c2.`stop_increment`
    AND b.`call_time` > a.`call_time`;
*/
