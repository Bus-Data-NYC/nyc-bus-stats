-- ewt
-- Excess Wait Time.
-- During high frequency scheduled service, the average wait time per passenger
-- implied by the schedule compared with the average wait time inferred from actual bus movements.

-- swt: during high frequency scheduled service, the average Scheduled Wait Time, in seconds
-- awt: during high frequency scheduled service, the average Actual Wait Time, in seconds
-- ewt: during high frequency scheduled service, the average Excess Wait Time, in seconds
-- scheduled: the number of bus calls scheduled during high frequency service
-- observed: the number of bus calls inferred from Bus Time during high frequency scheduled service

SELECT
  start_date, end_date
FROM start_date INTO @start_date, @end_date;

SET @max_int = 2147483647;

DROP TABLE IF EXISTS tmp_awt;
DROP TABLE IF EXISTS tmp_ah;
DROP TABLE IF EXISTS tmp_sh;

CREATE temporary TABLE tmp_sh (
  headway INT,
  rds_index SMALLINT UNSIGNED,
  date DATE,
  hour TINYINT,
  time DATETIME
) ENGINE=MYISAM;

CREATE temporary TABLE tmp_ah (
  headway INT,
  rds_index SMALLINT UNSIGNED,
  date DATE,
  hour TINYINT,
  time DATETIME
) engine=myisam;

CREATE temporary TABLE tmp_awt (
  date DATE NOT NULL,
  rds_index SMALLINT UNSIGNED NOT NULL,
  hour TINYINT NOT NULL,
  ah INT NOT NULL,
  ah_sq INT NOT NULL,
  PRIMARY KEY (date, rds_index, hour)
) engine=myisam;

INSERT tmp_sh SELECT
  @headway:=IF(rds_index=@prev_rds, TIME_TO_SEC(TIMEDIFF(call_time, @prev_time)), NULL),
  @prev_rds:=rds_index,
  DATE(@mid:=ADDTIME(@prev_time, SEC_TO_TIME(@headway / 2))),
  HOUR(@mid),
  @prev_time:=call_time
FROM (
  SELECT
    rds_index,
    ADDTIME(date, departure_time) AS call_time
  FROM ref_date_trips AS dt
    INNER JOIN ref_stop_times AS st USING (trip_index)
  WHERE date BETWEEN DATE_SUB(@start_date, INTERVAL 1 DAY) AND DATE_ADD(@end_date, INTERVAL 1 DAY)
    AND pickup_type != 1
    AND departure_time BETWEEN '00:00:00' AND '23:59:59'
) AS x
ORDER BY rds_index, call_time;

/* Ingredients:
  1. measure actual headways (headways_observed)
  2. measure scheduled headways (headways_scheduled)
  3. Calculate a weighted average of average wait times over each route/direction/stop/period/weekend.
  4. Also count the total number of calls in ach

-- 15m
INSERT tmp_awt SELECT
  date,
  rds_index,
  HOUR(datetime),
  SUM(headway) AS ah,
  LEAST(SUM(headway * headway), @max_int) AS ah_sq
FROM hw_observed
WHERE year BETWEEN YEAR(@start_date) AND YEAR(@end_date)
  AND month BETWEEN MONTH(@start_date) AND MONTH(@end_date)
  AND headway IS NOT NULL
GROUP BY date,
  rds_index,
  HOUR(datetime);

/* Record Scheduled Wait Times */

INSERT ewt SELECT
  date,
  rds_index,
  hour,
  pickups AS scheduled,
  SUM(headway) AS sh,
  LEAST(SUM(headway * headway), @max_int) AS sh_sq,
  GREATEST(observed, 0) AS observed,
  COALESCE(ah, 30 * 60) AS ah,
  COALESCE(
    IF(ah_sq = @max_int, ROUND(SQRT(@max_int)), ah_sq),
    (30 * 60) * (30 * 60) - 1 -- affects 0.007% of high frequency rds-datehours
  ) AS ah_sq
FROM tmp_sh
    LEFT JOIN schedule_hours sh USING (date, rds_index, hour)
    LEFT JOIN adherence a USING (date, rds_index, hour)
    LEFT JOIN tmp_awt AS awt USING (date, rds_index, hour)
WHERE date BETWEEN @start_date AND @end_date
   AND headway IS NOT NULL
   AND scheduled >= 1
GROUP BY date,
    rds_index,
    hour;

-- 1.5 million rows in 5 mins on xl
INSERT perf_ewt
    (month, route_id, direction_id, stop_id, weekend, period, scheduled_hf, wswt, observed_hf, wawt)
SELECT
    @start_date AS month,
    route_id,
    direction_id,
    stop_id,
    (WEEKDAY(`date`) >= 5 OR `holiday` IS NOT NULL) AS weekend,
    day_period_hour(hour) AS period,
    SUM(pickups) AS scheduled_hf,
    COALESCE(ROUND(SUM(pickups * sh_sq / sh / 2)), 0) AS wswt,
    COALESCE(SUM(observed), 0) AS observed_hf,
    COALESCE(ROUND(SUM(observed * ah_sq / ah / 2)), 0) AS wawt
  FROM schedule_hours AS sh
    LEFT JOIN ewt USING (date, rds_index, hour)
    LEFT JOIN ref_holidays h USING (date)
    JOIN ref_rds USING (rds_index)
  WHERE date BETWEEN @start_date AND @end_date
    AND pickups >= 5
    AND NOT exception
  GROUP BY
    rds_index,
    weekend,
    period;


/* merge the two headway tables, calculating:
  -- observed expected wt
  -- scheduled expected wt
  -- excess wt
 */
CREATE OR REPLACE FUNCTION get_excess_wait(start date, term interval)
    RETURNS TABLE (
        route_id text,
        direction_id int,
        stop_id text,
        weekend int,
        period int,
        sched_wt interval,
        obs_wt interval,
        excess_wt interval,
        sched_calls int,
        obs_calls int
    )
    AS $$
    SELECT

    FROM stat.headway_scheduled
        LEFT JOIN stat.headway_observed ON (trip_id, stop_id, "date", period)
    WHERE "date" BETWEEN "start" AND "start" + "term"
    $$
LANGUAGE SQL STABLE;

