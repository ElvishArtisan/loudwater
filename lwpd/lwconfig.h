// lwconfig.h
//
// Container class for LiveWire Configuration
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwconfig.h,v 1.1.1.1 2009/10/12 16:33:45 pcvs Exp $
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License version 2 as
//   published by the Free Software Foundation.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License for more details.
//
//   You should have received a copy of the GNU General Public
//   License along with this program; if not, write to the Free Software
//   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
//

#ifndef LWCONFIG_H
#define LWCONFIG_H

#ifndef WIN32
#include <syslog.h>
#include <netdb.h>
#endif  // WIN32

#include <vector>

#include <qstring.h>

class LWConfig
{
 public:
  LWConfig();
  QString mysqlHostname() const;
  QString mysqlUsername() const;
  QString mysqlDbname() const;
  QString mysqlPassword() const;
  QString mysqlDriver() const;
  QString hostname() const;
  bool load(const QString &filename);
  void clear();

 private:
  QString conf_filename;
  QString conf_mysql_hostname;
  QString conf_mysql_username;
  QString conf_mysql_dbname;
  QString conf_mysql_password;
  char conf_hostname[HOST_NAME_MAX+1];
};


#endif  // LWCONFIG_H
