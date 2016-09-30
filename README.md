### Loading data

Run to download stop and trip data into a database name `turnaround`.
```
make init
```

Assuming you have a file named `calls/2015-10.tsv`:
```
make mysql-calls-2015-10
```

Then run:
```
make bunch-2015-10
```

Change the last part of the command to any YYYY-MM for which you have data.

These commands will assume your `mysql` username is the same as your system username. If that's not the case:
```
make mysql-calls-2015-10 USER=myusername
```

To specify a different database name:
```
make mysql-calls-2015-10 DATABASE=mydatabase
```
