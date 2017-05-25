-- From: Nathan Johnson

-- So, at some point I did dump, compress, and upload some "calls" data - the inferred
-- stop times that forms the basis of the performance analysis (along with the schedule data).
-- I don't want to put them on a public website since I have concerns about the accuracy of
-- some of the dwell times. However, you can download them. I uploaded monthly data for
-- August 2014 to August 2015. The August 2015 data is available here:
-- https://s3.amazonaws.com/data2.mytransit.nyc/bus_calls/2015/calls_2015-08.tsv.xz.
-- You can guess the URLs of the earlier months (they take the same form). The files
-- are quite large (300-400 MB/month compressed; 2-3 GB/month uncompressed). The files
-- are tab-delimited (\t) with unix (\n) line endings. Here is the SQL schema:

-- (trip_index is more "route index") - NF
CREATE TABLE IF NOT EXISTS calls (
    vehicle_id smallint not null,
    trip_index int not null,
    stop_sequence tinyint not null,
    call_time datetime not null,
    dwell_time smallint not null,
    source char(1) not null,
    rds_index smallint not null,
    deviation smallint not null,
    -- Add a PRIMARY KEY index to calls table
    `call_id` BIGINT(20) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    INDEX rds (rds_index),
    INDEX trips (trip_index)
);

-- In my wisdom, I reindexed the GTFS trip_ids as integers (trip_index), but I'm
-- not sure where I put the lookup table, so it won't be possible to match the
-- trip_index up with the GTFS trip_id (and thus the route, direction, scheduled times, etc.)
-- However, you can use this as a sample for starting to work with the data - future data
-- dumps will take the same form (and will be accompanied by a lookup table for trip_ids).
-- The stop_ids do directly match the GTFS (and numbers displayed at bus stops), though.
-- • The "vehicle_id" is the number painted on the bus and reported by Bus Time.
-- • "Stop_sequence" should be self-explanatory and matches the GTFS.
-- • "Call_time" is the time the bus was inferred to have served or passed the stop - I'm pretty
--   sure it's in local time (and not UTC), but will have to double-check when I have more time.
-- • "Dwell_time" is the number of seconds the bus spent at the stop, although maybe it was stuck
--   in traffic near the stop; or maybe if it says zero seconds, it did stop for a few seconds,
--   but was too brief to be captured. Dwell times work better in aggregate. However, there is an issue
--   which causes (a lot less than) <1% of dwell times to be over-estimated, which is why I wouldn't use
--   it for metrics yet.
-- • "Source" describes how the call_time was inferred: "C" means it was captured directly; "I" is
--    interpolated (proportional with scheduled times) between adjacent captures; "S" is extrapolated
--    backwards (also proportional with scheduled times) from the first capture of the run, and "E"
--    is extrapolated forwards (also proportional) from the final capture of the run. Most extrapolations
--    are actually interpolations as they take into account bus movements before or after the run
-- • "Deviation" is the number of seconds the call_time deviated from the scheduled time - negative means
--   early; positive means late.
-- Sorry this is so messy, and especially that the trip_id lookup data is missing, but at least this
-- should give you a start on being able to work with the data. Also, maybe don't load all months
-- because I might not find the trip_id lookup tables for these, but can relatively easily generate
-- more dumps (in the same form, but with different trip_index, but that are accompanied by trip_id
-- lookup tables).

-- From: Nathan Johnson

-- I've uploaded all calls data (inferred actual stop/pass times) for August 2014
-- through February 2016. The URLs to download the files are in the format
-- https://s3.amazonaws.com/data2.mytransit.nyc/bus_calls/YYYY/calls_YYYY-MM.tsv.xz

-- Since the calls data also includes deviations from schedule, that should be all
-- that is needed to calculate terminal departure on time performance (OTP)
-- (taking into consideration that OTP should not be measured using extrapolated
-- times - indicated by source='S'/'E' in the calls tables).

