DROP TABLE IF EXISTS stat_date_trips;
DROP TABLE IF EXISTS stat_holidays;
DROP TABLE IF EXISTS stat_schedule_hours;
-- DROP TABLE IF EXISTS stat_missing_calls;
DROP TABLE IF EXISTS stat_headway_scheduled;
DROP TABLE IF EXISTS stat_headway_observed;
DROP TABLE IF EXISTS stat_bunching;
DROP TABLE IF EXISTS stat_adherence;
DROP TABLE IF EXISTS stat_service;
DROP TABLE IF EXISTS stat_otp;
DROP TABLE IF EXISTS stat_cewt;
DROP TABLE IF EXISTS perf_cewt;
DROP TABLE IF EXISTS stat_wtp;
DROP TABLE IF EXISTS stat_evt;

BEGIN;

-- Add indices to calls table
CREATE INDEX calls_rds ON calls (route_id, direction_id, stop_id);
CREATE INDEX calls_date ON calls ((timezone('US/Eastern'::text, call_time)::date));

CREATE TABLE stat_date_trips (
    feed_index integer not null,
    "date" date not null,
    trip_id text not null,
    CONSTRAINT stat_date_trips_pk PRIMARY KEY (feed_index, date, trip_id)
);

CREATE TABLE stat_holidays (
    "date" date PRIMARY KEY,
    "holiday" text NOT NULL DEFAULT ''
);
-- Major holidays on weekdays
INSERT INTO stat_holidays ("date", holiday)
VALUES
  ('2015-11-26','Thanksgiving'),
  ('2015-12-24','Christmas Eve'),
  ('2015-12-25','Christmas'),
  ('2016-01-01','New Years Day'),
  ('2016-02-15','Presidents Day'),
  ('2016-05-30','Memorial Day'),
  ('2016-09-05','Labor Day'),
  ('2016-11-24','Thanksgiving'),
  ('2016-12-26','Christmas (Observed)'),
  ('2016-12-24','Christmas Eve'),
  ('2017-01-02','New Years Day'),
  ('2017-02-20','Presidents Day'),
  ('2017-05-29','Memorial Day'),
  ('2017-09-04','Labor Day'),
  ('2017-11-23','Thanksgiving'),
  ('2017-12-25','Christmas'),
  ('2018-01-01','New Years Day')
;

CREATE TABLE stat_schedule_hours (
    "date" date not null,
    route_id text,
    direction_id int,
    stop_id text,
    hour integer not null,
    scheduled integer not null,
    pickups integer not null,
    exception integer not null,
    CONSTRAINT stat_schedule_hours_pk PRIMARY KEY ("date", route_id, direction_id, stop_id, hour)
);

CREATE TABLE stat_headway_scheduled (
    feed_index int not null,
    trip_id text NOT NULL,
    stop_id text not null,
    service_date date not null,
    datetime timestamp with time zone NOT NULL,
    headway interval DEFAULT NULL,
    CONSTRAINT stat_headway_scheduled_pk
        PRIMARY KEY (feed_index, trip_id, stop_id, service_date)
);
CREATE INDEX stat_headway_scheduled_idx ON stat_headway_scheduled (feed_index, trip_id);

CREATE TABLE stat_headway_observed (
    trip_id text NOT NULL,
    stop_id text NOT NULL,
    service_date date not null,
    datetime timestamp with time zone NOT NULL,
    headway interval DEFAULT NULL,
    CONSTRAINT stat_headway_observed_pk
        PRIMARY KEY (trip_id, stop_id, service_date)
);
CREATE INDEX stat_headway_observed_idx ON stat_headway_observed (datetime);

CREATE TABLE stat_bunching (
    month date NOT NULL,
    route_id text,
    direction_id int,
    stop_id text,
    period integer NOT NULL,
    weekend integer NOT NULL,
    call_count integer NOT NULL,
    bunch_count integer NOT NULL
);
CREATE INDEX stat_bunching_month_idx ON stat_bunching (month, route_id, direction_id, stop_id);

CREATE TABLE stat_bunching_average (
    month date NOT NULL,
    route_id text,
    direction_id int,
    stop_id text,
    period integer NOT NULL,
    weekend integer NOT NULL,
    call_count integer NOT NULL,
    bunch_count integer NOT NULL
);
CREATE INDEX stat_bunching_average_idx ON stat_bunching_average (month, route_id, direction_id, stop_id);

-- CREATE TABLE stat_missing_calls (
--     trip_id int NOT NULL,
--     route_id text NOT NULL,
--     direction_id integer not null.
--     stop_id text not null,
--     date date NOT NULL,
--     CONSTRAINT stat_missing_calls_pk PRIMARY KEY
--         (trip_id, route_id, direction_id, stop_id, datetime)
-- );

CREATE TABLE stat_adherence (
    date date not null,
    route_id text,
    direction_id int,
    stop_id text,
    hour integer not null,
    observed integer not null, -- observed pickups
    early_5 integer not null,
    early_2 integer not null,
    early integer not null,
    on_time integer not null,
    late integer not null,
    late_10 integer not null,
    late_15 integer not null,
    late_20 integer not null,
    late_30 integer not null,
    PRIMARY KEY (date, route_id, direction_id, stop_id, hour)
);

CREATE TABLE stat_evt (
    month date not null,
    route_id text not null,
    weekend integer not null,
    period integer not null,
    count_trips integer not null,
    duration_avg_sched decimal not null,
    duration_avg_obs decimal not null,
    pct_late decimal not null
);
CREATE INDEX stat_evt_idx ON stat_evt (month, route_id);

CREATE TABLE stat_service (
    month date not null,
    route_id text not null,
    direction_id integer not null,
    stop_id int not null,
    weekend integer not null,
    period integer not null,
    hours integer not null,
    scheduled integer not null,
    observed integer not null
);
CREATE INDEX stat_service_idx ON stat_service (month, route_id, direction_id, stop_id);

CREATE TABLE stat_otp (
    month date not null,
    route_id text,
    direction_id int,
    stop_id text,
    weekend integer not null,
    period integer not null,
    early integer not null,
    on_time integer not null,
    late integer not null
);
CREATE INDEX stat_otp_idx ON stat_otp (month, route_id, direction_id, stop_id);

CREATE TABLE stat_cewt (
    month date not null,
    route_id text,
    direction_id int,
    stop_id text,
    weekend integer not null,
    period integer not null,
    count int not null,
    count_cewt int not null,
    scheduled integer not null,
    observed integer not null,
    wawt int not null
);
CREATE INDEX stat_ewt_idx ON stat_ewt (month, route_id, direction_id, stop_id);

CREATE TABLE stat_wtp (
    month date not null,
    route_id text,
    direction_id int,
    stop_id text,
    weekend integer not null,
    period integer not null,
    hours_hf integer not null,
    wtp_5 int not null,
    wtp_10 int not null,
    wtp_15 int not null,
    wtp_20 int not null,
    wtp_30 int not null,
    CONSTRAINT stat_wtp_pk PRIMARY KEY (month, route_id, direction_id, stop_id) 
);

CREATE TABLE stat_speed (
    month date not null,
    route_id text not null,
    direction_id int not null,
    stop_id text not null,
    weekend integer not null,
    period integer not null,
    distance numeric not null,
    travel_time numeric not null,
    CONSTRAINT stat_speed_pk PRIMARY KEY (month, route_id, direction_id, stop_id)
);

COMMIT;
