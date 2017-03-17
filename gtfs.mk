shell = bash

BASE = http://web.mta.info/developers/data

files = routes shapes stop_times stops trips

GTFSVERSION ?= $(shell date +"%Y%m%d")

GTFSES = $(addprefix google_transit_,bronx brooklyn manhattan queens staten_island busco)

NYCTFILES = $(foreach x,bronx brooklyn manhattan queens staten_island,gtfs/$(GTFSVERSION)/google_transit_$x.zip)

GTFSFILES = $(foreach x,$(files),gtfs/$(GTFSVERSION)/$x.txt)

.PHONY: gtfs 

gtfs: $(GTFSFILES)

gtfs/$(GTFSVERSION)/%.txt: $(foreach x,$(GTFSES),gtfs/$(GTFSVERSION)/$x/%.txt)
	csvstack $^ > $@

.SECONDEXPANSION:

files_by_gtfs = $(foreach d,$(GTFSES),$(foreach f,$(files),gtfs/$(GTFSVERSION)/$d/$f.txt))

$(files_by_gtfs): gtfs/$(GTFSVERSION)/%.txt: gtfs/$(GTFSVERSION)/$$(*D).zip | $$(@D)
	unzip -oqd $(@D) $< $(@F)
	@touch $@

$(NYCTFILES): gtfs/$(GTFSVERSION)/%.zip: | gtfs/$(GTFSVERSION)
	curl $(BASE)/nyct/bus/$*.zip -o $@

gtfs/$(GTFSVERSION)/google_transit_busco.zip: | gtfs/$(GTFSVERSION)
	curl $(BASE)/busco/google_transit.zip -o $@

gtfs/$(GTFSVERSION) $(addprefix gtfs/$(GTFSVERSION)/,$(GTFSES)):; mkdir -p $@
