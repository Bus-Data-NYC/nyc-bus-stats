SERVER = https://s3.amazonaws.com/data2.mytransit.nyc
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

.PHONY: all init mysql-calls-% bunch-% otd-%

all:

spacing/stop_spacing_avg.csv: spacing/stop_spacing.db sql/stop_spacing_avg.sql
	sqlite3 -csv -header $< 'SELECT route, direction, \
	ROUND(SUM(spacing_m) / COUNT(*) - 1) avg_spacing_m \
	FROM stop_spacing \
	GROUP BY route, direction;' > $@

spacing/stop_spacing.db: lookups/rds_indexes.tsv sql/stop_spacing.sql gtfs/gtfs_mtabc_20150906/stops.txt gtfs/gtfs_nyct_bus_20150905/stops.txt
	@rm -f $@
	spatialite $@ ''
	sqlite3 $@ 'CREATE TABLE rds_indexes (rds_index INTEGER, route VARCHAR, direction CHAR(1), stop_id INTEGER); \
		CREATE TABLE stops (stop_id INTEGER, stop_name VARCHAR, stop_desc VARCHAR, stop_lat FLOAT, stop_lon FLOAT)';
	sqlite3 -separator '	' $@ '.import $< rds_indexes'
	sqlite3 -separator , $@ '.import gtfs/gtfs_mtabc_20150906/stops.txt stops'
	csvcut -c stop_id,stop_name,stop_desc,stop_lat,stop_lon gtfs/gtfs_nyct_bus_20150905/stops.txt | \
		sqlite3 -separator , $@ '.import /dev/stdin stops'
	spatialite -header -csv $@ < sql/stop_spacing.sql

gtfs/bus_route_ratios.csv: gtfs/bus_ratios_mtabc_20150906.csv gtfs/bus_ratios_nyct_bus_20150905.csv
	csvstack $^ | \
	sort -ru | \
	csvsort -rc simple_ratio > $@

gtfs/bus_ratios_%.csv: gtfs/gtfs_%/shapes.geojson gtfs/gtfs_%/trips.dbf gtfs/simplified_shapes.shp
	@rm -f $@
	ogr2ogr $@ $< -f CSV -overwrite -dialect sqlite \
		-sql "SELECT DISTINCT t.route_id, shape.shape_id, service_id, \
		ROUND(ST_Length(shape.Geometry, 1) / ST_Distance(StartPoint(shape.Geometry), EndPoint(shape.Geometry), 1), 2) crow_ratio, \
		ROUND(ST_Length(shape.Geometry, 1) / ST_Length(simp.Geometry, 1), 2) simple_ratio \
		FROM OGRGeoJSON shape \
		LEFT JOIN '$(word 2,$(^D))'.trips t ON (t.shape_id = shape.id) \
		LEFT JOIN $(word 3,$(^D)).bus_shapes simp ON (simp.id = shape.id)"

gtfs/gtfs_%/trips.dbf: gtfs/gtfs_%/trips.csv
	ogr2ogr $@ $<

gtfs/gtfs_%/trips.csv: gtfs/gtfs_%/trips.txt
	csvcut -c route_id,service_id,shape_id $< | \
	csvgrep -c service_id -m Weekday | \
	sort -ru > $@

gtfs/simplified_shapes.shp: gtfs/gtfs_nyct_bus_20150905/shapes.geojson gtfs/gtfs_mtabc_20150906/shapes.geojson
	ogr2ogr -f 'ESRI Shapefile' -overwrite -simplify 0.01 $@ $<
	ogr2ogr -f 'ESRI Shapefile' -update -append -simplify 0.01 $@ $(word 2,$^)

# on time departure
on_time_departure/%-otd.csv: sql/on_time_departure.sql | on_time_departure
	{ echo SET @the_month=\'$*-01\'\; ; cat $^ ; } | \
	$(MYSQL) > $@

bunch-%: sql/headway.sql sql/bunching_observed.sql sql/bunching_sched.sql
	{ echo SET @the_month=\'$*-01\'\; ; cat $^ ; } | \
	$(MYSQL)

mysql-calls-%: calls/%.tsv
	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE '$(<)' INTO TABLE calls \
		FIELDS TERMINATED BY '\t' ($(CALL_FIELDS))"

mysql-schedule-%: schedule/schedule_%.tsv
	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE '$(<)' INTO TABLE schedule \
		FIELDS TERMINATED BY '\t' ($(SCHEDULE_FIELDS))"

.INTERMEDIARY: %.tsv

%.tsv: %.tsv.xz; unxz $<

.PRECIOUS: calls/%.tsv.xz schedule/%.tsv.xz

# Calls data available for 2014-08 to 2016-02
# format: $(SERVER)/bus_calls/YYYY/calls_YYYY-MM.tsv.xz
calls/%.tsv.xz: | calls
	curl -o $@ $(SERVER)/bus_calls/$(word 1,$(subst -, ,$*))/calls_$*.tsv.xz

schedule/%.tsv.xz: | schedule
	curl -o $@ $(SERVER)/bus_schedule/$*.tsv.xz

# Schedules available for 2014-08 to 2016-02
# format: $(SERVER)/bus_schedule/YYYY/schedule_YYYY-MM.tsv.xz
schedule/schedule_%.tsv.xz: | schedule
	curl -o $@ $(SERVER)/bus_schedule/$(word 1,$(subst -, ,$*))/schedule_$*.tsv.xz

lookups/%.tsv.xz:
	curl -o $@ $(SERVER)/bus_calls/$*.tsv.xz

init: sql/create.sql lookups/rds_indexes.tsv lookups/trip_indexes.tsv schedule/date_trips.tsv schedule/stop_times.tsv
	$(MYSQL) < $<

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'lookups/rds_indexes.tsv' INTO TABLE rds_indexes \
		FIELDS TERMINATED BY '\t' (rds_index, route, direction, stop_id)"

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'lookups/trip_indexes.tsv' INTO TABLE trip_indexes \
		FIELDS TERMINATED BY '\t' (trip_index, gtfs_trip)"

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'schedule/date_trips.tsv' INTO TABLE date_trips \
		FIELDS TERMINATED BY '\t' (date, trip_index)"

	$(MYSQL) --local-infile \
		-e "LOAD DATA LOCAL INFILE 'schedule/stop_times.tsv' INTO TABLE stop_times \
		FIELDS TERMINATED BY '\t' \
		(trip_index, time, time_public, stop_id, stop_sequence, pickup_type, drop_off_type, rds_index)"

calls schedule trips on_time_departure:; mkdir -p $@
