#!/bin/sh
checkinstall -y -D --requires bash,btrfs-progs --maintainer "Marshall Whittaker"  --pkgversion "1.1" --pkglicense "Apache 2.0"  --pkgname "butterscotch" --summary "This is a helper utility for generating snapshot backups with btrfs." make install
