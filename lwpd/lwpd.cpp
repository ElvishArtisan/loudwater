// lwpd.cpp
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwpd.cpp,v 1.5 2014/05/09 15:43:18 pcvs Exp $
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
#include <syslog.h>

#include <qapplication.h>
#include <qdatetime.h>

#include <common.h>
#include <cmdswitch.h>
#include <lwconfig.h>
#include <lwpd.h>

//
// Globals
//
volatile bool lwpd_exiting=false;
volatile pid_t lwpd_sync_pid=0;

void SigHandler(int signo)
{
  switch(signo) {
  case SIGTERM:
  case SIGINT:
    lwpd_exiting=true;
    break;
  }
}


MainObject::MainObject(QObject *parent,const char *name)
  :QObject(parent,name)
{
  //
  // Read Command Options
  //
  debug=false;
  lwpd_sync_pid=0;

  CmdSwitch *cmd=new CmdSwitch(qApp->argc(),qApp->argv(),"lwpd",LWPD_USAGE);
  for(unsigned i=0;i<cmd->keys();i++) {
    if(cmd->key(i)=="-d") {
      debug=true;
    }
  }
  delete cmd;
  if(debug) {
    openlog("lwpd",LOG_PERROR,LOG_DAEMON);
  }
  else {
    openlog("lwpd",0,LOG_DAEMON);
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
    fprintf(stderr,"lwpd: unable to log into database server\n");
    exit(256);
  }

  //
  // Detach
  //
  if(!debug) {
    daemon(0,0);
  }
  FILE *f=NULL;
  if((f=fopen(PID_FILE,"w"))==NULL) {
    fprintf(stderr,"lwpd: unable to create pid file\n");
  }
  else {
    fprintf(f,"%d",getpid());
    fclose(f);
  }

  //
  // Set up signals
  //
  //  ::signal(SIGCHLD,SigHandler);
  ::signal(SIGTERM,SigHandler);
  ::signal(SIGINT,SigHandler);

  //
  // Clear stalled/incomplete jobs
  //
  ClearJobs();

  //
  // Start processing
  //
  lw_process_timer=new QTimer(this);
  connect(lw_process_timer,SIGNAL(timeout()),this,SLOT(processData()));
  lw_process_timer->start(0,true);

  QTimer *timer=new QTimer(this);
  connect(timer,SIGNAL(timeout()),this,SLOT(clearMetadataData()));
  timer->start(LWPD_METADATA_SCAN_INTERVAL*1000);
  clearMetadataData();
}


void MainObject::processData()
{
  if(lwpd_exiting) {
    unlink(PID_FILE);
    exit(0);
  }
  Process();
  lw_process_timer->start(1000,true);
}


void MainObject::clearMetadataData()
{
  QString sql;
  QSqlQuery *q;
  QDateTime one_hour_ago=QDateTime(QDate::currentDate(),
				   QTime::currentTime()).
    addSecs(-LWPD_METADATA_SCAN_INTERVAL);

  sql=QString().sprintf("delete from PLAYLIST_METADATA \
                         where UPDATE_DATETIME<\"%s\"",
			(const char *)one_hour_ago.
			toString("yyyy-MM-dd hh:mm:ss"));
  q=new QSqlQuery(sql);
  delete q;
}


