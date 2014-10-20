// lwconfig.cpp
//
// Container class for LiveWire Configuration
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwconfig.cpp,v 1.1.1.1 2009/10/12 16:33:45 pcvs Exp $
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

#include <stdlib.h>
#include <stdio.h>

#include <qstringlist.h>

#include <lwconfig.h>

LWConfig::LWConfig()
{
  clear();
}


QString LWConfig::mysqlHostname() const
{
  return conf_mysql_hostname;
}


QString LWConfig::mysqlUsername() const
{
  return conf_mysql_username;
}


QString LWConfig::mysqlDbname() const
{
  return conf_mysql_dbname;
}


QString LWConfig::mysqlPassword() const
{
  return conf_mysql_password;
}


QString LWConfig::hostname() const
{
  return QString(conf_hostname);
}


bool LWConfig::load(const QString &filename)
{
  FILE *f=NULL;
  char line[1024];
  QStringList list;

  char hostname[HOST_NAME_MAX+1];
  struct hostent *hostent;

  //
  // Get canonical hostname
  //
  gethostname(hostname,HOST_NAME_MAX);
  if((hostent=gethostbyname(hostname))==NULL) {
    syslog(LOG_DAEMON|LOG_ERR,"unable to determine canonical host name");
    strcpy(conf_hostname,hostname);
  }
  else {
    strcpy(conf_hostname,hostent->h_name);
  }

  //
  // Read configuration file
  //
  if((f=fopen(filename,"r"))==NULL) {
    return false;
  }
  while(fgets(line,1024,f)!=NULL) {
    list=list.split("=",line);
    if(list.size()==2) {
      list[1].replace("\"","");
      list[1].replace(";","");
      list[1].replace("\n","");
      if(list[0]=="$loudwater_db_hostname") {
	conf_mysql_hostname=list[1];
      }
      if(list[0]=="$loudwater_db_dbname") {
	conf_mysql_dbname=list[1];
      }
      if(list[0]=="$loudwater_db_username") {
	conf_mysql_username=list[1];
      }
      if(list[0]=="$loudwater_db_password") {
	conf_mysql_password=list[1];
      }
    }
  }
  fclose(f);

  return true;
}


void LWConfig::clear()
{
  conf_mysql_hostname="";
  conf_mysql_username="";
  conf_mysql_dbname="";
  conf_mysql_password="";
}
