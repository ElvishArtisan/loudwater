#!/usr/bin/perl

# loudwater_update_db.pl
#
# (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
#
#  $Id: loudwater_update_db.pl,v 1.24 2012/04/25 20:56:04 pcvs Exp $
#
# Check the Loudwater database schema and update it as necessary.
#

use DBI;

do "/etc/loudwater_conf.pl";

sub EscapeString {
    $_=$_[0];
    s{\(}{\\(}g;
    s{\)}{\\)}g;
    s{\[}{\\[}g;
    s{\]}{\\]}g;
    s{\"}{\\"}g;
    s{\'}{\\'}g;
    s{\`}{\\`}g;
    s{\?}{\\?}g;
    s{\&}{\\&}g;
    s{\;}{\\;}g;
    s{\<}{\\<}g;
    s{\>}{\\>}g;
    s{\!}{\\!}g;

    return $_;
}


#
# Open the database
#
my $dbh=DBI->connect("dbi:mysql:$loudwater_db_dbname:$loudwater_db_hostname",
		     $loudwater_db_username,$loudwater_db_password);
if(!dbh) {
    print "unable to open database\n";
    exit 256;
}

#
# Get the schema version
#
my $sql="create table if not exists VERSION (DB int default 0)";
my $q=$dbh->prepare($sql);
$q->execute();
$q->finish();

$sql="select DB from VERSION";
$q=$dbh->prepare($sql);
if(!$q->execute()) {
    $q->finish();

    $sql="create table VERSION (DB int)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="insert into VERSION set DB=0";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="select DB from VERSION";
    $q=$dbh->prepare($sql);
    $q->execute();
}

my $row;
if(!($row=$q->fetchrow_arrayref)) {
    print "unable to initialize database\n";
    exit 256;
}
my $db_ver=@$row[0];
$q->finish();

#
# Apply schema updates
#
if($db_ver<1) {
    $sql="create table USERS (\
          ID int primary key auto_increment,\
          NAME char(32) unique,\
          PASSWORD char(255),\
          FULL_NAME char(255),\
          EMAIL_ADDRESS char(255),\
          PHONE_NUMBER char(255),\
          MANAGE_USERS_PRIV enum('N','Y') default 'N',\
          index NAME_IDX(NAME))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create table WEB_CONNECTIONS (\
          SESSION_ID int unsigned not null primary key,\
          LOGIN_NAME char(32),\
          IP_ADDRESS char(16),\
          TIME_STAMP datetime)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="insert into USERS set \
          NAME=\"admin\",\
          PASSWORD=\"\",\
          FULL_NAME=\"Default Administrator Account\",\
          MANAGE_USERS_PRIV=\"Y\"";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<2) {
    $sql="alter table USERS add column MANAGE_PLAYERS_PRIV enum('N','Y') \
              default 'N' after MANAGE_USERS_PRIV";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<3) {
    $sql="create table PLAYERS (\
          NAME char(8) not null primary key,\
          TITLE char(255) not null,\
          SPLASH_LINK char(255),\
          LIVE_LINK char(255),\
          DEFAULT_LINK char(255),\
          AUDIO_LOGO_LINK char(255),\
          VIDEO_LOGO_LINK char(255),\
          LIVE_DIVIDER_HOUR int default 0,\
          LIVE_ONDEMAND_LINK char(255),\
          LIVE_LIVE1_LINK char(255),\
          LIVE_LIVE2_LINK char(255),\
          LIVE_INACTIVE_LINK char(255),\
          SID int,\
          GATEWAY_QUALITY int default 1,\
          BUTTON_SECTION_IMAGE char(255),\
          BUTTON_COLUMNS int default 1,\
          BUTTON_ROWS int default 1,\
          TOP_BANNER_CODE text,\
          SIDE_BANNER_CODE text,\
          OPTIONAL_LINK_CODE text,\
          HEAD_CODE text\
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<4) {
    $sql="create table LIVE_SEGMENTS (\
          ID int unsigned auto_increment not null primary key,\
          PLAYER_NAME char(8) not null,\
          START_HOUR int not null,\
          RUN_LENGTH int not null,\
          SUN enum('N','Y') default 'N',\
          MON enum('N','Y') default 'N',\
          TUE enum('N','Y') default 'N',\
          WED enum('N','Y') default 'N',\
          THU enum('N','Y') default 'N',\
          FRI enum('N','Y') default 'N',\
          SAT enum('N','Y') default 'N'\
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<5) {
    $sql="create table CHANNEL_BUTTONS (\
          ID int unsigned auto_increment not null primary key,\
          PLAYER_NAME char(8) not null,\
          BUTTON_NUMBER int unsigned not null,\
          IMAGE_LINK char(255),\
          CLICK_LINK char(255),\
          unique PLAYER_NAME_IDX(PLAYER_NAME,BUTTON_NUMBER)\
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<6) {
    $sql="alter table LIVE_SEGMENTS add column LIVE_LINK char(255) \
          after RUN_LENGTH";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table LIVE_SEGMENTS add column LOGO_LINK char(255) \
          after LIVE_LINK";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="select NAME,LIVE_LINK,AUDIO_LOGO_LINK from PLAYERS";
    $q=$dbh->prepare($sql);
    $q->execute();
    while($row=$q->fetchrow_arrayref) {
	$sql=sprintf "update LIVE_SEGMENTS set LIVE_LINK=\"%s\",\
                      LOGO_LINK=\"%s\" where PLAYER_NAME=\"%s\"",
	    &EscapeString(@$row[1]),&EscapeString(@$row[2]),
	    &EscapeString(@$row[0]);
	my $q1=$dbh->prepare($sql);
	$q1->execute();
	$q1->finish();
    }
    $q->finish();
}

