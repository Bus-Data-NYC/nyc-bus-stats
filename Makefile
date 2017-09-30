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

GTFSSTATS = routeratio spacing stopdist
CALLSTATS = evt cewt otp otd bunching service speed

MONTH = 2016-10
FEED = 1

.PHONY: all init $(CALLSTATS) $(GTFSSTATS)

all:

#
# Call-based stats
#
$(CALLSTATS): %: stats/$(MONTH)-%.csv.gz

$(foreach x,$(CALLSTATS),stats/$(MONTH)-$x.csv.gz): stats/$(MONTH)-%.csv.gz: | stats
	$(PSQL) -c "INSERT INTO stat_$* SELECT * FROM get_$*('$(MONTH)-01'::date) ON CONFLICT DO NOTHING"
	$(PSQL) -c "SELECT * FROM stat_$* WHERE month = '$(MONTH)-01'::date" | gzip - > $@

#
# Feed-based stats
#
$(GTFSSTATS): %: stats/$(FEED)-%.csv.gz

$(foreach x,$(GTFSSTATS),stats/$(FEED)-$x.csv.gz): stats/$(FEED)-%.csv.gz: | stats
	$(PSQL) -c "INSERT INTO stat_$* SELECT * FROM get_$*(string_to_array('$(FEED)', '-')) ON CONFLICT DO NOTHING"
	$(PSQL) -c "SELECT * FROM stat_$* WHERE ARRAY[feed_index::text] <@ string_to_array('$(FEED)', '-')" | gzip - > $@

sql = $(foreach x,schema functions gtfs $(CALLSTATS),sql/$x.sql)

# Calculate headway for the given month.
prepare: headway-observed headway-scheduled

headway-%:
	$(PSQL) -c "INSERT INTO stat_headway_$* (trip_id, stop_id, date, headway) \
		SELECT trip_id, stop_id, date, headway \
		FROM get_headway_$*('$(MONTH)-01'::date, INTERVAL '1 MONTH') ON CONFLICT DO NOTHING"

init: $(sql)
	$(PSQL) $(foreach x,$^,-f $x)

stats: ; mkdir -p $@
