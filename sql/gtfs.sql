CREATE TABLE IF NOT EXISTS `trips_gtfs` (
    `route_id` varchar(5) DEFAULT NULL,
    `service_id` varchar(64) DEFAULT NULL,
    `trip_id` varchar(64) DEFAULT NULL,
    `trip_headsign` varchar(128) DEFAULT NULL,
    `direction_id` char(1) DEFAULT NULL,
    `shape_id` varchar(8) DEFAULT NULL,
    `rowid` int(11) unsigned NOT NULL,
    KEY `trip_id` (`trip_id`),
    KEY `rowid` (`rowid`),
    KEY `service_id` (`service_id`, `route_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `stop_times_gtfs` (
    `trip_id` varchar(64) DEFAULT NULL,
    `arrival_time` time DEFAULT NULL,
    `departure_time` time DEFAULT NULL,
    `stop_id` int(11) DEFAULT NULL,
    `stop_sequence` tinyint(4) DEFAULT NULL,
    `pickup_type` char(1) DEFAULT NULL,
    `drop_off_type` char(1) DEFAULT NULL,
    KEY `trip_id` (`trip_id`, `stop_id`, `stop_sequence`),
    KEY `time` (`arrival_time`),
    KEY `stop` (`stop_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `headways_gtfs` (
    `rowid` int(11) unsigned NOT NULL,
    `route_id` varchar(5) DEFAULT NULL,
    `direction_id` tinyint(1) DEFAULT NULL, 
    `stop_id` int(11) DEFAULT NULL,
    `stop_sequence` tinyint(4) DEFAULT NULL,
    `trip_id` varchar(64) DEFAULT NULL,
    `prev_arrival_time` time DEFAULT NULL,
    `arrival_time` time DEFAULT NULL,
    `headway` double DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