if($db_ver<7) {
    $sql="create table CHANNELS (\
          NAME char(8) not null primary key,\
          TITLE char(255),\
          DESCRIPTION text,\
          CATEGORY char(255),\
          LINK char(255),\
          COPYRIGHT char(255),\
          WEBMASTER char(255),\
          LANGUAGE char(5),\
          MAX_UPLOAD_SIZE int default 10000000 \
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create table CHANNEL_PERMS (\
          ID int unsigned auto_increment not null primary key,\
          USER_NAME char(32),\
          CHANNEL_NAME char(8) \
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table USERS add column MANAGE_CHANNELS_PRIV enum('N','Y') \
          default 'N' after MANAGE_PLAYERS_PRIV";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<8) {
    $sql="create table POSTS (\
          ID int unsigned auto_increment not null primary key,\
          CHANNEL_NAME char(8),\
          TITLE char(255),\
          DESCRIPTION text,\
          CATEGORY char(255),\
          LINK char(255),\
          COPYRIGHT char(255),\
          WEBMASTER char(255),\
          LANGUAGE char(5),\
          ACTIVE enum('N','Y') default 'N',\
          PARTS int unsigned, \
          ORIGIN_DATETIME datetime,\
          ORIGIN_ADDRESS char(16),\
          ORIGIN_USER_NAME char(32), \
          JOB_STATUS int unsigned default 0 \
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create table JOBS (\
          ID int unsigned auto_increment not null primary key,\
          POST_ID int unsigned,\
          PATH char(255), \
          STATUS int unsigned default 0 \
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<9) {
    $sql="alter table POSTS add column ORIGIN_HOSTNAME char(255) \
          after ORIGIN_DATETIME";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column ORIGIN_USER_AGENT char(255) \
          after ORIGIN_USER_NAME";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table JOBS add column PART int unsigned after POST_ID";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<10) {
    $sql="create table SERVERS (\
          HOSTNAME char(255) not null primary key,\
          IP_ADDRESS char(16),\
          TOTAL_THREADS int default 1,\
          INGEST_THREADS int default 1,\
          ENCODE_THREADS int default 1,\
          DISTRIBUTION_THREADS int default 1,\
          MAINTENANCE_THREADS int default 1 \
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table USERS add column MANAGE_SERVERS_PRIV enum('N','Y') \
          default 'N' after MANAGE_CHANNELS_PRIV";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<11) {
    $sql="alter table LIVE_SEGMENTS add column SID int default 0 \
          after LOGO_LINK";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNEL_BUTTONS add column SID int default 0 \
          after CLICK_LINK";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<12) {
    $sql="alter table JOBS add column HOSTNAME char(255) after POST_ID";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table JOBS add column PROCESS_ID int unsigned after HOSTNAME";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<13) {
    $sql="alter table JOBS add column TAP_ID int after POST_ID";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create table if not exists TAPS (\
          ID int unsigned auto_increment not null primary key,\
          CHANNEL_NAME char(8) not null,\
          TITLE char(64),\
          HEADER_XML text,\
          CHANNEL_XML text,\
          ITEM_XML text,\
          UPLOAD_URL char(255),\
          UPLOAD_USERNAME char(64),\
          UPLOAD_PASSWORD char(64),\
          DOWNLOAD_URL char(255),\
          DOWNLOAD_PREAMBLE char(255),\
          PING_URL char(255),\
          ORIGIN_DATETIME datetime,\
          LAST_BUILD_DATETIME datetime,\
          AUDIO_ENCODER char(255),\
          VIDEO_ENCODER char(255),\
          AUDIO_SAMPLERATE int,\
          AUDIO_CHANNELS int,\
          AUDIO_ONLY enum('N','Y') default 'N',
          index CHANNEL_NAME_IDX(CHANNEL_NAME) \
          )";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<14) {
    $sql="alter table TAPS add column AUDIO_EXTENSION char(8) \
          after AUDIO_ENCODER";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table TAPS add column VIDEO_EXTENSION char(8) \
          after VIDEO_ENCODER";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<15) {
    $sql="create table if not exists UPLOADS ( \
          ID int unsigned not null auto_increment primary key,\
          POST_ID int unsigned not null,\
          TAP_ID int unsigned not null,\
          URL char(255) not null,\
          TYPE enum('A','V') not null,\
          BYTE_LENGTH int unsigned not null,\
          UPLOAD_DATETIME datetime,\
          index POST_ID_IDX(POST_ID,TAP_ID))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<16) {
    $sql="alter table POSTS drop column JOB_STATUS";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column PROCESSING enum ('N','Y') default 'N' \
          after ORIGIN_USER_AGENT";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column DELETING enum ('N','Y') default 'N' \
          after PROCESSING";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<17) {
    $sql="create table if not exists PARTS ( \
          ID int unsigned not null auto_increment primary key,\
          POST_ID int unsigned not null,\
          PART int unsigned not null,\
          AUDIO_LENGTH int unsigned,\
          index POST_ID_IDX(POST_ID))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table TAPS add column DOWNLOAD_MIMETYPE char(64) \
          default \"application/rss+xml\" after DOWNLOAD_URL";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<18) {
    $sql="alter table PARTS add column CONTENT_TYPE enum('A','V') default 'A' \
          after PART";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<19) {
    $sql="alter table POSTS add column COMMENTS char(255) after LANGUAGE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<20) {
    $sql="alter table JOBS add column ERROR_TEXT text after STATUS";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<21) {
    $sql="alter table CHANNELS add column ALLOW_MULTIPART_POSTS enum ('N','Y')\
          default 'N' after MAX_UPLOAD_SIZE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<22) {
    $sql="alter table TAPS add column DELETING enum ('N','Y')\
          default 'N' after AUDIO_ONLY";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<23) {
    $sql="alter table TAPS add column AUDIO_MIMETYPE char(64) \
          default \"audio/mpeg\" after AUDIO_EXTENSION";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table TAPS add column VIDEO_MIMETYPE char(64) \
          default \"video/x-flv\" after VIDEO_EXTENSION";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<24) {
    $sql="create table if not exists THUMBNAILS ( \
          ID int unsigned not null auto_increment primary key,\
          CHANNEL_NAME char(8) not null,\
          URL char(255) not null,\
          index CHANNEL_NAME_IDX(CHANNEL_NAME))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column THUMBNAIL_ID int unsigned \
          after PARTS";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column THUMBNAIL_UPLOAD_URL char(255) \
          after LANGUAGE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column THUMBNAIL_UPLOAD_USERNAME char(64) \
          after THUMBNAIL_UPLOAD_URL";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column THUMBNAIL_UPLOAD_PASSWORD char(64) \
          after THUMBNAIL_UPLOAD_USERNAME";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column THUMBNAIL_DOWNLOAD_URL char(255) \
          after THUMBNAIL_UPLOAD_PASSWORD";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<25) {
    $sql="alter table UPLOADS add column DOWNLOAD_URL char(255) after URL";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<26) {
    $sql="alter table TAPS add column FOOTER_XML text after ITEM_XML";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<27) {
    $sql="alter table CHANNELS add column THUMBNAIL_ID int unsigned \
          after LANGUAGE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<28) {
    $sql="alter table THUMBNAILS add column FILENAME char(255) \
          after CHANNEL_NAME";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table THUMBNAILS drop column URL";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<29) {
    $sql="alter table CHANNELS add column AUTHOR char(255) after WEBMASTER";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column OWNER char(255) after AUTHOR";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column OWNER_EMAIL char(255) after OWNER";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column SUBTITLE char(255) after OWNER_EMAIL";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column CATEGORY_ITUNES char(255) \
          after SUBTITLE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column KEYWORDS text after CATEGORY_ITUNES";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNELS add column EXPLICIT enum('C','N','Y') \
          default 'N'\
          after KEYWORDS";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column SHORT_DESCRIPTION char(80) \
          after DESCRIPTION";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column AUTHOR char(255) after WEBMASTER";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column KEYWORDS text after AUTHOR";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column EXPLICIT enum('C','N','Y') default 'N'\
          after KEYWORDS";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<30) {
    $sql="create table if not exists EXAMPLE_XML ( \
          ID int unsigned not null auto_increment primary key,\
          NAME char(32) unique not null,\
          HEADER_XML text,\
          CHANNEL_XML text,\
          ITEM_XML text,\
          FOOTER_XML text,\
          index NAME_IDX(NAME))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="insert into EXAMPLE_XML set \
          NAME=\"RSS 2.0\",\
          HEADER_XML=\"<?xml version=\\\"1.0\\\" encoding=\\\"ISO-8859-1\\\"?><rss version=\\\"2.0\\\">\",\
          CHANNEL_XML=\"<channel>\n<title>%CHANNEL_TITLE%</title>\n<description>%CHANNEL_DESCRIPTION%</description>\n<category>%CHANNEL_CATEGORY%</category>\n<language>%CHANNEL_LANGUAGE%</language>\n<copyright>%CHANNEL_COPYRIGHT%</copyright>\n<lastBuildDate>%BUILD_DATE%</lastBuildDate>\n<pubDate>%PUBLISH_DATE%</pubDate>\n<webMaster>%CHANNEL_WEBMASTER%</webMaster>\n<generator>%GENERATOR%</generator>\n</channel>\n\",\
          ITEM_XML=\"<item>\n<title>%ITEM_TITLE%</title>\n<link>%ITEM_LINK%</link>\n<guid isPermaLink=\\\"false\\\">%ITEM_GUID%</guid>\n<description>%ITEM_DESCRIPTION%</description>\n<comments>%ITEM_COMMENTS%</comments>\n<enclosure url=\\\"%ITEM_CONTENT_URL%\\\" length=\\\"%ITEM_CONTENT_LENGTH%\\\"  type=\\\"%ITEM_CONTENT_MIMETYPE%\\\" />\n<category>%ITEM_CATEGORY%</category>\n<pubDate>%ITEM_PUBLISH_DATE%</pubDate>\n</item>\",\
          FOOTER_XML=\"\"";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<31) {
    $sql="insert into EXAMPLE_XML set \
          NAME=\"RSS 2.0 + iTunes\",\
          HEADER_XML=\"<rss version=\\\"2.0\\\"\nxmlns:itunes=\\\"http://www.itunes.com/dtds/podcast-1.0.dtd\\\"\nxmlns:atom=\\\"http://www.w3.org/2005/Atom\\\"\nxmlns:media=\\\"http://search.yahoo.com/mrss/\\\">\",\
          CHANNEL_XML=\"<channel>\n<title>%CHANNEL_TITLE%</title>\n<description>%CHANNEL_DESCRIPTION%</description>\n<category>%CHANNEL_CATEGORY%</category>\n<language>%CHANNEL_LANGUAGE%</language>\n<copyright>%CHANNEL_COPYRIGHT%</copyright>\n<lastBuildDate>%BUILD_DATE%</lastBuildDate>\n<pubDate>%PUBLISH_DATE%</pubDate>\n<webMaster>%CHANNEL_WEBMASTER%</webMaster>\n<image>\n  <url>%CHANNEL_IMAGE%</url>\n  <title>%CHANNEL_TITLE%</title>\n  <link>%CHANNEL_LINK%</link>\n</image>\n<itunes:subtitle>%CHANNEL_SUBTITLE%</itunes:subtitle>\n<itunes:author>%CHANNEL_AUTHOR%</itunes:author>\n<itunes:summary>%CHANNEL_DESCRIPTION%</itunes:summary>\n<itunes:owner>\n  <itunes:name>%CHANNEL_OWNER%</itunes:name>\n  <itunes:email>%CHANNEL_OWNER_EMAIL%</itunes:email>\n</itunes:owner>\n<itunes:image href=\\\"%CHANNEL_IMAGE%\\\" />\n<itunes:category text=\\\"%CHANNEL_CATEGORY_ITUNES%\\\">\n  <itunes:category text=\\\"%CHANNEL_CATEGORY_ITUNES%\\\" />\n</itunes:category>\n<itunes:explicit>%CHANNEL_EXPLICIT%</itunes:explicit>\n<itunes:keywords>%CHANNEL_KEYWORDS%</itunes:keywords>\n<generator>%GENERATOR%</generator>\n</channel>\n\",\
          ITEM_XML=\"<item>\n<title>%ITEM_TITLE%</title>\n<link>%ITEM_CONTENT_URL%</link>\n<guid>%ITEM_GUID%</guid>\n<description>%ITEM_DESCRIPTION%</description>\n<enclosure url=\\\"%ITEM_CONTENT_URL%\\\" length=\\\"%ITEM_CONTENT_LENGTH%\\\"  type=\\\"%ITEM_CONTENT_MIMETYPE%\\\" />\n<category>%ITEM_CATEGORY%</category>\n<pubDate>%ITEM_PUBLISH_DATE%</pubDate>\n<itunes:author>%ITEM_AUTHOR%</itunes:author>\n<itunes:duration>%ITEM_CONTENT_TIME%<itunes:duration>\n<itunes:keywords>%ITEM_KEYWORDS%</itunes:keywords>\n</item>\",\
          FOOTER_XML=\"\"";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="insert into EXAMPLE_XML set \
          NAME=\"Modieus\",\
          HEADER_XML=\"<playlist version=\\\"1\\\" xmlns=\\\"http://xspf.org/ns/0/\\\">\",\
          CHANNEL_XML=\"<tracklist>\n<title>%CHANNEL_TITLE%</title>\",\
          ITEM_XML=\"<track>\n<location>%ITEM_CONTENT_URL%</location>\n<title>%ITEM_TITLE%</title>\n<creator>%ITEM_WEBMASTER%</creator>\n<annotation>%ITEM_DESC_SHORT%</annotation>\n<info>%ITEM_CONTENT_URL%</info>\n<image>%ITEM_IMAGE%</image>\n<duration>%ITEM_CONTENT_TIME%</duration>\n<meta rel='tags'>%ITEM_PUBLISH_DATE%</meta>\n</track>\n\",\
          FOOTER_XML=\"</tracklist>\n</playlist>\n\"";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="insert into EXAMPLE_XML set \
          NAME=\"Mrss\",\
          HEADER_XML=\"<rss version=\\\"2.0\\\" xmlns:media=\\\"http://search.yahoo.com/mrss/\\\">\",\
          CHANNEL_XML=\"<channel>\n<title>%CHANNEL_TITLE%</title>\n<link>%CHANNEL_LINK%</link>\n<description>%CHANNEL_DESCRIPTION%</description>\n\",\
          ITEM_XML=\"<item>\n<title>%ITEM_TITLE%</title>\n<link>%ITEM_LINK%</link>\n<media:content\n  url=\\\"%ITEM_CONTENT_URL%\\\"\n  fileSize=\\\"%ITEM_CONTENT_LENGTH%\\\"\n  type=\\\"%ITEM_CONTENT_MIMETYPE%\\\"\n  medium=\\\"video\\\"\n  isDefault=\\\"true\\\"\n  expression=\\\"full\\\"\n  bitrate=\\\"128\\\"\n  framerate=\\\"25\\\"\n  samplingrate=\\\"44.1\\\"\n  channels=\\\"1\\\"\n  duration=\\\"185\\\"\n  height=\\\"200\\\"\n  width=\\\"300\\\"\n  lang=\\\"%ITEM_LANGUAGE%\\\" />\n<media:title>%ITEM_TITLE%</media:title>\n<media:description type=\\\"plain\\\">%ITEM_DESCRIPTION%</media:description>\n<media:keywords>%ITEM_KEYWORDS%</media:keywords>\n<media:thumbnail url=\\\"%ITEM_IMAGE%\\\" width=\\\"75\\\" height=\\\"50\\\" time=\\\"12:05:01.123\\\" />\n<media:player url=\\\"http://karen.radioamerica.org/loudwater/player.pl?name=pttest\\\" height=\\\"200\\\" width=\\\"400\\\" />\n<media:copyright url=\\\"http://blah.com/additional-info.html\\\">%ITEM_COPYRIGHT%</media:copyright>\n</item>\",\
          FOOTER_XML=\"</channel>\n</rss>\n\"";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

#    $sql="insert into EXAMPLE_XML set \
#          NAME=\"Modieus\",\
#          HEADER_XML=\"\",\
#          CHANNEL_XML=\"\",\
#          ITEM_XML=\"\",\
#          FOOTER_XML=\"\"";
#    $q=$dbh->prepare($sql);
#    $q->execute();
#    $q->finish();
}

