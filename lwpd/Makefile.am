## automake.am
##
## Loudwater Processing Daemon
##
## (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
##
##      $Id: Makefile.am,v 1.3 2010/09/07 18:38:12 pcvs Exp $
##
##   This program is free software; you can redistribute it and/or modify
##   it under the terms of the GNU General Public License version 2 as
##   published by the Free Software Foundation.
##
##   This program is distributed in the hope that it will be useful,
##   but WITHOUT ANY WARRANTY; without even the implied warranty of
##   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##   GNU General Public License for more details.
##
##   You should have received a copy of the GNU General Public
##   License along with this program; if not, write to the Free Software
##   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
##
##
## Use automake to process this into a Makefile.in

AM_CPPFLAGS = -Wall -DPREFIX=\"$(prefix)\" -DQTDIR=\"@QT_DIR@\" @QT_CXXFLAGS@ @MXML_CFLAGS@
LIBS = @QT_LIBS@
MOC = @QT_MOC@

# The dependency for qt's Meta Object Compiler (moc)
moc_%.cpp:	%.h
	$(MOC) $< -o $@


sbin_PROGRAMS = lwpd lwingest lwencode lwdistribute lwmaintain lwsync

dist_lwpd_SOURCES = cmdswitch.cpp cmdswitch.h\
                    common.cpp common.h\
                    lwconfig.cpp lwconfig.h\
                    lwpd.cpp lwpd.h
nodist_lwpd_SOURCES = moc_lwpd.cpp
lwpd_LDADD = @QT_LIBS@

dist_lwingest_SOURCES = common.cpp common.h\
                        lwconfig.cpp lwconfig.h\
                        lwingest.cpp lwingest.h
nodist_lwingest_SOURCES = moc_lwingest.cpp
lwingest_LDADD = @QT_LIBS@ -lsndfile

dist_lwencode_SOURCES = common.cpp common.h\
                        lwconfig.cpp lwconfig.h\
                        lwencode.cpp lwencode.h
nodist_lwencode_SOURCES = moc_lwencode.cpp
lwencode_LDADD = @QT_LIBS@

dist_lwdistribute_SOURCES = common.cpp common.h\
                            lwconfig.cpp lwconfig.h\
                            lwdistribute.cpp lwdistribute.h
nodist_lwdistribute_SOURCES = moc_lwdistribute.cpp
lwdistribute_LDADD = @QT_LIBS@ -lcurl

dist_lwmaintain_SOURCES = common.cpp common.h\
                          lwconfig.cpp lwconfig.h\
                          lwmaintain.cpp lwmaintain.h
nodist_lwmaintain_SOURCES = moc_lwmaintain.cpp
lwmaintain_LDADD = @QT_LIBS@ -lcurl

dist_lwsync_SOURCES = cmdswitch.cpp cmdswitch.h\
                      common.cpp common.h\
                      lwconfig.cpp lwconfig.h\
                      lwsync.cpp lwsync.h
nodist_lwsync_SOURCES = moc_lwsync.cpp
lwsync_LDADD = @QT_LIBS@ -lcurl -lmxml


EXTRA_DIST =

CLEANFILES = *~ moc_* *.obj *.idb *.pdb *ilk
MAINTAINERCLEANFILES = *~ Makefile.in
