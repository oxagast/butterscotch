# Define where to install files
PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
MANDIR=/usr/share/man


# Install target
install: butterscotch.sh
	mkdir -p $(BINDIR)
	cp butterscotch.sh $(BINDIR)/butterscotch
	chown root:root $(BINDIR)/butterscotch
	chmod a+rx,u+rwx $(BINDIR)/butterscotch
	gzip -k man1/butterscotch.1
	mv man1/butterscotch.1.gz $(MANDIR)/man1/butterscotch.1.gz
	echo "#!/bin/sh" > /etc/cron.daily/butterscotch
	echo "butterscotch -a -d 3 -c -w" >> /etc/cron.daily/butterscotch


# Remove the installed target
deinstall:
	rm -f $(BINDIR)/butterscotch $(MANDIR)/man1/butterscotch.1.gz
	rm -f /etc/cron.daily/butterscotch
