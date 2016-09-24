/* ewt.sql */

SET @start_date = '2015-05-01', @end_date = '2015-05-31';
SET @max_int = POW(2,31)-1;

/* Measure Scheduled Headways */
SET
    @prev_rds = NULL,
    @prev_time = NULL;

DROP TABLE IF EXISTS tmp_sh;
CREATE TABLE tmp_sh (
    headway int,
    rds smallint unsigned,
    date date,
    hour tinyint,
    time datetime) ENGINE=MyISAM;

INSERT tmp_sh
    SELECT
        @headway := IF(rds=@prev_rds, TIME_TO_SEC(TIMEDIFF(call_time, @prev_time)), NULL),
        @prev_rds := rds,
        DATE(@mid := ADDTIME(@prev_time, SEC_TO_TIME(@headway / 2))),
        HOUR(@mid),
        @prev_time := call_time
    FROM (
        SELECT
            rds,
            ADDTIME(date, IF(date_offset < 1, departure_time, SUBTIME(departure_time, '24:00:00'))) AS call_time
        FROM date_trips AS dt, stop_times AS st
        WHERE date BETWEEN DATE_SUB(@start_date, INTERVAL 1 DAY
            AND DATE_ADD(@end_date, INTERVAL 1 DAY)
            AND dt.trip_index = st.trip_index
            AND pickup_type != 1
            AND IF(date_offset < 1, departure_time, SUBTIME(departure_time, '24:00:00'))
                BETWEEN '00:00:00' AND '23:59:59'
    ) AS x
    ORDER BY rds, call_time; -- 11m

/* Measure Actual Headways */
SET
    @prev_rds = NULL,
    @prev_time = NULL;
DROP TABLE IF EXISTS tmp_ah;
CREATE TABLE tmp_ah (
    headway int,
    rds smallint unsigned,
    date date,
    hour tinyint,
    time datetime) ENGINE=MyISAM;

INSERT tmp_ah
    SELECT
        @headway := IF(rds=@prev_rds, TIME_TO_SEC(TIMEDIFF(call_time, @prev_time)), NULL),
        @prev_rds := rds,
        DATE(@mid := ADDTIME(@prev_time,SEC_TO_TIME(@headway/2))),
        HOUR(@mid),
        @prev_time := call_time
    FROM calls
    WHERE call_time BETWEEN DATE_SUB(CAST(@start_date AS DATETIME), INTERVAL 12 HOUR)
        AND DATE_ADD(CAST(@end_date AS DATETIME), INTERVAL 36 HOUR)
        AND dwell_time != -1
    ORDER BY rds, call_time;   -- 7m

/* Record Scheduled Wait Times */
REPLACE ewt
    SELECT date,
        rds,
        hour, -1 AS pickups,
        SUM(headway) AS sh,
        LEAST(SUM(headway*headway), @max_int) AS sh_sq,
        NULL AS ah,
        NULL AS ah_sq
    FROM tmp_sh
    WHERE date BETWEEN @start_date
        AND @end_date
        AND headway IS NOT NULL
    GROUP BY date, rds, hour;    -- 16m

UPDATE
    ewt AS e,
    schedule_hours AS sh
    SET e.pickups = sh.pickups
    WHERE e.date BETWEEN @start_date
        AND @end_date
        AND (e.date = sh.date AND e.rds = sh.rds AND e.hour = sh.hour);   -- 1m

DELETE FROM ewt
    WHERE date BETWEEN @start_date AND @end_date
        AND pickups < 1;

/* Record Actual Wait Times */
DROP TABLE IF EXISTS tmp_awt;
CREATE TABLE tmp_awt (
    date date NOT NULL,
    rds smallint unsigned NOT NULL,
    hour tinyint NOT NULL,
    ah int NOT NULL,
    ah_sq int NOT NULL,
    PRIMARY KEY (date, rds, hour)) ENGINE=MyISAM;

INSERT tmp_awt
    SELECT
        date,
        rds,
        hour,
        SUM(headway) AS ah,
        LEAST(SUM(headway*headway), @max_int) AS ah_sq
    FROM tmp_ah
    WHERE date BETWEEN @start_date AND @end_date
        AND headway IS NOT NULL
    GROUP BY date, rds, hour;    -- 15m

UPDATE
    ewt AS e
        INNER JOIN tmp_awt AS a ON (e.date = a.date AND e.rds = a.rds AND e.hour = a.hour)
    SET e.ah = a.ah,
        e.ah_sq = a.ah_sq; -- 1m

-- affects 0.007% of high frequency rds-datehours :
UPDATE ewt SET ah = 1800, ah_sq = 1800*1800-1 WHERE ah is NULL OR ah_sq is NULL;

-- affects 0.0006% of rds-datehours :
UPDATE ewt SET ah = round(sqrt(@max_int)) WHERE ah_sq = @max_int;   

REPLACE ewt_summary SELECT
        CONCAT(YEAR(date),'-',LPAD(MONTH(date), 2, '0'),'-01') AS month,
        route_id,
        SUM(pickups),
        SEC_TO_TIME(1/2*SUM(sh_sq)/SUM(sh)) AS swt,
        SEC_TO_TIME(1/2*SUM(ah_sq)/SUM(ah)) AS awt,
        -1 AS ewt
    FROM ewt, rds
    WHERE pickups >= 5
        AND rds.rds=ewt.rds
        AND date BETWEEN @start_date AND @end_date
        AND route_id != 'B39'
    GROUP BY EXTRACT(YEAR_MONTH FROM date), route_id;    -- 10s

UPDATE ewt_summary
    SET ewt = SUBTIME(awt, swt);

-- Get monthly weighted average for all routes:
SELECT
    month,
    SUM(pickups),
    SUM(pickups*TIME_TO_SEC(swt))/SUM(pickups)/60 AS swt_wa,
    SUM(pickups*TIME_TO_SEC(awt))/SUM(pickups)/60 AS awt_wa,
    SUM(pickups*TIME_TO_SEC(ewt))/SUM(pickups)/60 AS ewt_wa
    FROM ewt_summary
    GROUP BY month;

-- Get monthly weighted average for Manhattan:
SELECT
    month,
    SUM(pickups),
    SUM(pickups*TIME_TO_SEC(swt))/SUM(pickups)/60 AS swt_wa,
    SUM(pickups*TIME_TO_SEC(awt))/SUM(pickups)/60 AS awt_wa,
    SUM(pickups*TIME_TO_SEC(ewt))/SUM(pickups)/60 AS ewt_wa
    FROM ewt_summary
    WHERE LEFT(route_id, 1)='M'
    GROUP BY month;

-- TODO Exclude M86/M86+ (crossover) from Sunday, June 28 to Wednesday, July 1, 2015.
