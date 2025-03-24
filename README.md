# btrfs-backups
Tools that ease the use of BTRFS

## Usage

```
BTRFS Snaptime, (c) 2025 oxasploits, llc.
Designed by: oxagast / Marshall Whittaker.

Usage:
   ./btrfs-snaptime.sh -p /:/home -c -w
   ./btrfs-snaptime.sh -p /home -r -d 5

 -h   This help message.
 -p    Partitions to snapshot, seperated by colons. Mandatory.     Default:          none
 -d    Max number of snapshots to leave in trail, total.           Default:             6
 -r    If there is a previous snapshot taken on the same           Default:           off
       day, should we remove it and resnap?
 -c    Immediately commit deletions.                               Default:           off
 -w    Mark read-only                                              Default:           off
 -L    Snapshot locations (relative to btrfs mountpoint)           Default:  /.snapshots/
```

It is also recommended to add this to a crontab so it runs automatically, an example would be:

`15 11,18 * * *    /usr/local/bin/btrfs-snaptime -p /home:/home/marshall/Secret -d 8 -r -c -w`


## Author

Marshall Whittaker (oxagast)
