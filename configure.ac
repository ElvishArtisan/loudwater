dnl configure.in
dnl
dnl Autoconf configuration for Loudwater.
dnl Use autoconf to process this into a configure script
dnl
dnl   (C) Copyright 2009-2014 Fred Gleason <fredg@paravelsystems.com>
dnl
dnl   This program is free software; you can redistribute it and/or modify
dnl   it under the terms of the GNU General Public License version 2 as
dnl   published by the Free Software Foundation.
dnl
dnl   This program is distributed in the hope that it will be useful,
dnl   but WITHOUT ANY WARRANTY; without even the implied warranty of
dnl   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
dnl   GNU General Public License for more details.
dnl
dnl   You should have received a copy of the GNU General Public
dnl   License along with this program; if not, write to the Free Software
dnl   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
dnl

AC_INIT(loudwater,m4_esyscmd(cat PACKAGE_VERSION))
AM_INIT_AUTOMAKE
AC_SUBST(RPM_RELEASE,1)
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])
AC_CONFIG_MACRO_DIR([m4])

#
# Some Fully Resolved Install Paths
# (for the packaging system and friends)
#
if test ${prefix} = "NONE" ; then
  AC_SUBST(LOCAL_PREFIX,/usr/local)
else
  AC_SUBST(LOCAL_PREFIX,${prefix})
fi

#
# Check for C Compiler
#
AC_PROG_CC

#
# Check for C++ Compiler
#
AC_PROG_CXX
AC_LANG(C++)

#
# Check for perl
#
#AX_WITH_PERL
#if test -z $PERL ; then
#  AC_MSG_ERROR([*** No Perl interpreter found ***])
#fi

#
# Check for Qt
#
BNV_HAVE_QT
if test $have_qt = "no" ; then
  AC_MSG_ERROR([*** Qt3 toolkit not found, unable to continue ***])
fi

#
# Check for libcurl
#
AC_CHECK_HEADER(curl/curl.h,[],[AC_MSG_ERROR([*** LibCurl not found, unable to continue ***])])

#
# Check for mxml
#
AC_CHECK_HEADER(mxml.h,[],[AC_MSG_ERROR([*** mxml not found, unable to continue ***])])
AC_SUBST(MXML_CFLAGS,`pkg-config --cflags mxml`)
#AC_SUBST(MXML_LIBS,`pkg-config --libs mxml`)

#
# Determine the target architecture
#
AR_GCC_TARGET()
AC_SUBST(VENDOR,$ar_gcc_distro)
AC_SUBST(ARCH,$ar_gcc_arch)

#
# Determine Distro
#
AR_GET_DISTRO()

#
# Check for libsndfile
#
AC_CHECK_HEADER(sndfile.h,[],[AC_MSG_ERROR([*** libsndfile not found ***])])

#
# Configure RPM Build
#
AC_CHECK_PROG(RPMBUILD_FOUND,rpmbuild,[yes],[])
if test -z $RPMBUILD_FOUND ; then
  AC_SUBST(RPMBUILD,rpm)
else
  AC_SUBST(RPMBUILD,rpmbuild)
fi
if test -d /usr/src/redhat ; then
  AC_SUBST(RPM_ROOT,/usr/src/redhat)
  AC_SUBST(VENDOR,redhat)
else
  AC_SUBST(RPM_ROOT,/usr/src/packages)
  AC_SUBST(VENDOR,suse)
fi 

AC_CONFIG_FILES([loudwater.spec \
    ./Makefile \
    ./loudwater.conf \
    ./src/Makefile \
    ./helpers/Makefile \
    ./scripts/Makefile \
    ./modules/Makefile \
    ./htdocs/Makefile \
    ./htdocs/version.pl \
    ./images/Makefile \
    ./stats/Makefile \
    ./lwpd/Makefile \
    ./docs/Makefile \
    ./rc.lwpd \
    ])
AC_OUTPUT()
chmod 755 htdocs/version.pl
chmod 755 rc.lwpd

#
# Configuration Results
#
AC_MSG_NOTICE()
AC_MSG_NOTICE(Now enter 'make' to build the software.)
AC_MSG_NOTICE()
