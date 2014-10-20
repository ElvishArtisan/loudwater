// lwpd.h
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwpd.h,v 1.3 2011/12/22 19:22:28 pcvs Exp $
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

#ifndef LWPD_H
#define LWPD_H

#include <list>

#include <qobject.h>
#include <qtimer.h>
#include <qsqldatabase.h>

#include <lwconfig.h>

#define LWPD_USAGE "-d\n"
#define PID_FILE "/var/run/lwpd.pid"
#define LWPD_METADATA_SCAN_INTERVAL 3600

class MainObject : public QObject
{
  Q_OBJECT
 public:
  MainObject(QObject *parent=0,const char *name=0);

 private slots:
  void processData();
  void clearMetadataData();

 private:
  void Process();
  int ProcessJobs(int threads,int status,const QString &cmd,
		  std::list<pid_t> *pids);
  int ProcessDeletions(int threads,int status,const QString &cmd,
		       std::list<pid_t> *pids);
  void ProcessSyncs();
  void ClearProcess(std::list<pid_t> *list,pid_t pid);
  void GetJobsLock() const;
  void FreeJobsLock() const;
  void ClearJobs() const;
  std::list<pid_t> lw_ingest_pids;
  std::list<pid_t> lw_encode_pids;
  std::list<pid_t> lw_distribution_pids;
  std::list<pid_t> lw_maintenance_pids;
  QTimer *lw_process_timer;
  bool debug;
  LWConfig *lw_config;
  QSqlDatabase *lw_db;
};


#endif  // LWPD_H
