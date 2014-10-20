// lwdistribute.cpp
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwdistribute.cpp,v 1.1.1.1 2009/10/12 16:33:45 pcvs Exp $
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
#include <errno.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <unistd.h>
#include <curl/curl.h>

#include <qapplication.h>
#include <qfileinfo.h>

#include <common.h>
#include <lwdistribute.h>

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
  CURL *curl=NULL;
  FILE *f;
  char curl_err[CURL_ERROR_SIZE];
  int err;
  QFileInfo *file;
  QString sql;
  QSqlQuery *q;
  QSqlQuery *q1;
  QSqlQuery *q2;
  QString url;
  QString download_url;

  openlog("lwdistribute [lwpd]",0,LOG_DAEMON);

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
    fprintf(stderr,"lwdistribute: unable to log into database server\n");
    exit(256);
  }

  //
  // Set up signals
  //
  ::signal(SIGCHLD,SigHandler);
  ::signal(SIGTERM,SigHandler);
  ::signal(SIGINT,SigHandler);

  sql=QString().sprintf("select JOBS.PATH,JOBS.POST_ID,\
                         TAPS.UPLOAD_URL,TAPS.UPLOAD_USERNAME,\
                         TAPS.UPLOAD_PASSWORD,TAPS.ID,TAPS.DOWNLOAD_URL \
                         from JOBS left join TAPS \
                         on JOBS.TAP_ID=TAPS.ID \
                         where JOBS.ID=%d",job_id);
  q=new QSqlQuery(sql);
  if(q->first()) {
    file=new QFileInfo(q->value(0).toString());
    url=q->value(2).toString()+"/"+file->fileName();
    download_url=q->value(6).toString()+"/"+file->fileName();
    if(!file->exists()) {
      syslog(LOG_ERR,"cannot open file \"%s\", job=%u",
	     (const char *)q->value(0).toString(),job_id);
    }
    if((f=fopen(q->value(0).toString(),"r"))==NULL) {
      int openerr=errno;
      syslog(LOG_ERR,"%s, job=%u,file=\"%s\"",strerror(openerr),job_id,
	     (const char *)q->value(0).toString());
      Enqueue(JOB_STATE_DISTRIBUTION_QUEUED,strerror(openerr),
	      q->value(0).toString(),q->value(1).toUInt(),job_id);
      exit(0);
    }
    curl_global_init(CURL_GLOBAL_ALL);
    if((curl=curl_easy_init())==NULL) {
      syslog(LOG_ERR,"unable to initialize curl library, job=%u",job_id);
      Enqueue(JOB_STATE_DISTRIBUTION_ERROR,"unable to initalize curl library",
	      q->value(0).toString(),
	      q->value(1).toUInt(),job_id);
      exit(0);
    }
    curl_easy_setopt(curl,CURLOPT_READDATA,f);
    curl_easy_setopt(curl,CURLOPT_ERRORBUFFER,curl_err);
    curl_easy_setopt(curl,CURLOPT_URL,(const char *)url);
    curl_easy_setopt(curl,CURLOPT_UPLOAD,1);
    curl_easy_setopt(curl,CURLOPT_FTP_FILEMETHOD,CURLFTPMETHOD_MULTICWD);
    curl_easy_setopt(curl,CURLOPT_USERPWD,(const char *)QString().
		     sprintf("%s:%s",
			     (const char *)q->value(3).toString(),
			     (const char *)q->value(4).toString()));
    curl_easy_setopt(curl,CURLOPT_HTTPAUTH,CURLAUTH_ANY);
    if((err=curl_easy_perform(curl))==0) {
      sql=QString().sprintf("insert into UPLOADS set \
                             POST_ID=%u,\
                             TAP_ID=%u,\
                             URL=\"%s\",\
                             DOWNLOAD_URL=\"%s\",\
                             TYPE=\"A\",\
                             BYTE_LENGTH=%u,\
                             UPLOAD_DATETIME=now()",
			    q->value(1).toUInt(),
			    q->value(5).toUInt(),
			    (const char *)url,
			    (const char *)download_url,
			    file->size());
      q1=new QSqlQuery(sql);
      delete q1;
      unlink(q->value(0).toString());
      sql=QString().sprintf("delete from JOBS where ID=%u",job_id);
      q1=new QSqlQuery(sql);
      delete q1;

      //
      // (Perhaps) update summary status
      //
      sql=QString().sprintf("select ID from JOBS where POST_ID=%u",
			    q->value(1).toUInt());
      q1=new QSqlQuery(sql);
      if(!q1->first()) {
	sql=QString().sprintf("update POSTS set PROCESSING=\"N\" where ID=%u",
			      q->value(1).toUInt());
	q2=new QSqlQuery(sql);
	delete q2;
      }
      delete q1;
    }
    else {
      syslog(LOG_ERR,"%s, job=%u, url=\"%s\", username=\"%s\", p/w: \"%s\"",
	     curl_err,job_id,(const char *)url,
	     (const char *)q->value(3).toString(),
	     (const char *)q->value(4).toString());
      Enqueue(JOB_STATE_DISTRIBUTION_ERROR,curl_err,
	      q->value(0).toString(),q->value(1).toUInt(),job_id);
    }
    curl_easy_cleanup(curl);
    fclose(f);
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