void MainObject::Process()
{
  QString sql;
  pid_t pid;

  sql=QString().sprintf("select TOTAL_THREADS,INGEST_THREADS,ENCODE_THREADS,\
                         DISTRIBUTION_THREADS,MAINTENANCE_THREADS \
                         from SERVERS where HOSTNAME=\"%s\"",
			(const char *)SqlEscape(lw_config->hostname()));
  QSqlQuery *q=new QSqlQuery(sql);
  if(q->first()) {
    int threads=0;
    int total_threads=q->value(0).toInt()
      -(lw_ingest_pids.size()+lw_encode_pids.size()+
	lw_distribution_pids.size()+lw_maintenance_pids.size());

    threads=q->value(4).toInt()-lw_maintenance_pids.size();
    if(total_threads<threads) {
      threads=total_threads;
    }
    total_threads-=ProcessDeletions(threads,JOB_STATE_DELETION_QUEUED,
				    "lwmaintain",&lw_maintenance_pids);
    total_threads-=ProcessJobs(threads,JOB_STATE_DELETION_QUEUED,
			       "lwmaintain",&lw_maintenance_pids);
    total_threads-=ProcessJobs(threads,JOB_STATE_TAP_DELETION_QUEUED,
			       "lwmaintain",&lw_maintenance_pids);
    ProcessSyncs();

    threads=q->value(1).toInt()-lw_ingest_pids.size();
    if(total_threads<threads) {
      threads=total_threads;
    }
    total_threads-=ProcessJobs(threads,JOB_STATE_INGEST_QUEUED,"lwingest",
			       &lw_ingest_pids);

    threads=q->value(2).toInt()-lw_encode_pids.size();
    if(total_threads<threads) {
      threads=total_threads;
    }
    total_threads-=ProcessJobs(threads,JOB_STATE_ENCODE_QUEUED,"lwencode",
			       &lw_encode_pids);

    threads=q->value(3).toInt()-lw_distribution_pids.size();
    if(total_threads<threads) {
      threads=total_threads;
    }
    total_threads-=ProcessJobs(threads,JOB_STATE_DISTRIBUTION_QUEUED,
			       "lwdistribute",&lw_distribution_pids);
  }
  delete q;

  //
  // Take out the trash
  //
  while((pid=waitpid(-1,NULL,WNOHANG))>0) {
    ClearProcess(&lw_ingest_pids,pid);
    ClearProcess(&lw_encode_pids,pid);
    ClearProcess(&lw_distribution_pids,pid);
    ClearProcess(&lw_maintenance_pids,pid);
    if(pid==lwpd_sync_pid) {
      lwpd_sync_pid=0;
    }
  }
}


int MainObject::ProcessJobs(int threads,int status,const QString &cmd,
			    std::list<pid_t> *pids)
{
  QString sql;
  QSqlQuery *q;
  QSqlQuery *q1;
  int used=0;
  std::vector<unsigned> post_ids;

  GetJobsLock();
  sql=QString().sprintf("select ID,POST_ID from JOBS where STATUS=%d",status);
  q=new QSqlQuery(sql);
  while(q->next()&&(threads>0)) {
    int job_id=q->value(0).toInt();
    pid_t pid=fork();
    if(pid==0) {
      system(QString().sprintf("%s %d",(const char *)cmd,job_id));
      exit(0);
    }
    pids->push_back(pid);
    sql=QString().sprintf("update JOBS set HOSTNAME=\"%s\",PROCESS_ID=%d,\
                           STATUS=%d where ID=%d",
			  (const char *)SqlEscape(lw_config->hostname()),
			  pid,
			  status+1,
			  q->value(0).toInt());
    q1=new QSqlQuery(sql);
    delete q1;
    post_ids.push_back(q->value(1).toUInt());
    used++;
    threads--;
  }
  delete q;
  FreeJobsLock();

  return used;
}


int MainObject::ProcessDeletions(int threads,int status,const QString &cmd,
				 std::list<pid_t> *pids)
{
  QString sql;
  QSqlQuery *q;
  QSqlQuery *q1;
  QSqlQuery *q2;
  int used=0;

  //
  // Delete queued post deletions
  //
  sql="select ID,CHANNEL_NAME,PROCESSING from POSTS where DELETING=\"Y\"";
  q=new QSqlQuery(sql);
  while(q->next()) {
    if(q->value(2).toString()=="N") {
      GetJobsLock();
      sql=QString().sprintf("select ID,PATH from JOBS where (POST_ID=%d)&&\
                           ((STATUS=%d)||(STATUS=%d)||\
                            (STATUS=%d)||(STATUS=%d)||(STATUS>%d))",
			    q->value(0).toInt(),
			    JOB_STATE_INGEST_QUEUED,
			    JOB_STATE_ENCODE_QUEUED,
			    JOB_STATE_DISTRIBUTION_QUEUED,
			    JOB_STATE_DELETION_QUEUED,
			    JOB_STATE_LAST_GOOD_STATE);
      q1=new QSqlQuery(sql);
      while(q1->next()) {
	unlink(q1->value(1).toString());
	sql=QString().sprintf("delete from JOBS where ID=%d",
			      q1->value(0).toInt());
	q2=new QSqlQuery(sql);
	delete q2;
      }
      delete q1;
      FreeJobsLock();
      
      //
      // Queue upload deletions
      //
      sql=QString().sprintf("select TAP_ID from UPLOADS where POST_ID=%u",
			    q->value(0).toUInt());
      q1=new QSqlQuery(sql);
      while(q1->next()) {
	sql=QString().sprintf("insert into JOBS set \
                             STATUS=%u,		    \
                             POST_ID=%u,	    \
                             TAP_ID=%u",
			      JOB_STATE_DELETION_QUEUED,
			      q->value(0).toUInt(),
			      q1->value(0).toUInt());
	q2=new QSqlQuery(sql);
	delete q2;
      }
      delete q1;

      //
      // Update processing status
      //
      sql=QString().sprintf("update POSTS set PROCESSING=\"Y\" where ID=%d",
			    q->value(0).toInt());
      q1=new QSqlQuery(sql);
      delete q1;
    }

    //
    // Update posts summary status
    //
    sql=QString().sprintf("select ID from JOBS where POST_ID=%d",
			  q->value(0).toInt());
    q1=new QSqlQuery(sql);
    if(!q1->first()) {
      sql=QString().sprintf("delete from PARTS where POST_ID=%d",
			    q->value(0).toInt());
      q2=new QSqlQuery(sql);
      delete q2;

      sql=QString().sprintf("delete from POSTS where ID=%d",
			    q->value(0).toInt());
      q2=new QSqlQuery(sql);
      delete q2;
    }
    delete q1;
  }
  delete q;

  //
  // Update taps summary status
  //
  sql="select ID from TAPS where DELETING=\"Y\"";
  q=new QSqlQuery(sql);
  while(q->next()) {
    sql=QString().sprintf("select ID from UPLOADS where TAP_ID=%d",
			  q->value(0).toInt());
    q1=new QSqlQuery(sql);
    if(!q1->first()) {
      sql=QString().sprintf("delete from TAPS where ID=%d",q->value(0).toInt());
      q2=new QSqlQuery(sql);
      delete q2;
    }
    delete q1;
  }
  delete q;

  return used;
}