-- To calculate the other metrics, a list of scheduled departures is required.
-- This information can be gleaned from the MTA's published GTFS feeds (archived
-- here and here). For your convenience, I've compiled and uploaded a complete
-- list of scheduled stop times and a date-to-trip lookup table (derived from GTFS
-- calendar files) covering the same period as the calls files. I've also uploaded
-- a schedule summary per route-stop-hour for each month. The schedule summaries
-- can be downloaded in the format
-- https://s3.amazonaws.com/data2.mytransit.nyc/bus_schedule/YYYY/schedule_YYYY-MM.
-- tsv.xz (again, for August 2014 to February 2016).

-- The additional schemas are:


CREATE TABLE IF NOT EXISTS schedule_hours (
    date date not null,
    rds_index smallint unsigned not null,
    hour tinyint not null,
    scheduled tinyint not null,
    pickups tinyint not null,
    exception tinyint not null,
    PRIMARY KEY (date, rds_index, hour)
);

CREATE TABLE IF NOT EXISTS hw_gtfs (
  `trip_index` int(11) NOT NULL,
  `rds_index` INTEGER NOT NULL,
  `datetime` datetime NOT NULL,
  `headway` MEDIUMINT UNSIGNED DEFAULT NULL,
  PRIMARY KEY k (trip_index, rds_index, datetime)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS hw_observed (
    `trip_index` int(11) NOT NULL,
    `rds_index` INTEGER NOT NULL,
    `datetime` datetime NOT NULL,
    `year` int(4) NOT NULL,
    `month` int(2) NOT NULL,
    `headway` SMALLINT UNSIGNED DEFAULT NULL,
    KEY `trip-rds-date` (`trip_index`, `rds_index`, `datetime`),
    INDEX yearmonth (`year`, `month`)
);

-- "schedule" (schedule summaries) shows the number of scheduled buses (which
-- includes arrivals/drop off only) and number of scheduled pickups (which should
-- generally be used for calculating metrics). It also includes a boolean column
-- (exception) indicating whether a route-stop-hour should be excepted from
-- measurement due to lack of data or a snowstorm/shutdown - this is the same
-- information as in the Exceptions table in the NYC Bus Performance Database.
-- bunching table
CREATE TABLE IF NOT EXISTS bunching (
  `month` date NOT NULL,
  `route_id` varchar(5),
  `direction_id` char(1),
  `stop_id` int(11),
  `period` int(1) NOT NULL,
  `weekend` int(1) NOT NULL,
  `call_count` SMALLINT(21) NOT NULL,
  `bunch_count` SMALLINT(21) NOT NULL,
  KEY rds (route, direction, stop_id),
  INDEX (month)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS bunching_averaged (
  `month` date NOT NULL,
  `route` varchar(5),
  `direction` char(1),
  `stop_id` int(11),
  `period` int(1) NOT NULL,
  `weekend` int(1) NOT NULL,
  `call_count` SMALLINT(21) NOT NULL,
  `bunch_count` SMALLINT(21) NOT NULL,
  KEY rds (route, direction, stop_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS adherence (
  date date not null,
  rds_index smallint unsigned not null,
  hour tinyint not null,
  observed tinyint not null, -- observed pickups
  early_5 tinyint not null,
  early_2 tinyint not null,
  early tinyint not null,
  on_time tinyint not null,
  late tinyint not null,
  late_10 tinyint not null,
  late_15 tinyint not null,
  late_20 tinyint not null,
  late_30 tinyint not null,
  PRIMARY KEY (date, rds_index, hour)
) ENGINE=MyISAM;

CREATE TABLE IF NOT EXISTS perf_ewt (
  month date not null,
  route_id varchar(255) not null,
  direction_id tinyint not null,
  stop_id int not null,
  weekend tinyint not null,
  period tinyint not null,
  scheduled_hf smallint not null,
  wswt int not null,
  observed_hf smallint not null,
  wawt int not null,
  PRIMARY KEY (month, route_id, direction_id, stop_id, weekend, period)
) ENGINE=MyISAM;

CREATE TABLE IF NOT EXISTS perf_service (
  month date not null, route_id varchar(255) not null,
  direction_id tinyint not null,
  stop_id int not null,
  weekend tinyint not null,
  period tinyint not null,
  hours smallint not null,
  scheduled smallint not null,
  observed smallint not null,
  PRIMARY KEY (month, route_id, direction_id, stop_id, weekend, period)
) ENGINE=MyISAM;

CREATE TABLE IF NOT EXISTS perf_otp (
  month date not null,
  route_id varchar(255) not null,
  direction_id tinyint not null,
  stop_id int not null,
  weekend tinyint not null,
  period tinyint not null,
  early smallint not null,
  on_time smallint not null,
  late smallint not null,
  PRIMARY KEY (month, route_id, direction_id, stop_id, weekend, period)) ENGINE=MyISAM;

CREATE TABLE IF NOT EXISTS perf_ewt (
  month date not null,
  route_id varchar(255) not null,
  direction_id tinyint not null,
  stop_id int not null,
  weekend tinyint not null,
  period tinyint not null,
  scheduled_hf smallint not null,
  wswt int not null,
  observed_hf smallint not null,
  wawt int not null,
  PRIMARY KEY (month, route_id, direction_id, stop_id, weekend, period)) ENGINE=MyISAM;

CREATE TABLE IF NOT EXISTS wtp (
  date date,
  rds_index int,
  hours smallint,
  w5 int not null,
  w10 int not null,
  w15 int not null,
  w20 int not null,
  w25 int not null,
  w30 int not null,
  PRIMARY KEY (date, rds_index, hour)
) ENGINE=MyISAM;

CREATE TABLE IF NOT EXISTS perf_wtp (
  month date not null,
  route_id varchar(255) not null,
  direction_id tinyint not null,
  stop_id int not null,
  weekend tinyint not null,
  period tinyint not null,
  hours_hf smallint not null,
  wtp_5 int not null,
  wtp_10 int not null,
  wtp_15 int not null,
  wtp_20 int not null,
  wtp_30 int not null,
  PRIMARY KEY (month, route_id, direction_id, stop_id, weekend, period)
) ENGINE=MyISAM;

-- All day is divided into five parts.
DROP FUNCTION IF EXISTS day_period;
CREATE FUNCTION day_period (d TIME)
    RETURNS INTEGER DETERMINISTIC
    RETURN CASE
        WHEN HOUR(d) BETWEEN 0 AND 6 THEN 5
        WHEN HOUR(d) BETWEEN 7 AND 9 THEN 1
        WHEN HOUR(d) BETWEEN 10 AND 15 THEN 2
        WHEN HOUR(d) BETWEEN 16 AND 18 THEN 3
        WHEN HOUR(d) BETWEEN 19 AND 22 THEN 4
        WHEN HOUR(d) >= 23 THEN 5
    END;

DROP FUNCTION IF EXISTS day_period_hour;
CREATE FUNCTION day_period_hour (h INTEGER)
    RETURNS INTEGER DETERMINISTIC
    RETURN CASE
        WHEN h BETWEEN 0 AND 6 THEN 5
        WHEN h BETWEEN 7 AND 9 THEN 1
        WHEN h BETWEEN 10 AND 15 THEN 2
        WHEN h BETWEEN 16 AND 18 THEN 3
        WHEN h BETWEEN 19 AND 22 THEN 4
        WHEN h >= 23 THEN 5
    END;


DROP FUNCTION IF EXISTS depart_time;
CREATE FUNCTION depart_time(call_time DATETIME, dwell_time INTEGER)
    RETURNS DATETIME DETERMINISTIC
    RETURN IF(dwell_time IS NULL,
      NULL,
      IF(dwell_time > 0, TIMESTAMPADD(SECOND, dwell_time, call_time), call_time)
    );

DROP PROCEDURE IF EXISTS add_dates;
DELIMITER $$
CREATE PROCEDURE add_dates(start_date DATE, end_date DATE)
BEGIN
    DROP TABLE IF EXISTS ref_dates;
    CREATE TABLE ref_dates (date DATE);
    label1: LOOP
        INSERT into ref_dates VALUES (start_date);
        SET start_date = DATE_ADD(start_date, INTERVAL 1 DAY);
        IF start_date <= end_date THEN ITERATE label1; END IF;
        LEAVE label1;
    END LOOP label1;
END $$
DELIMITER ;
