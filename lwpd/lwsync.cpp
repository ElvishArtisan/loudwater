// lwsync.cpp
//
// Loudwater Processing Daemon - sync external channel feeds
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: lwsync.cpp,v 1.7 2014/05/09 15:43:18 pcvs Exp $
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
#include <qdatetime.h>
#include <qdir.h>

#include <common.h>
#include <cmdswitch.h>
#include <lwsync.h>

//
// Globals
//
QString last_error_text;

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


void XmlErrorCallback(const char *err_text)
{
  last_error_text=err_text;
}


MainObject::MainObject(QObject *parent,const char *name)
  :QObject(parent,name)
{
  QStringList feeds;
  bool found;
  QString sql;
  QSqlQuery *q;
  QDateTime now;
  char tempdir[PATH_MAX];

  lw_force=false;

  //
  // Get Command Options
  //
  CmdSwitch *cmd=new CmdSwitch(qApp->argc(),qApp->argv(),"lwsync",LWSYNC_USAGE);
  for(unsigned i=0;i<cmd->keys();i++) {
    if(cmd->key(i)=="--force") {
      lw_force=true;
    }
  }
  if(lw_force) {
    openlog("lwsync [lwpd]",LOG_PERROR,LOG_DAEMON);
  }
  else {
    openlog("lwsync [lwpd]",0,LOG_DAEMON);
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
    fprintf(stderr,"lwsync: unable to log into database server\n");
    exit(256);
  }

  //
  // Create Temporary Directory
  //
  if(getenv("TEMP")!=NULL) {
    strcpy(tempdir,getenv("TEMP"));
  }
  else {
    strcpy(tempdir,"/tmp");
  }
  strcat(tempdir,"/lwsyncXXXXXX");
  if(mkdtemp(tempdir)==NULL) {
    lw_db->removeDatabase(lw_config->mysqlDbname());
    fprintf(stderr,"lwsync: unable to create temporary directory\n");
    exit(256);
  }
  lw_tempdir=tempdir;
    
  //
  // Initialize Curl Library
  //
  curl_global_init(CURL_GLOBAL_ALL);

  //
  // Set up signals
  //
  ::signal(SIGCHLD,SigHandler);
  ::signal(SIGTERM,SigHandler);
  ::signal(SIGINT,SigHandler);

  //
  // Build Feed List
  //
  now=QDateTime(QDate::currentDate(),QTime::currentTime());
  sql="select CLICK_LINK from CHANNEL_BUTTONS where (CLICK_LINK is not NULL)";
  if(!lw_force) {
    sql+=QString().sprintf("&&((LAST_UPDATE<\"%s\")||(LAST_UPDATE is null))",
			   (const char *)now.
			   addSecs(-CHANNEL_METADATA_UPDATE_INTERVAL).
			   toString("yyyy-MM-dd hh:mm:ss"));
  }
  q=new QSqlQuery(sql);
  while(q->next()) {
    found=false;
    for(unsigned i=0;i<feeds.size();i++) {
      if(q->value(0).toString()==feeds[i]) {
	found=true;
      }
    }
    if(!found) {
      feeds.push_back(q->value(0).toString());
    }
  }
  delete q;

  //
  // Process Feeds
  //
  for(unsigned i=0;i<feeds.size();i++) {
    SyncFeed(feeds[i]);
  }

  //
  // Cleanup
  //
  rmdir(lw_tempdir);

  exit(0);
}


void MainObject::SyncFeed(const QString &url)
{
  CURL *curl=NULL;
  CURLcode err;
  long respcode;
  QString xmlfile=lw_tempdir+"/xml.rss";
  FILE *f=NULL;
  QString sql;
  QSqlQuery *q;

  //
  // Fetch Feed Data
  //
  if((f=fopen(xmlfile,"w+"))==NULL) {
    syslog(LOG_ERR,"unable to open temporary file \"%s\"",
	   (const char *)xmlfile);
    return;
  }
  if((curl=curl_easy_init())==NULL) {
    syslog(LOG_ERR,"unable to initialize curl library");
  }
  curl_easy_setopt(curl,CURLOPT_URL,(const char *)url);
  curl_easy_setopt(curl,CURLOPT_WRITEDATA,f);
  switch((err=curl_easy_perform(curl))) {
  case CURLE_OK:
    if(curl_easy_getinfo(curl,CURLINFO_RESPONSE_CODE,&respcode)==0) {
      switch(respcode) {
      case 200:
	rewind(f);
	WriteFeedData(url,f);
	break;

      default:
	syslog(LOG_ERR,"got response code %ld, url=\"%s\"",
	       respcode,(const char *)url);
	break;
      }
    }
    break;
    
  default:
    syslog(LOG_ERR,"%s [%d], url=\"%s\"",
	   curl_easy_strerror(err),err,(const char *)url);
  }
  curl_easy_cleanup(curl);
  sql=QString().sprintf("update CHANNEL_BUTTONS set LAST_UPDATE=now() \
                         where CLICK_LINK=\"%s\"",
			(const char *)SqlEscape(url));
  q=new QSqlQuery(sql);
  delete q;
  fclose(f);
  unlink(xmlfile);
}


