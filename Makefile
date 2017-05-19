# Copyright 2017 TransitCenter
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at 
#   http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SERVER = https://s3.amazonaws.com/data2.mytransit.nyc
MYSQLFLAGS = -u $(USER) -p$(PASS)
DATABASE = turnaround
MYSQL = mysql $(DATABASE) $(MYSQLFLAGS)

GTFSVERSION = 20150906
MONTH = 2015-10

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

.PHONY: all init init-$(MONTH) mysql-calls mysql-calls-% mysql-schedule-% \
	bunch otd evt routeratio spacing

all:

#
# EVT (excess in-vehicle time)
#

ROUTES = $(shell cat routes.txt)
routes = $(foreach s,$(ROUTES),stats/evt/$s.tsv)

evt: stats/$(MONTH)-evt.csv

stats/$(MONTH)-evt.csv: $(routes)
	csvstack -t $^ > $@

$(routes): stats/evt/%.tsv: sql/evt_route.sql | stats/evt
	{ echo "SET @the_month=\'$(MONTH)-01\', @the_route=\'$*\'\;" ; cat $^ ; } | \
	$(MYSQL) > $@

routes.txt: gtfs/$(GTFSVERSION)/routes.txt
	csvcut -c 1 $< | tail -n+2 | sort -u | tr '\n' ' ' | fold -sw80 > $@

#
# Conservative EWT
#
cewt: stats/$(MONTH)-cewt.csv

stats/$(MONTH)-cewt.csv: sql/ewt_conservative.sql
	{ echo "SET @the_month=\'$(MONTH)-01\';" ; cat $^ ; } | \
	$(MYSQL)
	$(MYSQL) -e "SELECT * FROM cewt_avg" > $@

#
# Stop Spacing
#

spacing: stats/$(GTFSVERSION)_stop_spacing_avg.csv

stats/$(GTFSVERSION)_stop_spacing_avg.csv: stats/stop_spacing.db
	sqlite3 -csv -header $< 'SELECT route, direction, \
		ROUND(SUM(spacing_m) / COUNT(*) - 1) avg_spacing_m \
		FROM stop_spacing \
		GROUP BY route, direction;' > $@

stats/stop_spacing.db: lookups/rds_indexes.tsv sql/stop_spacing.sql gtfs/$(GTFSVERSION)/stops.txt | stats
	@rm -f $@
	spatialite $@ ''
	sqlite3 $@ 'CREATE TABLE rds_indexes (rds_index INTEGER, route VARCHAR, direction CHAR(1), stop_id INTEGER); \
		CREATE TABLE stops (stop_id INTEGER, stop_name VARCHAR, stop_desc VARCHAR, stop_lat FLOAT, stop_lon FLOAT)';
	sqlite3 -separator '	' $@ '.import $< rds_indexes'
	sqlite3 -separator , $@ '.import gtfs/$(GTFSVERSION)/stops.txt stops' 2> /dev/null
	spatialite -header -csv $@ < sql/stop_spacing.sql

#
# Route Ratios
#
routeratio: stats/$(GTFSVERSION)-route-ratios.csv

stats/$(GTFSVERSION)-route-ratios.csv: gtfs/$(GTFSVERSION)/shapes.geojson gtfs/$(GTFSVERSION)/trips.dbf | stats
	@rm -f $@
	ogr2ogr $@ $< -f CSV -overwrite -dialect sqlite \
		-sql "SELECT DISTINCT t.route_id, shape.shape_id, service_id, \
		ROUND(ST_Length(shape.Geometry, 1) / ST_Distance(StartPoint(shape.Geometry), EndPoint(shape.Geometry), 1), 2) crow_ratio, \
		ROUND(ST_Length(shape.Geometry, 1) / ST_Length(simp.Geometry, 1), 2) simple_ratio \
		FROM OGRGeoJSON shape \
		LEFT JOIN '$(word 2,$(^D))'.trips t ON (t.shape_id = shape.id) \
		SORT BY crow_ratio DESC"

gtfs/$(GTFSVERSION)/trips.dbf: gtfs/$(GTFSVERSION)/trips.csv
	ogr2ogr $@ $<

gtfs/$(GTFSVERSION)/shapes.geojson: gtfs/$(GTFSVERSION)
	node_modules/.bin/gtfs2geojson -o $(@D) $<

#
# on time departure
#
otd: stats/$(MONTH)-otd.csv

stats/$(MONTH)-otd.csv: stats/%-otd.csv: sql/on_time_departure.sql | stats
	{ echo "SET @the_month=\'$*-01\'\;" ; cat $^ ; } | \
	$(MYSQL) > $@

#
# Bus bunching
#
bunch: stats/$(MONTH)-bunching.csv

stats/$(MONTH)-bunching.csv: sql/headway_observed.sql sql/headway_sched.sql sql/bunching.sql sql/bunching_average.sql
	{ echo "SET @the_month=\'$*-01\'\;" ; cat $^ ; } | \
	$(MYSQL)
	$(MYSQL) -e "SELECT * FROM bunching_average" > $@

#
# Insert calls data for a particular month
#
init-month: init-$(MONTH)
init-$(MONTH): init-%: mysql-calls-% mysql-schedule-%

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

install:
	pip install --user -r requirements.txt
	npm i andrewharvey/gtfs2geojson

calls schedule trips stats stats/evt:; mkdir -p $@
