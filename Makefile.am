## automake.am
##
## Top level automake.am for Loudwater
##
## Use automake to process this into a Makefile.in
##
##   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
##
##      $Id: Makefile.am,v 1.6 2012/04/25 20:56:03 pcvs Exp $
##

SUBDIRS = docs src scripts helpers modules htdocs images stats lwpd

ACLOCAL_AMFLAGS = -I m4

maintainer-clean-local:	
	rm -rf m4

install-exec-local:	
	mkdir -p $(DESTDIR)/etc/init.d
	cp rc.lwpd $(DESTDIR)/etc/init.d/lwpd
	mkdir -p $(DESTDIR)/var/cache/loudwater/encode
	chmod 777 $(DESTDIR)/var/cache/loudwater/encode
	mkdir -p $(DESTDIR)/var/cache/loudwater/ingest
	chmod 777 $(DESTDIR)/var/cache/loudwater/ingest
	mkdir -p $(DESTDIR)/var/cache/loudwater/upload
	chmod 777 $(DESTDIR)/var/cache/loudwater/upload
	mkdir -p $(DESTDIR)$(sysconfdir)
	cp loudwater.conf $(DESTDIR)/$(sysconfdir)/
	mkdir -p $(DESTDIR)/var/log/loudwater

uninstall-local:
	rm -f $(DESTDIR)/etc/init.d/lwpd
	rm -f $(DESTDIR)$(sysconfdir)/loudwater.conf

rpm:	dist
	cp loudwater-$(VERSION).tar.gz $(HOME)/rpmbuild/SOURCES/
	$(RPMBUILD) -ba --target $(ARCH)-$(VENDOR)-linux loudwater.spec
	mv $(HOME)/rpmbuild/RPMS/$(ARCH)/loudwater-$(VERSION)-@RPM_RELEASE@.$(ARCH).rpm $(top_srcdir)/
	mv $(HOME)/rpmbuild/RPMS/$(ARCH)/loudwater-stats-$(VERSION)-@RPM_RELEASE@.$(ARCH).rpm $(top_srcdir)/
	mv $(HOME)/rpmbuild/SRPMS/loudwater-$(VERSION)-@RPM_RELEASE@.src.rpm $(top_srcdir)/
	rm $(HOME)/rpmbuild/SOURCES/loudwater-$(VERSION).tar.gz
	rm -rf $(HOME)/rpmbuild/BUILD/loudwater-$(VERSION)

EXTRA_DIST = autogen.sh loudwater.spec.in loudwater.conf.in\
             loudwater_conf-sample.pl PACKAGE_VERSION\
             loudwater_stats_conf-sample.pl\
             get_target.sh get_distro.sh rc.lwpd.in

CLEANFILES = *~ *.tar.gz *.tgz *.mo *.rpm *.zip
DISTCLEANFILES = loudwater.spec ltmain.sh config.guess config.sub\
                 loudwater.conf rc.lwpd
MAINTAINERCLEANFILES = *~ Makefile.in configure aclocal.m4 *.tar.gz\
                       config.guess config.status config.sub install-sh\
                       libtool ltmain.sh missing mkinstalldirs depcomp\
                       loudwater.spec
