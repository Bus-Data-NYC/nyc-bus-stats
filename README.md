# nyc-bus-stats

Calculate certain statistics on New York City bus calls data.

## Requirements

* bash or another *nix shell
* Make
* Postgres

## Organization and syntax

This repo uses a Makefile to organize the tasks that go into performing different statistics. The actual calculations are done by the Postgres server.

### Learn just enough make in 144 words

Make is a program that runs recipes, which are organized sets of tasks that lead to particular outcome, like a file. The tasks are written down in a Makefile. A `make` command has the syntax `make recipename`, where *recipename* is task you want make to perform (or a file to create). You can tune the way a Makefile runs by setting variables. To set a variable named `BRONX` to `nothonx`, use this syntax: `make recipename BRONX=nothonx`. By convention, variables in make are generally all uppercase.

The main Makefile in this repo is `Makefile`. A secondary file is named `gtfs.mk`. You can tell make to run commands in a given Makefile with the `-f` flag: `make recipename -f gtfs.mk`.

If you want to see what a `make` command will do without touching anything, use the `--dry-run` flag: `make recipename --dry-run`.

### Running stats for a particular date

In general, stats are run for a particular release of GTFS data or a month of calls data. There are two `make` variables that allow you to tune these options. The are named `GTFSVERSION` and `MONTH`. `GTFSVERSION` will generally be a particular date that a version of the MTA's GTFS data was released. For our purposes, it's written in the format `YYYYMMDD`, e.g: `GTFSVERSION=20150906`.

The `MONTH` variable is in a different format: YYYY-MM, e.g: `MONTH=2015-10`.

## Loading calls data into MySQL

To run most stats, you must have MySQL available on your local machine. By default the database is named `turnaround` and the MySQL username is assumed to be your shell username. You can specify the mysql settings with make variables: 
```
make init USER=myusername
make init DATABASE=mydatabase
make init USER=myusername PASS=mypassword
```

This sets up the Postgres database and downloads stop and trip data into it:
```
make init
```


## Statistics

As with loading data, each command runs on one month's worth of data at a time. To set the month, use the `MONTH` variable:
```
make bunch MONTH=2015-10
```

### Bus bunching

```
make bunch MONTH=2015-10
```

This will generate a file named `stats/2015-10-bunching.csv`, with the bunching stats for all route/stops/directions in the given month.

### On Time Departure

This calculates the percentage of buses in excess of three minutes behind schedule as of the third stop on each route.

```
make otd GTFSVERSION=yyyymmdd
```

### Conservative EWT

This stat examines excess wait time at the stop level, omitting any 'missing' buses from the analysis.

```
make cewt MONTH=2015-10
```

This will create a file named `stats/2015-10-cewt.csv`.

### Stop spacing

Stop spacing measures the average distance between stops. Requires Spatialite and Sqlite3. Creates a file called `stats/GTFSVERSION_stop_spacing_avg.csv`.

```
make spacing GTFSVERSION=yyyymmdd
````

### Route circuitousness

This stat measures how indirect is the path of a given route relative to a straight line between the route's endpoints. The calculation uses `gtfs2geojson` (a node utility) and `ogr2ogr`, part of GDAL/OGR.
```
make routeratio GTFSVERSION=yyyymmdd
```

This will create a file named `stats/yyyymmdd-route-ratios.csv`.

### Route-level EVT
The "excess in-vehicle time" is the difference between scheduled and actual trip times for a route. This is measured using the Conservative EWT tables.
```
make 
```

### Wait Time probability

The chance of waiting less than 5, 10, 15, 20, or 30 minutes when arriving at a bus stop at random. Groups data by route, direction, stop, period and weekday/weekend.

```
make wtp MONTH=2017-09
```

* `wtp_5`, `wtp_10`, `wtp_15`, `wtp_20`, `wtp_30`: the percentage chance of waiting less than 5, 10, 15, 20, or 30 minutes when arriving at a bus stop at random during high frequency scheduled service
* `calls`: the number of calls captured in each period

## Notes & etc

Number of distinct rds_index (route-direction-stop) (calls_2015-10): 25,262

Date-trips in 2015-10: 1,471,140

Stop times in 2015-10: 56,485,803

## License

Copyright 2017 TransitCenter. Made available under the Apache 2.0 license.

Developer: [Neil Freeman](http://fakeisthenewreal.org) [@fitnr](http://twitter.com/fitnr)
