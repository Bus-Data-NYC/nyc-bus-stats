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

DATABASE = nycbus
PFLAGS =
PSQL = psql $(DATABASE) $(PFLAGS)

GTFSSTATS = routeratio stopspacing 
CALLSTATS = evt cewt otp otd bunching service speed

MONTH = 2016-10-01
FEED = 1

.PHONY: all init $(CALLSTATS) $(GTFSSTATS)

all:

#
# Call-based stats
#
$(CALLSTATS): %: stats/$(MONTH)-%.csv.gz

$(foreach x,$(CALLSTATS),stats/$(MONTH)-$x.csv.gz): stats/$(MONTH)-%.csv.gz: | stats
	$(PSQL) -c "INSERT INTO stat_$* get_$*('$(MONTH)-01'::date) ON CONFLICT DO NOTHING"
	$(PSQL) -c "SELECT * FROM stat_$* WHERE month = '$(MONTH)-01'::date" | gzip - > $@

#
# Feed-based stats
#
$(GTFSSTATS): %: stats/$(FEED)-%.csv.gz

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

sql = sql/schema.sql \
	sql/functions.sql \
	$(foreach x,$(CALLSTATS) $(GTFSSTATS),sql/$x.sql)

init: $(sql)
	$(PSQL) $(foreach x,$^,-f $x)

stats: ; mkdir -p $@
