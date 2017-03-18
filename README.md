# nyc-bus-stats

Calculate certain statistics on New York City bus calls data.

## Requirements

* bash or another *nix shell
* Make
* MySQL
* [csvkit](https://github.com/wireservice/csvkit)
* SQLite and Spatialite (for stop spacing)
* GDAL/OGR (for route length ratios)
* [gtfs2geojson](https://github.com/andrewharvey/gtfs2geojson)

## Organization and syntax

This repo uses a Makefile to organize the tasks that go into performing different statistics. Most of the actual calculations are done by MySQL or SQLite. 

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
(MySQL will warn you if you use your password this way, but it will save you time. Don't do this if you use your MySQL password for any other accounts.)

This sets up the MySQL database and downloads stop and trip data into it:
```
make init
```

This command will attempt to download the following from `https://s3.amazonaws.com/data2.mytransit.nyc`:
````
lookups/rds_indexes.tsv
lookups/trip_indexes.tsv
schedule/date_trips.tsv
schedule/stop_times.tsv
````

Load calls for a specific month into the MySQL database with:
`make init-month MONTH=2015-10`

This will attempt to download that month's calls data from `https://s3.amazonaws.com/data2.mytransit.nyc`.

### GTFS

The `gtfs.mk` Makefile will download the current MTA bus GTFS files, merge them, and place them in a folder called `gtfs/yyymmdd/`, where `yyymmdd` reflects the current date. This date string is the `GTFSVERSION`, and can be set in other commands to specify a particular version of GTFS data.

It's important to note that the MTA GTFS data includes six sets of files: one for each borough and the MTA Bus Company. Some archived versions of the GTFS data combine these into two sets of files (NYCT Bus and the Bus Co.).

The `gtfs.mk` file has a task for combining sets of files like this. Let's say that the files are in two zip archives named `gtfs_busco_20150906.zip` and `gtfs_nyct_20150906.zip`. Place them in `gtfs/20150906` and run:
```
make -f gtfs.mk GTFSES="gtfs_busco_20150906 gtfs_nyct_20150906" GTFSVERSION=20161020`
```

Processing the GTFS can be somewhat slow. Because the MTA doesn't release the NYCT Bus and Bus Company files with the same column layout, they are combined with `csvkit`, which is less efficient than standard shell tools.

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

## Notes & etc

Number of distinct rds_index (route-direction-stop) (calls_2015-10): 25,262

Date-trips in 2015-10: 1,471,140

Stop times in 2015-10: 56,485,803

## License

Copyright 2017 TransitCenter. Made available under the Apache 2.0 license.

Developer: [Neil Freeman](http://fakeisthenewreal.org) [@fitnr](http://twitter.com/fitnr)
