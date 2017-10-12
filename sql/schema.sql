DROP TABLE IF EXISTS stat_date_trips;
DROP TABLE IF EXISTS stat_holidays;
DROP TABLE IF EXISTS stat_schedule_hours;
-- DROP TABLE IF EXISTS stat_missing_calls;
DROP TABLE IF EXISTS stat_headway_scheduled;
DROP TABLE IF EXISTS stat_headway_observed;
DROP TABLE IF EXISTS stat_bunching;
DROP TABLE IF EXISTS stat_bunching_average;
DROP TABLE IF EXISTS stat_adherence;
DROP TABLE IF EXISTS stat_service;
DROP TABLE IF EXISTS stat_otp;
DROP TABLE IF EXISTS stat_otd;
DROP TABLE IF EXISTS stat_ewt;
DROP TABLE IF EXISTS stat_cewt;
DROP TABLE IF EXISTS stat_wtp;
DROP TABLE IF EXISTS stat_evt;
DROP TABLE IF EXISTS stat_speed;
DROP TABLE IF EXISTS stat_routeratio;
DROP TABLE IF EXISTS stat_spacing;
DROP TABLE IF EXISTS stat_stopdist;

-- Add indices to calls table
CREATE INDEX calls_date ON calls (date);

BEGIN;

CREATE TABLE stat_date_trips (
    feed_index integer not null,
    trip_id text not null,
    "date" date not null,
    CONSTRAINT stat_date_trips_pk PRIMARY KEY (feed_index, "date", trip_id)
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
    "date" date NOT NULL,
    period int not null,
    headway interval DEFAULT NULL
);
CREATE UNIQUE INDEX stat_hws_idx ON stat_headway_scheduled
    (feed_index, trip_id, stop_id, "date");

CREATE TABLE stat_headway_observed (
    trip_id text NOT NULL,
    stop_id text NOT NULL,
    "date" date NOT NULL,
    period int not null,
    headway interval DEFAULT NULL
);
CREATE INDEX stat_hwob_idx ON stat_headway_observed (trip_id, stop_id);
CREATE INDEX stat_hwob_date ON stat_headway_observed ("date");

CREATE TABLE stat_bunching (
    month date NOT NULL,
    route_id text,
    direction_id int,
    stop_id text,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period integer NOT NULL CHECK (period BETWEEN 1 and 5),
    count integer NOT NULL,
    count_bunch integer NOT NULL,
    UNIQUE (month, route_id, direction_id, stop_id, weekend, period) 
);

CREATE TABLE stat_bunching_average (
    month date NOT NULL,
    route_id text,
    direction_id int,
    stop_id text,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period integer NOT NULL CHECK (period BETWEEN 1 and 5),
    count integer NOT NULL,
    bunch_count integer NOT NULL,
    UNIQUE (month, route_id, direction_id, stop_id, weekend, period) 
);

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
    direction_id int,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period integer not null CHECK (period BETWEEN 1 and 5),
    duration_avg_sched decimal not null,
    duration_avg_obs decimal not null,
    count_trips int not null,
    count_late int not null,
    UNIQUE (month, route_id, direction_id, weekend, period) 
);

CREATE TABLE stat_service (
    month date not null,
    route_id text not null,
    direction_id integer not null,
    stop_id text not null,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period integer not null CHECK (period BETWEEN 1 and 5),
    hours integer not null,
    scheduled integer not null,
    observed integer not null,
    UNIQUE (month, route_id, direction_id, stop_id, weekend, period) 
);

CREATE TABLE stat_otp (
    month date not null,
    route_id text,
    direction_id int,
    stop_id text,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period integer not null CHECK (period BETWEEN 1 and 5),
    early integer not null,
    on_time integer not null,
    late integer not null,
    UNIQUE (month, route_id, direction_id, stop_id, weekend, period) 
);

CREATE TABLE stat_ewt (
  month date NOT NULL,
  route_id text NOT NULL,
  direction_id int NOT NULL,
  stop_id int NOT NULL,
  weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
  period integer not null CHECK (period BETWEEN 1 and 5),
  scheduled_hf int NOT NULL,
  wswt int NOT NULL,
  observed_hf int NOT NULL,
  wawt int NOT NULL,
  PRIMARY KEY (month, route_id, direction_id, stop_id, weekend, period)
);

CREATE TABLE stat_cewt (
    month date not null,
    route_id text,
    direction_id int,
    stop_id text,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period integer not null CHECK (period BETWEEN 1 and 5),
    count int not null,
    count_cewt int not null,
    cewt_avg numeric not null,
    UNIQUE (month, route_id, direction_id, stop_id, weekend, period) 
);

CREATE TABLE stat_wtp (
    month date not null,
    route_id text,
    direction_id int,
    stop_id text,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period integer not null CHECK (period BETWEEN 1 and 5),
    calls integer not null,
    wtp_5 int not null,
    wtp_10 int not null,
    wtp_15 int not null,
    wtp_20 int not null,
    wtp_30 int not null,
    UNIQUE (month, route_id, direction_id, stop_id, weekend, period) 
);

CREATE TABLE stat_speed (
    month date not null,
    route_id text not null,
    direction_id int not null,
    stop_id text not null,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period integer not null CHECK (period BETWEEN 1 and 5),
    distance int not null,
    travel_time int not null,
    count integer not null,
    UNIQUE (month, route_id, direction_id, stop_id, weekend, period) 
);

CREATE TABLE stat_otd (
    month date not null,
    route_id text not null,
    direction_id int not null,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period int CHECK (period BETWEEN 1 AND 5),
    count int not null,
    count_otd int not null,
    CONSTRAINT otd_pk PRIMARY KEY (month, route_id, direction_id)
);

CREATE TABLE stat_routeratio (
    feed_index integer,
    route_id text,
    direction_id int,
    shape_id text,
    routeratio numeric,
    UNIQUE (feed_index, route_id, direction_id, shape_id) 
);
CREATE TABLE stat_spacing(
    feed_index integer,
    route_id text,
    direction_id integer,
    count_trip integer,
    wavg numeric,
    UNIQUE (feed_index, route_id, direction_id) 
);
CREATE TABLE stat_stopdist (
    feed_index integer,
    stop_id text,
    wavg numeric,
    CONSTRAINT stopdist_pk PRIMARY KEY (feed_index, stop_id)
);

COMMIT;
