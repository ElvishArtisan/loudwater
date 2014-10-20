// lwingest.cpp
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwingest.cpp,v 1.5 2012/04/25 20:56:04 pcvs Exp $
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
#include <sndfile.h>

#include <qapplication.h>

#include <common.h>
#include <lwingest.h>

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

  openlog("lwingest [lwpd]",0,LOG_DAEMON);

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
    fprintf(stderr,"lwingest: unable to log into database server\n");
    exit(256);
  }

  //
  // Set up signals
  //
  ::signal(SIGCHLD,SigHandler);
  ::signal(SIGTERM,SigHandler);
  ::signal(SIGINT,SigHandler);

  QString sql;
  sql=
    QString().sprintf("select POST_ID,PART,PATH from JOBS where ID=%d",job_id);
  QSqlQuery *q=new QSqlQuery(sql);
  if(q->first()) {
    Ingest(q->value(0).toInt(),q->value(1).toInt(),q->value(2).toString());
  }
  delete q;

  exit(0);
}


void MainObject::Ingest(int post_id,int partnum,const QString &infile)
{
  QString outfile;
  QString cmd;
  QString sql;
  QSqlQuery *q;
  SNDFILE *sndfile;
  SF_INFO sfinfo;
  QString type;
  long unsigned audio_length=0;
  int audio_samplerate=0;
  int audio_channels=0;
  bool delete_outfile=true;

  //
  // Generate Temporary File Name
  //
  QString vstats=QueueFilePath(FILE_TYPE_INGEST,post_id,partnum,-1,"vstats");

  //
  // Build normalization command
  //
  QString extension=FileExtension(infile).lower();
  if(extension=="wav") {
    outfile=QueueFilePath(FILE_TYPE_ENCODE,post_id,partnum,-1,"wav");
    cmd="cp "+infile+" "+outfile;
    type="A";
  }
  if((extension=="mp")||(extension=="mp1")||(extension=="mp2")||
     (extension=="mp3")) {
    outfile=QueueFilePath(FILE_TYPE_ENCODE,post_id,partnum,-1,"wav");
    cmd="mpg321 -w "+outfile+" "+infile;
    type="A";
  }
  if(extension=="ogg") {
    outfile=QueueFilePath(FILE_TYPE_ENCODE,post_id,partnum,-1,"wav");
    cmd="ogg123 -d wav -f "+outfile+" "+infile;
    type="A";
  }
  if(extension=="flac") {
    outfile=QueueFilePath(FILE_TYPE_ENCODE,post_id,partnum,-1,"wav");
    cmd="flac -d -o "+outfile+" "+infile;
    type="A";
  }
  if(extension=="dv") {
    outfile=QueueFilePath(FILE_TYPE_ENCODE,post_id,partnum,-1,"dv");
    cmd="mv "+infile+" "+outfile+";"+"ffmpeg -y -vstats_file "+vstats+" -i "+
      outfile+" -target ntsc-dv /dev/null";
    type="V";
  }
  if((extension=="avi")||(extension=="mov")||(extension=="wmv")||
     (extension=="mpg")||(extension=="mpeg")||(extension=="asf")||
     (extension=="flv")) {
    outfile=QueueFilePath(FILE_TYPE_ENCODE,post_id,partnum,-1,"dv");
    cmd="ffmpeg -y -vstats_file "+vstats+" -i "+infile+" -target ntsc-dv "+
      outfile;
    type="V";
  }

  if(cmd.isNull()) {
    unlink(vstats);
    syslog(LOG_NOTICE,"Unknown file type, aborting, name: %s  extension: %s",
	   (const char *)infile,(const char *)extension);
    Abort(JOB_STATE_UNKNOWN_FILETYPE_ERROR,infile,job_id,post_id);
    return;
  }

  //
  // Normalize format
  //
  if(system(cmd)!=0) {
    MatchPerms(infile,outfile);
    unlink(vstats);
    Abort(JOB_STATE_INTERNAL_ERROR,infile,job_id,post_id);
    return;
  }
  MatchPerms(infile,outfile);

  //
  // Calculate Content Length
  //
  if(type=="A") {
    if((sndfile=sf_open(outfile,SFM_READ,&sfinfo))==NULL) {
      Abort(JOB_STATE_INTERNAL_ERROR,infile,job_id,post_id);
      return;
    }
    audio_length=1000*sfinfo.frames/sfinfo.samplerate;
    audio_samplerate=sfinfo.samplerate;
    audio_channels=sfinfo.channels;
    sf_close(sndfile);
  }
  else {
    audio_length=VstatsLength(vstats);
  }
  printf("audio len: %lu\n",audio_length);

  //
  // Create Part Record
  //
  sql=QString().sprintf("insert into PARTS set \
                         POST_ID=%u,\
                         PART=%u,\
                         CONTENT_TYPE=\"%s\",\
                         AUDIO_LENGTH=%lu",
			post_id,
			partnum,
			(const char *)type,
			audio_length);
  q=new QSqlQuery(sql);
  delete q;

  //
  // Create encode jobs
  //
  sql=QString().sprintf("select TAPS.ID from TAPS left join POSTS \
                         on TAPS.CHANNEL_NAME=POSTS.CHANNEL_NAME \
                         where (POSTS.ID=%d)&&(TAPS.IS_TRANSPARENT=\"N\")",
			post_id);
  q=new QSqlQuery(sql);
  while(q->next()) {
    sql=QString().sprintf("insert into JOBS set \
                           PATH=\"%s\",	   \
                           STATUS=%d,	   \
                           HOSTNAME=null,	   \
                           PROCESS_ID=null, \
                           PART=%d,\
                           POST_ID=%d,\
                           TAP_ID=%d",
			  (const char *)SqlEscape(outfile),
			  JOB_STATE_ENCODE_QUEUED,
			  partnum,
                          post_id,
			  q->value(0).toInt());
    QSqlQuery *q1=new QSqlQuery(sql);
    delete q1;
    delete_outfile=false;
  }
  delete q;

  //
  // Create distribution jobs (for transparent taps)
  //
  sql=QString().sprintf("select TAPS.ID,TAPS.AUDIO_EXTENSION,\
                         TAPS.VIDEO_EXTENSION from TAPS left join POSTS \
                         on TAPS.CHANNEL_NAME=POSTS.CHANNEL_NAME \
                         where (POSTS.ID=%d)&&(TAPS.IS_TRANSPARENT=\"Y\")",
			post_id);
  q=new QSqlQuery(sql);
  while(q->next()) {
    QString ext=q->value(1).toString();
    if(type!="A") {
      ext=q->value(2).toString();
    }
    QString directfile=QueueFilePath(FILE_TYPE_UPLOAD,post_id,
				   partnum,q->value(0).toInt(),ext);
    system("cp "+infile+" "+directfile);
    sql=QString().sprintf("insert into JOBS set \
                           PATH=\"%s\",	   \
                           STATUS=%d,	   \
                           HOSTNAME=null,	   \
                           PROCESS_ID=null, \
                           PART=%d,\
                           POST_ID=%d,\
                           TAP_ID=%d",
			  (const char *)SqlEscape(directfile),
			  JOB_STATE_DISTRIBUTION_QUEUED,
			  partnum,
                          post_id,
			  q->value(0).toInt());
    QSqlQuery *q1=new QSqlQuery(sql);
    delete q1;
  }
  delete q;

  //
  // Delete ingest job
  //
  sql=QString().sprintf("delete from JOBS where ID=%d",job_id);
  q=new QSqlQuery(sql);
  delete q;

  //
  // Clean up
  //
  unlink(vstats);
  unlink(infile);
  if(delete_outfile) {
    unlink(outfile);
  }
}


int main(int argc,char *argv[])
{
  QApplication a(argc,argv,false);
  new MainObject(NULL,"main");
  return a.exec();
}