if($db_ver<32) {
    $sql="alter table CHANNEL_BUTTONS add column MODE int default 0 \
          after BUTTON_NUMBER";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="select ID,BUTTON_NUMBER from CHANNEL_BUTTONS";
    $q=$dbh->prepare($sql);
    $q->execute();
    while(my $row=$q->fetchrow_arrayref) {
	if(@$row[1]==0) {
	    $sql=sprintf "update CHANNEL_BUTTONS set MODE=1 where ID=%u",
	                 @$row[0];
	    $q1=$dbh->prepare($sql);
	    $q1->execute();
	    $q1->finish();
	}
    }
    $q->finish();
}

if($db_ver<33) {
    $sql="alter table POSTS add column LAST_MODIFIED_DATETIME datetime \
          after ORIGIN_USER_AGENT";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column AIR_DATE date after COMMENTS";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add column AIR_HOUR int after AIR_DATE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="select ID,ORIGIN_DATETIME from POSTS";
    $q=$dbh->prepare($sql);
    $q->execute();
    while(my $row=$q->fetchrow_arrayref) {
	$sql=sprintf "update POSTS set AIR_DATE=\"%s\" where ID=%u",
	     substr(@$row[1],0,10),@$row[0];
	$q1=$dbh->prepare($sql);
	$q1->execute();
	$q1->finish();
    }
    $q->finish();
}

