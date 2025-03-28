#!/bin/sh
#checkinstall -R --requires bash --maintainer "Marshall Whittaker"  --pkgversion "0.27" --pkglicense "Apache 2.0"  --pkgname "btrfs-snaptime" --summary "This is a helper utility for generating snapshot backups with btrfs." make install
checkinstall -D --gzman --requires bash --maintainer "Marshall Whittaker"  --pkgversion "0.27" --pkglicense "Apache 2.0"  --pkgname "btrfs-snaptime" --summary "This is a helper utility for generating snapshot backups with btrfs." make install
