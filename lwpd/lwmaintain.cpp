// lwmaintain.cpp
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwmaintain.cpp,v 1.3 2011/05/25 23:18:41 pcvs Exp $
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
#include <curl/curl.h>

#include <qapplication.h>
#include <qurl.h>

#include <common.h>
#include <lwmaintain.h>

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
  struct curl_slist *cmds=NULL;
  QUrl *url;
  CURL *curl=NULL;
  CURLcode err;
  QString sql;
  QSqlQuery *q;
  QSqlQuery *q1;

  openlog("lwmaintain [lwpd]",0,LOG_DAEMON);

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
    fprintf(stderr,"lwmaintain: unable to log into database server\n");
    exit(256);
  }

  //
  // Set up signals
  //
  ::signal(SIGCHLD,SigHandler);
  ::signal(SIGTERM,SigHandler);
  ::signal(SIGINT,SigHandler);

  sql=QString().sprintf("select UPLOADS.URL,TAPS.UPLOAD_USERNAME,\
                         TAPS.UPLOAD_PASSWORD,UPLOADS.POST_ID,UPLOADS.ID \
                         from UPLOADS left join TAPS \
                         on UPLOADS.TAP_ID=TAPS.ID \
                         left join JOBS \
                         on UPLOADS.TAP_ID=JOBS.TAP_ID \
                         where JOBS.ID=%u",job_id);
  q=new QSqlQuery(sql);
  if(q->first()) {
    url=new QUrl(q->value(0).toString());
    curl_global_init(CURL_GLOBAL_ALL);
    if((curl=curl_easy_init())==NULL) {
      syslog(LOG_ERR,"unable to initialize curl library, job=%u",job_id);
      Enqueue(JOB_STATE_DISTRIBUTION_QUEUED,"unable to initialize curl library",
	      "",q->value(3).toUInt(),job_id);
      exit(0);
    }
    curl_easy_setopt(curl,CURLOPT_URL,
		     (const char *)(url->protocol()+"://"+url->host()+"/"));
    curl_easy_setopt(curl,CURLOPT_USERPWD,(const char *)QString().
		     sprintf("%s:%s",
			     (const char *)q->value(1).toString(),
			     (const char *)q->value(2).toString()));
    curl_easy_setopt(curl,CURLOPT_HTTPAUTH,CURLAUTH_ANY);
    cmds=curl_slist_append(cmds,QString().sprintf("cwd %s",
	  (const char *)url->dirPath().right(url->dirPath().length()-1)));
    cmds=curl_slist_append(cmds, QString().sprintf("dele %s",
          (const char *)url->fileName()));
    curl_easy_setopt(curl,CURLOPT_QUOTE,cmds);
    switch((err=curl_easy_perform(curl))==0) {
    case CURLE_OK:
#ifdef CURLE_QUOTE_ERROR
    case CURLE_QUOTE_ERROR:  // In case the file is already gone
#endif
      sql=QString().sprintf("delete from UPLOADS where ID=%u",
			    q->value(4).toUInt());
      q1=new QSqlQuery(sql);
      delete q1;
      sql=QString().sprintf("delete from JOBS where ID=%u",job_id);
      q1=new QSqlQuery(sql);
      delete q1;      
      ClearPost(q->value(3).toUInt());
      break;

    default:
      syslog(LOG_ERR,"%s [%d], job=%u, url=\"%s\", username=\"%s\"",
	     curl_easy_strerror(err),err,job_id,
	     (const char *)q->value(0).toString(),
	     (const char *)q->value(1).toString());
      Enqueue(JOB_STATE_DELETION_QUEUED,curl_easy_strerror(err),"",
	      q->value(3).toUInt(),job_id);
    }
    curl_slist_free_all(cmds);
    curl_easy_cleanup(curl);
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