void MainObject::ProcessSyncs()
{
  if(lwpd_sync_pid!=0) {
    return;
  }
  if((lwpd_sync_pid=fork())==0) {
    //    execve("/usr/sbin/lwsync",NULL,NULL);
    execl("/usr/sbin/lwsync","/usr/sbin/lwsync",(char *)NULL);
    syslog(LOG_ERR,"unable to exec lwsync(8)");
    exit(256);
  }
}


void MainObject::ClearProcess(std::list<pid_t> *list,pid_t pid)
{
  for(std::list<pid_t>::iterator it=list->begin();it!=list->end();it++) {
    if(*it==pid) {
      list->erase(it);
      return;
    }
  }
}


void MainObject::GetJobsLock() const
{
  QString sql="lock tables JOBS write";
  QSqlQuery *q=new QSqlQuery(sql);
  delete q;
}


void MainObject::FreeJobsLock() const
{
  QString sql="unlock tables";
  QSqlQuery *q=new QSqlQuery(sql);
  delete q;
}


void MainObject::ClearJobs() const
{
  QString sql;
  QSqlQuery *q;
  QSqlQuery *q1;
  QString filename;

  sql=QString().sprintf("select ID,PATH,POST_ID,PART,STATUS from JOBS \
                         where (HOSTNAME=\"%s\")&&\
                         ((STATUS=%d)||(STATUS=%d)||(STATUS=%d)||(STATUS=%d))",
			(const char *)SqlEscape(lw_config->hostname()),
			JOB_STATE_INGESTING,
			JOB_STATE_ENCODING,
			JOB_STATE_DISTRIBUTING,
			JOB_STATE_DELETING);
  q=new QSqlQuery(sql);
  while(q->next()) {
    //
    // Delete partial data
    //
    switch(q->value(4).toInt()) {
    case JOB_STATE_INGESTING:
      filename=QueueFilePath(FILE_TYPE_ENCODE,q->value(2).toInt(),
			     q->value(3).toInt(),-1,"*");
      if(!filename.isNull()) {
	system(QString("rm -f ")+filename);
      }
      break;

    case JOB_STATE_ENCODING:
      filename=QueueFilePath(FILE_TYPE_UPLOAD,q->value(2).toInt(),
			     q->value(3).toInt(),-1,"*");
      if(!filename.isNull()) {
	system(QString("rm -f ")+filename);
      }
      break;
    }

    //
    // Requeue the job
    //
    sql=QString().sprintf("update JOBS set \
                           HOSTNAME=null,\
                           PROCESS_ID=null,\
                           STATUS=%d\
                           where ID=%d",
			  q->value(4).toInt()-1,
			  q->value(0).toInt());
    q1=new QSqlQuery(sql);
    delete q1;
    syslog(LOG_WARNING,"found job %d incomplete, requeued",q->value(0).toInt());
  }
  delete q;
}


int main(int argc,char *argv[])
{
  QApplication a(argc,argv,false);
  new MainObject(NULL,"main");
  return a.exec();
}
