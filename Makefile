SERVER = https://s3.amazonaws.com/data2.mytransit.nyc
YEAR := $(word 1,$(subst -, ,$*))
MYSQLFLAGS = -u $(USER) -p$(PASS)
DATABASE = turnaround
MYSQL = mysql $(DATABASE) $(MYSQLFLAGS)

CALL_FIELDS = vehicle_id, \
	trip_index, \
	stop_sequence, \
	call_time, \
	dwell_time, \
	source, \
	rds_index, \
	deviation

SCHEDULE_FIELDS = date, \
	rds_index, \
	hour, \
	scheduled, \
	pickups, \
	exception

.PHONY: all init mysql-calls-%

all:

mysql-calls-%: calls/%.tsv
	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE '$(<)' INTO TABLE $(DATABASE).calls \
		FIELDS TERMINATED BY '\t' ($(CALL_FIELDS))"

mysql-schedule-%: schedule/schedule_%.tsv
	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE '$(<)' INTO TABLE $(DATABASE).schedule \
		FIELDS TERMINATED BY '\t' ($(SCHEDULE_FIELDS))"

.INTERMEDIARY: %.tsv

%.tsv: %.tsv.xz; unxz $<

.PRECIOUS: calls/%.tsv.xz schedule/%.tsv.xz

# Calls data available for 2014-08 to 2016-02
# format: $(SERVER)/bus_calls/YYYY/calls_YYYY-MM.tsv.xz
calls/%.tsv.xz: | calls
	curl -o $@ $(SERVER)/bus_calls/$(YEAR)/calls_$*.tsv.xz

# Schedules available for 2014-08 to 2016-02
# format: $(SERVER)/bus_schedule/YYYY/schedule_YYYY-MM.tsv.xz
schedule/schedule_%.tsv.xz: | schedule
	curl -o $@ $(SERVER)/bus_schedule/$(YEAR)/schedule_$*.tsv.xz

schedule/date_trips.tsv.xz: | schedule; curl -o $@ $(SERVER)/bus_schedule/date_trips.tsv.xz

schedule/stop_times.tsv.xz: | schedule; curl -o $@ $(SERVER)/bus_schedule/stop_times.tsv.xz

## gtfs

mysql-gtfs-%: sql/gtfs.sql gtfs/%/calendar.txt gtfs/%/stop_times.txt gtfs/%/trips.txt
	$(MYSQL) < $<

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'gtfs/$*/stop_times.txt' INTO TABLE $(DATABASE).stop_times_gtfs \
		FIELDS TERMINATED BY ',' IGNORE 1 LINES \
		(trip_id, arrival_time, departure_time, stop_id, stop_sequence, pickup_type, drop_off_type)"

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'gtfs/$*/trips.txt' INTO TABLE $(DATABASE).trips_gtfs \
		FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' \
		LINES TERMINATED BY '\n' IGNORE 1 LINES \
		(route_id, service_id, trip_id, trip_headsign, direction_id, shape_id, @null)"

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'gtfs/$*/calendar.txt' INTO TABLE $(DATABASE).calendar_gtfs \
		FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 LINES \
		(service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, @end) \
		SET end_date=INSERT(INSERT(@end, 7, 0, '-'), 5, 0, '-')"

gtfs/%/calendar.txt gtfs/%/stop_times.txt gtfs/%/trips.txt: gtfs/%.zip
	@mkdir -p gtfs/$*
	unzip -jnd $(@D) $< stop_times.txt trips.txt calendar.txt

init: sql/create.sql lookups/rds_indexes.tsv lookups/trip_indexes.tsv schedule/date_trips.tsv schedule/stop_times.tsv
	$(MYSQL) < $<

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'lookups/rds_indexes.tsv' INTO TABLE $(DATABASE).rds_indexes \
		FIELDS TERMINATED BY '\t' (rds_index, route, direction, stop_id)"

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'lookups/trip_indexes.tsv' INTO TABLE $(DATABASE).trip_indexes \
		FIELDS TERMINATED BY '\t' (trip_index, gtfs_trip)"

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'trips/date_trips.tsv' INTO TABLE $(DATABASE).date_trips \
		FIELDS TERMINATED BY '\t' (date, trip_index)"

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'trips/stop_times.tsv' INTO TABLE $(DATABASE).stop_times \
		FIELDS TERMINATED BY '\t' \
		(trip_index, time, time_public, stop_id, stop_sequence, pickup_type, drop_off_type, rds_index)"

calls schedule trips:; mkdir -p $@
