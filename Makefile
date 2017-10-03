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

PG_DATABASE = nycbus
PSQLFLAGS = $(PG_DATABASE)

ifdef PG_HOST
PSQLFLAGS += -h $(PG_HOST)
endif

ifdef PG_PORT
PSQLFLAGS += -p $(PG_PORT)
endif

ifdef PG_USER
PSQLFLAGS += -U $(PG_USER)
endif

PSQL = psql $(PSQLFLAGS)

GTFSSTATS = routeratio spacing stopdist
CALLSTATS = evt cewt otp otd bunching service speed

MONTH = 2016-10
FEED = 1

OUTOPTS = TO STDOUT CSV HEADER DELIMITER '	'

.PHONY: all init $(CALLSTATS) $(GTFSSTATS)

all:

#
# Call-based stats
#
$(CALLSTATS): %: stats/$(MONTH)-%.tsv.gz

$(foreach x,$(CALLSTATS),stats/$(MONTH)-$x.tsv.gz): stats/$(MONTH)-%.tsv.gz: | stats
	$(PSQL) -c "INSERT INTO stat_$* SELECT * FROM get_$*('$(MONTH)-01'::date) ON CONFLICT DO NOTHING"
	$(PSQL) -c "COPY (SELECT * FROM stat_$* WHERE month = '$(MONTH)-01'::date) $(OUTOPTS)" \
		| gzip - > $@

#
# Feed-based stats
#
$(GTFSSTATS): %: stats/$(FEED)-%.tsv.gz

$(foreach x,$(GTFSSTATS),stats/$(FEED)-$x.tsv.gz): stats/$(FEED)-%.tsv.gz: | stats
	$(PSQL) -c "INSERT INTO stat_$* SELECT * FROM get_$*(string_to_array('$(FEED)', '-')) ON CONFLICT DO NOTHING"
	$(PSQL) -c "COPY (SELECT * FROM stat_$* WHERE ARRAY[feed_index::text] <@ string_to_array('$(FEED)', '-')) $(OUTOPTS)" \
		| gzip - > $@

sql = $(foreach x,schema functions gtfs $(CALLSTATS),sql/$x.sql)

# Calculate headway for the given month.
prepare: headway-observed headway-scheduled

headway-%:
	$(PSQL) -c "INSERT INTO stat_headway_$* \
		SELECT * FROM get_headway_$*('$(MONTH)-01'::date, INTERVAL '1 MONTH') ON CONFLICT DO NOTHING"

init: $(sql)
	$(PSQL) $(foreach x,$^,-f $x)

stats: ; mkdir -p $@
