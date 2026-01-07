#!/bin/sh
cd ../
checkinstall -y -D --requires bash,btrfs-progs --pkgarch all --maintainer "Marshall Whittaker" --pkgversion "1.3" --pkglicense "Apache 2.0" --pkgname "butterscotch" --summary "This is a helper utility for generating snapshot backups." make install
