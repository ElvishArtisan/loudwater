// lwencode.h
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwencode.h,v 1.1.1.1 2009/10/12 16:33:45 pcvs Exp $
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

#ifndef LWENCODE_H
#define LWENCODE_H

#include <list>

#include <qobject.h>
#include <qsqldatabase.h>

#include <lwconfig.h>
#include <lwencode.h>

#define LWENCODE_USAGE "<job-id>\n"

class MainObject : public QObject
{
  Q_OBJECT
 public:
  MainObject(QObject *parent=0,const char *name=0);

 private:
  LWConfig *lw_config;
  QSqlDatabase *lw_db;
};


#endif  // LWENCODE_H
