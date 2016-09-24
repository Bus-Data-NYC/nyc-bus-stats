SERVER = https://s3.amazonaws.com/data2.mytransit.nyc
YEAR := $(word 1,$(subst -, ,$*))
MYSQLFLAGS = -u $(USER) -p $(PASS)
DATABASE = turnaround

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
	mysql $(DATABASE) $(MYSQLFLAGS) --local-infile \
		-e "LOAD DATA LOCAL INFILE '$(<)' INTO TABLE $(DATABASE).calls \
		FIELDS TERMINATED BY '\t' ($(CALL_FIELDS))"

mysql-schedule-%: schedule/%.tsv
	mysql $(DATABASE) $(MYSQLFLAGS) --local-infile \
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
schedule/%.tsv.xz: | schedule
	curl -o $@ $(SERVER)/bus_schedule/$(YEAR)/schedule_$*.tsv.xz

init: sql/create.sql lookups/rds_indexes.tsv lookups/trip_indexes.tsv
	mysql $(DATABASE) $(MYSQLFLAGS) < $<

	mysql $(DATABASE) $(MYSQLFLAGS) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'lookups/rds_indexes.tsv' INTO TABLE $(DATABASE).rds_indexes \
		FIELDS TERMINATED BY '\t' (stop_sequence, route, direction, rds_index)"

	mysql $(DATABASE) $(MYSQLFLAGS) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'lookups/trip_indexes.tsv' INTO TABLE $(DATABASE).trip_indexes \
		FIELDS TERMINATED BY '\t' (trip_index, gtfs_trip)"

calls schedule:; mkdir -p $@
