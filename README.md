# kapacitor-tasks

The [Kapacitor](https://docs.influxdata.com/kapacitor/v1.5/) task scripts, can be used with [InfluxDB](https://docs.influxdata.com/influxdb/v1.7/) to monitor timeseries data. can be used with [kapacitor-alarm](https://github.com/arstercz/kapacitor-alarm).

**note**: these task scripts only test in `kapacitor-1.5` and `influxdb-1.7`, some `influx tag` or `field` maybe different at old version. 

## How to use?

#### define the task

the `database` and `retention policy` can be changed by `-dbrp` option, or modify the line `dbrp xxxx` which in the tick script:
```
# kapacitor define cpu_usage -tick cpu/cpu_usage.tick
```

#### enable the task
after define task, you can enable the monitor:
```
# kapacitor enable cpu_usage
```

## task list

#### cpu
```
cpu_usage.tick
```
#### disk
```
disk_bandwidth.tick
disk_iops.tick
disk_latency.tick
disk_used.tick
```
#### memory
```
memory/memory_used.tick
```
#### system
```
system_load.tick
system_process.tick
system_swap.tick
```
#### network
```
network_connect.tick
network_traffic.tick
```
#### memory
```
memcached_conn.tick
memcached_qps.tick
```
#### mysql
```
mysql_conn.tick
mysql_qps_detect.tick
mysql_qps.tick
mysql_slave.tick
```
#### redis
```
redis_conn.tick
redis_mem.tick
redis_qps.tick
redis_slave.tick
```

## check tools

#### dependency

the following dependency packages should be installed:
```
perl-libwww-perl
perl-HTTP-Message
perl-DateTime
perl-JSON
perl-Data-Dumper
```

#### how to use?

the `check_tools` directory contains some useful utilities so that we can check custom timeseries data:
```
set_tick.sh     # define and enable kapacitor tasks in batch way
exec_parse.pl   # sample usage when you use the alert.exec() method
service_check.pl  
service_check.tick
```
the `service_check.pl` check the lastest `system`, `mysql`, `redis` and `memcached` items, then insert expire status to the "db"."autogen"."service_check". `service_check.tick` use the `isTimeExpire` filed to determine whether the service is alive or dead, or missing lastest data.

`service_check.pl` can be run as crontab jobs, and the period time in `service_check.tick` should be greater than crontab interval time.

#### define and enable kapacitor tasks

```
$ cd kapacitor-tasks
$ bash check_tools/set_tick.sh -d -e
```

## License

MIT/BSD
