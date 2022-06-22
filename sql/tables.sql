CREATE SCHEMA IF NOT EXISTS stat;

DROP TABLE IF EXISTS stat.date_trips;
DROP TABLE IF EXISTS stat.holidays;
DROP TABLE IF EXISTS stat.schedule_hours;
-- DROP TABLE IF EXISTS stat.missing_calls;
DROP TABLE IF EXISTS stat.headway_scheduled;
DROP TABLE IF EXISTS stat.headway_observed;
DROP TABLE IF EXISTS stat.bunching;
DROP TABLE IF EXISTS stat.bunching_average;
DROP TABLE IF EXISTS stat.adherence;
DROP TABLE IF EXISTS stat.service;
DROP TABLE IF EXISTS stat.otp;
DROP TABLE IF EXISTS stat.otd;
DROP TABLE IF EXISTS stat.ewt;
DROP TABLE IF EXISTS stat.cewt;
DROP TABLE IF EXISTS stat.wtp;
DROP TABLE IF EXISTS stat.evt;
DROP TABLE IF EXISTS stat.speed;
DROP TABLE IF EXISTS stat.routeratio;
DROP TABLE IF EXISTS stat.spacing;
DROP TABLE IF EXISTS stat.stopdist;

-- Add indices to calls table
CREATE INDEX IF NOT EXISTS calls_date ON inferno.calls (date);

BEGIN;

CREATE TABLE stat.date_trips (
    feed_index integer not null,
    trip_id text not null,
    "date" date not null,
    CONSTRAINT date_trips_pk PRIMARY KEY (feed_index, "date", trip_id)
);

CREATE TABLE stat.holidays (
    "date" date PRIMARY KEY,
    "holiday" text NOT NULL DEFAULT ''
);
-- Major holidays on weekdays
INSERT INTO stat.holidays ("date", holiday)
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
  ('2018-01-01','New Years Day'),
  ('2019-01-01','New Years Day'),
  ('2019-02-18','Presidents Day'),
  ('2019-05-04','Memorial Day'),
  ('2019-07-04','Independence Day'),
  ('2019-09-02','Labor Day'),
  ('2019-11-11','Veterans Day'),
  ('2019-11-28','Thanksgiving'),
  ('2019-12-25','Christmas')
;

CREATE TABLE stat.schedule_hours (
    "date" date not null,
    route_id text,
    direction_id int,
    stop_id text,
    hour integer not null,
    scheduled integer not null,
    pickups integer not null,
    exception integer not null,
    CONSTRAINT schedule_hours_pk PRIMARY KEY ("date", route_id, direction_id, stop_id, hour)
);

CREATE TABLE stat.headway_scheduled (
    feed_index int not null,
    trip_id text NOT NULL,
    stop_id text not null,
    "date" date NOT NULL,
    period int not null,
    headway interval DEFAULT NULL
);
CREATE UNIQUE INDEX hws_idx ON stat.headway_scheduled
    (feed_index, trip_id, stop_id, "date");

CREATE TABLE stat.headway_observed (
    trip_id text NOT NULL,
    stop_id text NOT NULL,
    "date" date NOT NULL,
    period int not null,
    headway interval DEFAULT NULL,
    PRIMARY KEY (trip_id, stop_id, date)
);
CREATE INDEX hwob_date ON stat.headway_observed ("date");

CREATE TABLE stat.bunching (
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

CREATE TABLE stat.bunching_average (
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

CREATE TABLE stat.evt (
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

CREATE TABLE stat.service (
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

CREATE TABLE stat.otp (
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

CREATE TABLE stat.ewt (
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

CREATE TABLE stat.cewt (
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

CREATE TABLE stat.wtp (
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

CREATE TABLE stat.speed (
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

CREATE TABLE stat.otd (
    month date not null,
    route_id text not null,
    direction_id int not null,
    weekend smallint NOT NULL CHECK (weekend IN (0, 1)),
    period int CHECK (period BETWEEN 1 AND 5),
    count int not null,
    count_otd int not null,
    CONSTRAINT otd_pk PRIMARY KEY (month, route_id, direction_id)
);

CREATE TABLE stat.routeratio (
    feed_index integer,
    route_id text,
    direction_id int,
    shape_id text,
    routeratio numeric,
    UNIQUE (feed_index, route_id, direction_id, shape_id)
);
CREATE TABLE stat.spacing(
    feed_index integer,
    route_id text,
    direction_id integer,
    count_trip integer,
    wavg numeric,
    UNIQUE (feed_index, route_id, direction_id)
);
CREATE TABLE stat.stopdist (
    feed_index integer,
    route_id text,
    direction_id integer,
    lead_stop_id text,
    lag_stop_id text,
    spacing numeric,
    CONSTRAINT stopdist_pk PRIMARY KEY (feed_index, route_id, lead_stop_id, lag_stop_id)
);

CREATE TABLE gtfs.shape_dist_traveled (
    feed_index int,
    route_id text,
    shape_id text,
    stop_id text,
    shape_dist_traveled double precision,
    PRIMARY KEY (feed_index, route_id, shape_id, stop_id)
);

COMMIT;
