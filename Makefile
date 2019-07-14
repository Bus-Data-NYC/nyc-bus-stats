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

PGDATABASE ?= $(USER)
PGUSER ?= $(USER)

PSQL = psql $(PGDATABASE)

GTFSSTATS = routeratio spacing stopdist
CALLSTATS = evt cewt otp otd bunching service speed wtp

MONTH = 2016-10
FEED = 1
INTERVAL = 1 MONTH

OUTOPTS = TO STDOUT CSV HEADER DELIMITER '	'

comma = ,

.PHONY: all init $(CALLSTATS) $(GTFSSTATS)

all:

#
# Call-based stats
#
$(CALLSTATS): %: stats/$(MONTH)-%.tsv.gz

$(foreach x,$(CALLSTATS),stats/$(MONTH)-$x.tsv.gz): stats/$(MONTH)-%.tsv.gz: | stats
	$(PSQL) -c "INSERT INTO stat.$* SELECT DATE '$(MONTH)-01' as month, * FROM get_$*('$(MONTH)-01', '$(INTERVAL)') ON CONFLICT DO NOTHING"
	$(PSQL) -c "COPY (SELECT * FROM stat.$* WHERE month = '$(MONTH)-01') $(OUTOPTS)" \
		| gzip - > $@

#
# Feed-based stats
#
$(GTFSSTATS): %: stats/$(FEED)-%.tsv.gz

$(foreach x,$(GTFSSTATS),stats/$(FEED)-$x.tsv.gz): stats/$(FEED)-%.tsv.gz: | stats
	$(PSQL) -c "INSERT INTO stat.$* SELECT * FROM get_$*(ARRAY[$(subst -,$(comma),$(FEED))]) ON CONFLICT DO NOTHING"; \
	$(PSQL) -c "COPY (SELECT * FROM stat.$* WHERE feed_index = ANY(ARRAY[$(subst -,$(comma),$(FEED))])) $(OUTOPTS)" \
		| gzip - > $@


# Calculate headway for the given month.
prepare: headway-observed headway-scheduled

headway-%:
	$(PSQL) -c "INSERT INTO stat.headway_$* \
		SELECT * FROM get_headway_$*('$(MONTH)-01', '$(INTERVAL)') ON CONFLICT DO NOTHING"

init: schema.sql
	$(PSQL) -f $<

schema.sql: $(foreach x,tables util gtfs $(CALLSTATS),sql/$x.sql)
	cat $^ > $@

stats: ; mkdir -p $@
