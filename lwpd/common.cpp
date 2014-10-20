// common.h
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: common.cpp,v 1.2 2014/05/09 15:43:17 pcvs Exp $
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
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <qstringlist.h>
#include <qsqldatabase.h>

#include <common.h>

bool MatchPerms(const QString &srcfile,const QString &destfile)
{
  struct stat st;

  memset(&st,0,sizeof(st));
  if(stat(srcfile,&st)<0) {
    return false;
  }
  chown(destfile,st.st_uid,st.st_gid);
  chmod(destfile,st.st_mode);

  return true;
}

QString SqlEscape(const QString &str)
{
  QString res;

  for(unsigned i=0;i<str.length();i++) {
    switch(((const char *)str)[i]) {
	case '(':
	  res+=QString("\\\(");
	  break;

	case ')':
	  res+=QString("\\)");
	  break;

	case '{':
	  res+=QString("\\\{");
	  break;

	case '"':
	  res+=QString("\\\"");
	  break;

	case '`':
	  res+=QString("\\`");
	  break;

	case '[':
	  res+=QString("\\\[");
	  break;

	case '\'':
	  res+=QString("\\\'");
	  break;

	case '\\':
	  res+=QString("\\");
	  res+=QString("\\");
	  break;

	case '?':
	  res+=QString("\\\?");
	  break;

	case ' ':
	  res+=QString("\\ ");
	  break;

	case '&':
	  res+=QString("\\&");
	  break;

        case ';':
	  res+=QString("\\;");
	  break;

        case '<':
	  res+=QString("\\<");
	  break;

        case '>':
	  res+=QString("\\>");
	  break;

        case '|':
	  res+=QString("\\|");
	  break;

	default:
	  res+=((const char *)str)[i];
	  break;
    }
  }
  return res;
}


QString FileExtension(const QString &pathname)
{
  QStringList list=list.split(".",pathname);
  return list[list.size()-1];
}


//
// FIXME: This must be kept in sync with the QueueFilePath function in
//        'htdocs/admin.pl'.
//
QString QueueFilePath(int file_type,int post_id,int partnum,int tap_id,
		      const QString &extension)
{
  QString ret="/var/cache/loudwater/";
  switch(file_type) {
  case FILE_TYPE_INGEST:
    ret+="ingest/";
    break;

  case FILE_TYPE_ENCODE:
    ret+="encode/";
    break;

  case FILE_TYPE_UPLOAD:
    ret+="upload/";
    break;

  default:
    return QString();
  }
  ret+=QString().sprintf("%09d_%03d",post_id,partnum);
  if(tap_id>0) {
    ret+=QString().sprintf("_%09d",tap_id);
  }
  ret+=QString().sprintf(".%s",(const char *)extension);
  return ret;
}


void Enqueue(int job_state,const QString &errtext,const QString &filename,
	     int post_id,int job_id)
{
  QString sql;
  QSqlQuery *q;
  sql=QString().sprintf("update JOBS set \
                         PATH=\"%s\",\
                         STATUS=%d,\
                         ERROR_TEXT=\"%s\",\
                         HOSTNAME=null,\
                         PROCESS_ID=null \
                         where ID=%d",
			(const char *)SqlEscape(filename),
			job_state,
			(const char *)SqlEscape(errtext),
			job_id);
  q=new QSqlQuery(sql);
  delete q;
}


void Abort(int job_state,const QString &filename,int job_id,int post_id)
{
  QString sql;
  QSqlQuery *q;

  if(!filename.isNull()) {
    unlink(filename);
  }

  //  sql=QString().sprintf("delete from JOBS where ID=%d",job_id);
  sql=QString().sprintf("update JOBS set STATUS=%d where ID=%d",
			job_state,job_id);
  q=new QSqlQuery(sql);
  delete q;
}


void ClearPost(uint post_id)
{
  QString sql;
  QSqlQuery *q;
  QSqlQuery *q1;

  sql=QString().sprintf("select ID from JOBS where POST_ID=%u",post_id);
  q=new QSqlQuery(sql);
  if(!q->first()) {
    sql=QString().sprintf("delete from PARTS where POST_ID=%u",post_id);
    q1=new QSqlQuery(sql);
    delete q1;

    sql=QString().sprintf("delete from POSTS where ID=%u",post_id);
    q1=new QSqlQuery(sql);
    delete q1;
  }
  delete q;
}


long unsigned VstatsLength(const QString &filename)
{
  FILE *f=NULL;
  QStringList list;
  char prev_line[256];
  char line[256];
  long unsigned ret=0;
  bool ok=false;

  if((f=fopen(filename,"r"))==NULL) {
    return ret;
  }
  while(fgets(line,256,f)!=NULL) {
    strcpy(prev_line,line);
  }
  list=list.split(" ",prev_line);
  for(unsigned i=0;i<list.size();i++) {
    if(list[i]=="time=") {
      double len=list[i+1].toDouble(&ok);
      if(ok) {
	return 1000*len;
      }
    }
  }
  
  fclose(f);
  return ret;
}


QString GetErrorText(const QString &filename)
{
  int fd;
  char err[256];
  int n;
  QString ret="";

  if((fd=open(filename,O_RDONLY))>=0) {
    while((n=read(fd,err,255))>0) {
      err[n]=0;
      ret+=QString(err);
    }
    close(fd);
    ret=ret.simplifyWhiteSpace();
  }
  return ret;
}
