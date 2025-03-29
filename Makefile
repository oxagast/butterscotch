# Define where to install files
PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
MANDIR=/usr/share/man


# Install target
install: btrfs-snaptime.sh
	mkdir -p $(BINDIR)
	cp btrfs-snaptime.sh $(BINDIR)/btrfs-snaptime
	chown root:root $(BINDIR)/btrfs-snaptime
	chmod a+rx,u+rwx $(BINDIR)/btrfs-snaptime
	gzip -k man1/btrfs-snaptime.1
	mv man1/btrfs-snaptime.1.gz $(MANDIR)/man1/btrfs-snaptime.1.gz


# Remove the installed target
deinstall:
	rm -f $(BINDIR)/btrfs-snaptime $(MANDIR)/man1/btrfs-snaptime.1.gz