void MainObject::WriteFeedData(const QString &url,FILE *xmlfile)
{
  mxml_node_t *tree=NULL;
  QString type;
  QString title;
  QString desc;
  QString enc_url;
  bool ok=false;
  QString sql;
  QSqlQuery *q;

  mxmlSetErrorCallback(XmlErrorCallback);
  if((tree=mxmlLoadFile(NULL,xmlfile,MXML_TEXT_CALLBACK))==NULL) {
    syslog(LOG_WARNING,"unable to process feed, url=\"%s\", reason=\"%s\"",
	   (const char *)url,(const char *)last_error_text);
    return;
  }
  type=tree->value.element.name;

  if(type.lower()=="playlist") {
    ok=GetPlaylist(tree,&title,&desc,&enc_url);
  }
  else {
    if(mxmlFindElement(tree,tree,"channel",NULL,NULL,MXML_DESCEND)!=NULL) {
      ok=GetRss(tree,&title,&desc,&enc_url);
    }
  }
  if(ok) {
    sql=QString().sprintf("update CHANNEL_BUTTONS set CURRENT_TITLE=\"%s\",\
                           CURRENT_DESCRIPTION=\"%s\",\
                           CURRENT_ENCLOSURE_URL=\"%s\" \
                           where CLICK_LINK=\"%s\"",
			  (const char *)SqlEscape(title),
			  (const char *)SqlEscape(desc),
			  (const char *)SqlEscape(enc_url),
			  (const char *)SqlEscape(url));
    q=new QSqlQuery(sql);
    delete q;
    syslog(LOG_DEBUG,"updating banner metadata, url=\"%s\"",(const char *)url);
    /*
    printf("title: %s\n",(const char *)title);
    printf(" desc: %s\n",(const char *)desc);
    printf("  url: %s\n",(const char *)enc_url);
    printf("\n");
    */
  }
  else {
    syslog(LOG_WARNING,"banner metadata update failed, url=\"%s\"",
	   (const char *)url);
  }
  mxmlDelete(tree);
}


bool MainObject::GetPlaylist(mxml_node_t *tree,QString *title,QString *desc,
			     QString *url)
{
  mxml_node_t *node=NULL;
  bool ret=false;

  if((node=mxmlFindElement(tree,tree,"title",NULL,NULL,MXML_DESCEND))!=NULL) {
    if((node=node->child)!=NULL) {
      *title=LoadString(node);
      ret=true;
    }
  }
  else {
    syslog(LOG_WARNING,"missing \"title\" tag in playlist");
  }
  if((node=mxmlFindElement(tree,tree,"annotation",NULL,NULL,MXML_DESCEND))!=NULL) {
    if((node=node->child)!=NULL) {
      *desc=LoadString(node);
      ret=true;
    }
  }
  else {
    syslog(LOG_WARNING,"missing \"annotation\" tag in playlist");
  }
  if((node=mxmlFindElement(tree,tree,"info",NULL,NULL,MXML_DESCEND))!=NULL) {
    if((node=node->child)!=NULL) {
      *url=LoadString(node);
      ret=true;
    }
  }
  else {
    syslog(LOG_WARNING,"missing \"info\" tag in playlist");
  }
  return ret;
}


bool MainObject::GetRss(mxml_node_t *tree,QString *title,QString *desc,
			QString *url)
{
  mxml_node_t *node=NULL;
  bool ret=false;

  if((node=mxmlFindElement(tree,tree,"title",NULL,NULL,MXML_DESCEND))!=NULL) {
    if((node=node->child)!=NULL) {
      *title=LoadString(node);
      ret=true;
    }
  }
  else {
    syslog(LOG_WARNING,"missing \"title\" tag in RSS feed");
  }
  if((node=mxmlFindElement(tree,tree,"item",NULL,NULL,MXML_DESCEND))==NULL) {
    syslog(LOG_WARNING,"missing \"item\" tag in RSS feed");
  }
  if((node=mxmlFindElement(node,node,"description",NULL,NULL,MXML_DESCEND))!=NULL) {
    if((node=node->child)!=NULL) {
      *desc=LoadString(node);
      ret=true;
    }
  }
  else {
    syslog(LOG_WARNING,"missing \"description\" tag in RSS feed");
  }
  if((node=mxmlFindElement(tree,tree,"item",NULL,NULL,MXML_DESCEND))==NULL) {
    syslog(LOG_WARNING,"missing \"item\" tag in RSS feed");
  }
  if((node=mxmlFindElement(node,node,"enclosure","url",NULL,MXML_DESCEND))!=NULL) {
    if((node)!=NULL) {
      *url=mxmlElementGetAttr(node,"url");
      ret=true;
    }
  }
  else {
    syslog(LOG_WARNING,"missing \"enclosure\" tag in RSS feed");
  }

  return ret;
}


QString MainObject::LoadString(mxml_node_t *node)
{
  QString ret=node->value.text.string;
  while((node=node->next)!=NULL) {
    ret+=QString(" ")+node->value.text.string;
  }
  return ret;
}


int main(int argc,char *argv[])
{
  QApplication a(argc,argv,false);
  new MainObject(NULL,"main");
  return a.exec();
}
