# ButterScotch

## Filesystem snapshot backed backup utilities

Tools that ease the use of filesystem snapshots

ButterScotch supports both ZFS and BTRFS currently.

## Usage

The below flags tell butterscotch how to generate and manage your snapshots.

```
Usage:
   ./butterscotch -p /:/home -c -w
   ./butterscotch -a -r -d 5

 -h       This help message.
 -a       Snapshot all btrfs partitions.                               Default:          off
 -p       Partitions to snapshot, seperated by colons. Mandatory.      Default:         none
 -d       Max number of snapshots to leave in trail, total.            Default:            6
 -r       If there is a previous snapshot taken on the same            Default:          off
          day, should we remove it and resnap?
 -c       Immediately commit deletions.                                Default:          off
 -w       Mark read-only.                                              Default:          off
 -L       Snapshot relative locations.  Must begin and end with '/'    Default: /.snapshots/
 -q       Take a quicksnap. This assumes -a if not specified.          Default:          off
 -U       Unsupported OS override. Use at your own risk!               Default:          off
 -l       List snapshots found in specified partitions. Pair with -p.  Default:         none
 -P       Purge all snapshots found in specified partitions. Asks for  Default:         none
          confirmation before deletion.  Pair with -p or -a.
 -y       Assume yes to all prompts.                                   Default:          off
 -V       Display version information.                                 Default:         none
```

It is also recommended to add this to a crontab so it runs automatically, an example would be:

`0 11,18 * * *    /usr/local/bin/butterscotch -p /:/home -d 8 -r -c -w`

This would tell butterscotch to run at 11am and 6pm every day.  It would overwrite the first
snapshot if rerun, on but this is to assure getting a backup every day.

## License

Apache License 2.0

## Author

Marshall Whittaker (oxagast)
