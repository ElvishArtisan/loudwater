// lwsync.h
//
// Loudwater Processing Daemon - Sync external channel feeds
//
//   (C) Copyright 2010 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwsync.h,v 1.2 2010/09/07 18:38:12 pcvs Exp $
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

#ifndef LWSYNC_H
#define LWSYNC_H

#include <stdio.h>

#include <list>

#include <mxml.h>

#include <qobject.h>
#include <qsqldatabase.h>

#include <lwconfig.h>

#define LWSYNC_USAGE "[--force]\n\n--force\n     Force a metadata update once and then exit.\n\n"

class MainObject : public QObject
{
  Q_OBJECT
 public:
  MainObject(QObject *parent=0,const char *name=0);

 private:
  void SyncFeed(const QString &url);
  void WriteFeedData(const QString &url,FILE *xmlfile);
  bool GetPlaylist(mxml_node_t *tree,QString *title,QString *desc,QString *url);
  bool GetRss(mxml_node_t *tree,QString *title,QString *desc,QString *url);
  QString LoadString(mxml_node_t *node);
  LWConfig *lw_config;
  QSqlDatabase *lw_db;
  QString lw_tempdir;
  bool lw_force;
};


#endif  // LWSYNC_H