if($db_ver<34) {
    $sql="alter table TAPS add column VISIBILITY_WINDOW int default 0 \
          after TITLE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<35) {
    $sql="alter table PLAYERS add column USE_SYNCHED_BANNERS enum ('N','Y') \
          default 'Y' after SID";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<36) {
    $sql="alter table JOBS add index POST_ID_IDX(POST_ID)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table JOBS add index TAP_ID_IDX(TAP_ID)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table JOBS add index PATH_IDX(ID,PATH)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table JOBS add index STATUS_IDX(STATUS)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table JOBS add index HOSTNAME_IDX(HOSTNAME,STATUS)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNEL_PERMS add index \
          USER_NAME_IDX(USER_NAME,CHANNEL_NAME)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table LIVE_SEGMENTS add index \
          PLAYER_NAME_ID(PLAYER_NAME,START_HOUR)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add index CHANNEL_NAME_IDX(CHANNEL_NAME)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table POSTS add index DELETING_IDX(DELETING)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table UPLOADS add index TAP_ID_IDX(TAP_ID)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table TAPS add index DELETING_IDX(DELETING)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<37) {
    $sql="alter table TAPS add column VALIDATION_URL char(255) after PING_URL";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<38) {
    $sql="alter table PLAYERS add column BGCOLOR char(7) default \"#000000\" \
          after TITLE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<39) {
    $sql="alter table PLAYERS add column PLAYLIST_FGCOLOR char(7) \
          default \"#FFFFFF\" after BGCOLOR";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table PLAYERS add column PLAYLIST_BGCOLOR char(7) \
          default \"#000000\" after PLAYLIST_FGCOLOR";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table PLAYERS add column PLAYLIST_HGCOLOR char(7) \
          default \"#FFFFFF\" after PLAYLIST_BGCOLOR";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<40) {
    $sql="alter table PLAYERS add column BASE_BRANDING_LINK char(255) \
          after LIVE_INACTIVE_LINK";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<41) {
    $sql="alter table PLAYERS add column PLAYLIST_SGCOLOR char(7) \
          default \"#FFFFFF\" after PLAYLIST_FGCOLOR";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<42) {
    $sql="alter table CHANNEL_BUTTONS add column CURRENT_TITLE char(255) \
          after SID";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNEL_BUTTONS add column CURRENT_DESCRIPTION text \
          after CURRENT_TITLE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table CHANNEL_BUTTONS add column LAST_UPDATE datetime \
          after CURRENT_DESCRIPTION";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create index LAST_UPDATE_IDX on CHANNEL_BUTTONS (LAST_UPDATE)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<43) {
    $sql="alter table CHANNEL_BUTTONS add column CURRENT_ENCLOSURE_URL \
          char(255) after CURRENT_DESCRIPTION";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create index CLICK_LINK_IDX on CHANNEL_BUTTONS (CLICK_LINK)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<44) {
    $sql="alter table PLAYERS add column BANNER_VIMAGE_URL \
          char(255) after BASE_BRANDING_LINK";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table PLAYERS add column BANNER_VIMAGE_HEIGHT int \
                after BANNER_VIMAGE_URL";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table PLAYERS add column BANNER_HIMAGE_URL \
          char(255) after BANNER_VIMAGE_HEIGHT";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table PLAYERS add column BANNER_HIMAGE_WIDTH int \
          after BANNER_HIMAGE_URL";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<45) {
    $sql="create table if not exists ACCESS_LOG (\
          ID int unsigned not null primary key auto_increment,\
          ACCESS_TYPE enum('P','B','C','E'),\
          ACCESS_DATETIME datetime not null,\
          IPV4_ADDRESS char(16) not null,\
          USER_AGENT char(255),\
          REFERER_URL char(255),\
          PLAYER_NAME char(8),\
          PLAYER_TITLE char(255),\
          PLAYER_URL char(255),\
          PLAYER_BRANDING char(32),\
          CHANNEL_NAME char(8),\
          CHANNEL_TITLE char(255),\
          CHANNEL_TAP_ID int unsigned,\
          CHANNEL_TAP_TITLE char(64),\
          POST_ID int unsigned,\
          POST_TITLE char(255),\
          UPLOAD_ID int unsigned,\
          index PLAYER_IDX(ACCESS_DATETIME,PLAYER_NAME),
          index CHANNEL_IDX(ACCESS_DATETIME,CHANNEL_NAME),
          index POST_IDX(ACCESS_DATETIME,POST_ID))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<46) {
    $sql="alter table PLAYERS add column LAYOUT enum('S','W') default 'S' \
          after TITLE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<47) {
    $sql="alter table CHANNEL_BUTTONS add column ACTIVE_IMAGE_LINK char(255) \
          after IMAGE_LINK";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="select ID,IMAGE_LINK from CHANNEL_BUTTONS";
    $q=$dbh->prepare($sql);
    $q->execute();
    while(my $row=$q->fetchrow_arrayref) {
	$sql=sprintf "update CHANNEL_BUTTONS set ACTIVE_IMAGE_LINK=\"%s\" where ID=%u",
	@$row[1],@$row[0];
	$q1=$dbh->prepare($sql);
	$q1->execute();
	$q1->finish();
    }
    $q->finish();
}

