// common.h
//
// Loudwater Processing Daemon
//
//   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//      $Id: common.h,v 1.2 2010/09/03 14:49:23 pcvs Exp $
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

#ifndef COMMON_H
#define COMMON_H

#include <qstring.h>

//
// Job States
//
// FIXME: This must be kept in sync with the values in 'htdocs/admin.pl'.
//
#define JOB_STATE_COMPLETE 0
#define JOB_STATE_UPLOADING 1
#define JOB_STATE_INGEST_QUEUED 2
#define JOB_STATE_INGESTING 3
#define JOB_STATE_ENCODE_QUEUED 4
#define JOB_STATE_ENCODING 5
#define JOB_STATE_DISTRIBUTION_QUEUED 6
#define JOB_STATE_DISTRIBUTING 7
#define JOB_STATE_DELETION_QUEUED 8
#define JOB_STATE_DELETING 9
#define JOB_STATE_TAP_DELETION_QUEUED 10
#define JOB_STATE_LAST_GOOD_STATE 99
#define JOB_STATE_INTERNAL_ERROR 100
#define JOB_STATE_UNKNOWN_FILETYPE_ERROR 101
#define JOB_STATE_ENCODER_ERROR 102
#define JOB_STATE_DISTRIBUTION_ERROR 103
#define JOB_STATE_TAP_DELETION_ERROR 104
#define JOB_STATE_MISSING_ENCODER_ERROR 105

//
// File Types
//
// FIXME: This must be kept in sync with the values in 'htdocs/admin.pl'.
//
#define FILE_TYPE_INGEST 1
#define FILE_TYPE_ENCODE 2
#define FILE_TYPE_UPLOAD 3

//
// The time to wait between updating channel metadata for banners (secs)
//
#define CHANNEL_METADATA_UPDATE_INTERVAL 300

//
// Utility Methods
//
bool MatchPerms(const QString &srcfile,const QString &destfile);
QString SqlEscape(const QString &str);
QString FileExtension(const QString &pathname);
QString QueueFilePath(int file_type,int post_id,int partnum,int tap_id,
		      const QString &extension);
void Enqueue(int job_state,const QString &errtext,const QString &filename,
	     int post_id,int job_id);
void Abort(int job_state,const QString &filename,int job_id,int post_id);
void ClearPost(uint post_id);
long unsigned VstatsLength(const QString &filename);
QString GetErrorText(const QString &filename);

#endif  // COMMON_H
