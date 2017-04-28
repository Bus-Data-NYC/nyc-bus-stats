SELECT
  start_date, end_date
FROM start_date INTO @start_date, @end_date;

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
    AND date_offset < 1
    AND departure_time BETWEEN '00:00:00' AND '23:59:59'
) AS x
ORDER BY rds_index, call_time;

/* Measure Actual Headways */
-- use headway_observed

/* Record Actual Wait Times */
-- 15m
INSERT tmp_awt SELECT
  date,
  rds_index,
  hour,
  SUM(headway) AS ah,
  LEAST(SUM(headway * headway), @max_int) AS ah_sq
FROM headway_observed
WHERE date BETWEEN @start_date AND @end_date
  AND headway IS NOT NULL
GROUP BY date,
  rds_index,
  hour;

/* Record Scheduled Wait Times */
REPLACE ewt SELECT
  date,
  rds_index,
  hour,
  e.pickups AS scheduled,
  SUM(headway) AS sh,
  LEAST(SUM(headway * headway), @max_int) AS sh_sq,
  GREATEST(a.observed, 0) AS observed,
  COALESCE(a.ah, 30 * 60) AS ah,
  COALESCE(
    IF(a.ah_sq = @max_int, ROUND(SQRT(@max_int)), a.ah_sq),
    (30 * 60) * (30 * 60) - 1 -- affects 0.007% of high frequency rds-datehours
  ) AS ah_sq
FROM tmp_sh
    LEFT JOIN schedule_hours sh USING (date, rds_index, hour)
    LEFT JOIN adherence a USING (date, rds_index, hour)
    LEFT JOIN tmp_awt AS a USING (date, rds_index, hour)
WHERE date BETWEEN @start_date AND @end_date
   AND headway IS NOT NULL
   AND scheduled >= 1
GROUP BY date,
    rds_index,
    hour;

DROP TABLE tmp_awt, tmp_ah, tmp_sh;

-- 1.5 million rows in 5 mins on xl
INSERT perf_ewt
  SELECT
    @start_date AS month,
    route_id
    direction_id,
    stop_id,
    (WEEKDAY(`date`) >= 5 OR h.`holiday` IS NOT NULL) AS weekend,
    day_period_hour(hour) AS period,
    SUM(sh.pickups),
    COALESCE(ROUND(SUM(sh.pickups * sh_sq / sh / 2)), 0),
    COALESCE(SUM(ewt.observed), 0),
    COALESCE(ROUND(SUM(ewt.observed * ah_sq / ah / 2)), 0)
  FROM schedule_hours AS sh
  LEFT JOIN ewt ON (sh.date = ewt.date AND sh.rds_index = ewt.rds_index AND sh.hour = ewt.hour)
  LEFT JOIN ref_holidays h ON sh.date = h.date
  JOIN ref_rds USING (rds_index);
  WHERE sh.date BETWEEN @start_date AND @end_date
    AND sh.pickups >= 5
    AND NOT exception
  GROUP BY rds_index, weekend, period;  