if($db_ver<48) {
    $sql="alter table PLAYERS add column SOCIAL_TEST enum('N','Y') \
          default 'N' after HEAD_CODE";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table PLAYERS add column SOCIAL_FACEBOOK enum('N','Y') \
          default 'N' after SOCIAL_TEST";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create table if not exists REMAPS (\
          LINK char(10) not null primary key,\
          NAME char(8) not null,\
          STYLE char(8) not null,\
          BUTTON int not null,\
          URL char(255) not null,\
          BRANDID int not null,\
          unique index TARGET_IDX(NAME,STYLE,BUTTON,URL,BRANDID))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create table if not exists PLAYLIST_METADATA (\
          ID int unsigned not null primary key auto_increment,\
          PLAYLIST_URL char(255) not null,\
          ENCLOSURE_URL char(255) not null,\
          UPDATE_DATETIME datetime not null,\
          ITEM_TITLE text,\
          ITEM_DESCRIPTION text,\
          ITEM_IMAGE_URL char(255),\
          CHANNEL_TITLE text,\
          unique index URL_IDX(PLAYLIST_URL,ENCLOSURE_URL),\
          index UPDATE_DATETIME_IDX(UPDATE_DATETIME))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table PLAYERS add column SOCIAL_FACEBOOK_ADMIN char(255) \
          after SOCIAL_FACEBOOK";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<49) {
    $sql="alter table PLAYERS add column PLAYLIST_POSITION \
          enum('bottom','left','right','over','none') default 'over' \
          after LAYOUT";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<50) {
    $sql="alter table PLAYERS add column SOCIAL_DISPLAY_LINK enum('N','Y') \
          default 'N' after SOCIAL_FACEBOOK_ADMIN";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<51) {
    $sql="alter table TAPS add column IS_TRANSPARENT enum('N','Y') \
          default 'N' after LAST_BUILD_DATETIME";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="alter table TAPS add index IS_TRANSPARENT_IDX(IS_TRANSPARENT)";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

if($db_ver<52) {
    $sql="create table if not exists FEEDSETS (".
	"ID int unsigned not null primary key auto_increment,".
	"SET_NAME char(8) not null,".
	"SUN enum('N','Y') not null default 'N',".
	"MON enum('N','Y') not null default 'N',".
	"TUE enum('N','Y') not null default 'N',".
	"WED enum('N','Y') not null default 'N',".
	"THU enum('N','Y') not null default 'N',".
	"FRI enum('N','Y') not null default 'N',".
	"SAT enum('N','Y') not null default 'N',".
	"START_TIME time not null,".
	"END_TIME time not null,".
	"NAME char(64) not null,".
	"MOUNT_POINT char(255) not null,".
	"TYPE char(32) not null,".
	"index SET_NAME_IDX(SET_NAME,SUN,MON,TUE,WED,THU,FRI,SAT,START_TIME,END_TIME))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


$sql="update VERSION set DB=52";
$q=$dbh->prepare($sql);
$q->execute();
$q->finish();

$dbh->disconnect;
