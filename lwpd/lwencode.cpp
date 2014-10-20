// lwencode.cpp
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwencode.cpp,v 1.3 2009/12/28 17:34:20 pcvs Exp $
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
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <unistd.h>

#include <qapplication.h>

#include <common.h>
#include <lwencode.h>

void SigHandler(int signo)
{
  switch(signo) {
  case SIGCHLD:
    ::signal(SIGCHLD,SigHandler);
    ::signal(SIGTERM,SigHandler);
    ::signal(SIGINT,SigHandler);
    return;

  case SIGTERM:
  case SIGINT:
    exit(0);
    break;
  }
}


MainObject::MainObject(QObject *parent,const char *name)
  :QObject(parent,name)
{
  bool ok;
  int job_id=0;
  QString sql;
  QSqlQuery *q;
  QSqlQuery *q1;
  QString cmd;
  QString ext;

  openlog("lwencode [lwpd]",0,LOG_DAEMON);

  if(qApp->argc()!=2) {
    exit(256);
  }
  job_id=QString(qApp->argv()[1]).toInt(&ok);
  if(!ok) {
    exit(256);
  }

  //
  // Load Local Configs
  //
  lw_config=new LWConfig();
  if(!lw_config->load("/etc/loudwater_conf.pl")) {
    fprintf(stderr,"lwpd: unable to open configuration file\n");
    exit(256);
  }

  //
  // Open Database
  //
  if(lw_config->mysqlHostname().isEmpty()) {
    fprintf(stderr,"lwpd: missing database name\n");
    exit(256);
  }
  lw_db=QSqlDatabase::addDatabase("QMYSQL3");
  if(!lw_db) {
    fprintf(stderr,"lwpd: unable to connect to database\n");
    exit(256);
  }
  lw_db->setDatabaseName(lw_config->mysqlDbname());
  lw_db->setUserName(lw_config->mysqlUsername());
  lw_db->setPassword(lw_config->mysqlPassword());
  lw_db->setHostName(lw_config->mysqlHostname());
  if(!lw_db->open()) {
    lw_db->removeDatabase(lw_config->mysqlDbname());
    fprintf(stderr,"lwencode: unable to log into database server\n");
    exit(256);
  }

  //
  // Set up signals
  //
  ::signal(SIGCHLD,SigHandler);
  ::signal(SIGTERM,SigHandler);
  ::signal(SIGINT,SigHandler);

  sql=QString().sprintf("select JOBS.PATH,\
                         TAPS.AUDIO_ENCODER,TAPS.AUDIO_EXTENSION,\
                         TAPS.VIDEO_ENCODER,TAPS.VIDEO_EXTENSION,\
                         JOBS.POST_ID,JOBS.PART,TAPS.ID,\
                         PARTS.CONTENT_TYPE from \
                         JOBS left join TAPS \
                         on JOBS.TAP_ID=TAPS.ID left join PARTS \
                         on (JOBS.POST_ID=PARTS.POST_ID)&&\
                         (JOBS.PART=PARTS.PART) \
                         where JOBS.ID=%d",job_id);
  q=new QSqlQuery(sql);
  while(q->next()) {
    if(q->value(8).toString()=="A") {
      cmd=q->value(1).toString();
      ext=q->value(2).toString();
    }
    else {
      cmd=q->value(3).toString();
      ext=q->value(4).toString();
    }
    if(cmd.isEmpty()) {
      syslog(LOG_ERR,"no encoder command specified, job=%d",job_id);
      sql=QString().sprintf("update JOBS set STATUS=%u,HOSTNAME=null,\
                             PROCESS_ID=null,ERROR_TEXT=null \
                             where ID=%d",
			    JOB_STATE_MISSING_ENCODER_ERROR,
			    job_id);
      q1=new QSqlQuery(sql);
      delete q1;
      delete q;
      exit(256);
    }
    cmd.replace("%f",q->value(0).toString());
    QString destfile=QueueFilePath(FILE_TYPE_UPLOAD,q->value(5).toInt(),
				   q->value(6).toInt(),q->value(7).toInt(),
				   ext);
    QString errfile=destfile+"_err";
    cmd.replace("%F",destfile);
    cmd+=(" 2> "+errfile);
    syslog(LOG_ERR,"encoder cmd: |%s|\n",(const char *)cmd);
    if(system(cmd)==0) {
      sql=QString().sprintf("select ID from JOBS \
                             where (PATH=\"%s\")&&(ID!=%u)",
			    (const char *)q->value(0).toString(),
			    job_id);
      q1=new QSqlQuery(sql);
      if(!q1->first()) {
	unlink(q->value(0).toString());
      }
      delete q1;
      sql=QString().sprintf("update JOBS set STATUS=%u,PATH=\"%s\",\
                             HOSTNAME=null,PROCESS_ID=null where ID=%d",
			    JOB_STATE_DISTRIBUTION_QUEUED,
			    (const char *)destfile,
			    job_id);
      q1=new QSqlQuery(sql);
      delete q1;
    }
    else {
      syslog(LOG_ERR,"encoder error, job=%d, cmd=\"%s\", err=\"%s\"",job_id,
	     (const char *)cmd,(const char *)GetErrorText(errfile));
      sql=QString().sprintf("update JOBS set STATUS=%u,ERROR_TEXT=\"%s\",\
                             HOSTNAME=null,PROCESS_ID=null where ID=%d",
			    JOB_STATE_ENCODER_ERROR,
			    (const char *)SqlEscape(GetErrorText(errfile)),
			    job_id);
      q1=new QSqlQuery(sql);
      delete q1;
    }
    MatchPerms(q->value(0).toString(),destfile);
    unlink(errfile);
  }
  delete q;

  exit(0);
}


int main(int argc,char *argv[])
{
  QApplication a(argc,argv,false);
  new MainObject(NULL,"main");
  return a.exec();
}
