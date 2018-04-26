# Scripts for Oracle Databases

## autoAWR.sh
This script can be used to automatically create AWR snapshots and reports (e.g. during performance tests).

Example usage:
* Create the first AWR snapshot before the performance test:
```bash
./autoAWR.sh -m start
```

* Snapshot at the end of the test:
```bash
./autoAWR.sh -m end
```

* The final AWR report:
```bash
./autoAWR.sh -m report -f foobar.html
```


