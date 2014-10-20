#!/usr/bin/perl

# feed.pl
#
# Loudwater Playlist Generator
#
# (C) Copyright 2009 Fred Gleason <fgleason@radiomaerica.org>
#

use CGI;
use DBI;
use Date::Format;
use Date::Calc qw(:all);
use File::Basename;

do "version.pl";
do "common.pl";
do "/etc/loudwater_conf.pl";

#
# FIXME: We should make this configurable in the database.
#
use constant USE_TIMEZONE=>'EST';

#
# Open the database
#
$dbh=DBI->connect("dbi:mysql:$loudwater_db_dbname:$loudwater_db_hostname",
		  $loudwater_db_username,$loudwater_db_password);
if(!$dbh) {
    print $post->header(-type=>'text/html');
    print "unable to open database\n";
    exit 0;
}

#
# Process the form
#
$post=new CGI;

#    my @names=$post->param();
#    my $count=0;
#    print "Content-type: text/html\n\n";
#    while(defined @names[$count]) {
#	printf "header: %s<br>\n",@names[$count++];
#    }
#    exit 0;

#
# Validate the Tap ID
#
$tap_id=$post->param("tap");

if($tap_id==0) {
    print $post->header(-type=>'text/html');
    print "Invalid tap ID\n";
    exit 0;
}

#
# Header/Channel Sections
#
my $sql=&ChannelQuery($tap_id);
my $q=$dbh->prepare($sql);
$q->execute();
my $row;
if(!($row=$q->fetchrow_arrayref)) {
    print "Content-type: text/html\n\n";
    print "Invalid tap id\n";
    exit 0;
}   

printf "Content-type: %s\n\n",@$row[4];
print @$row[0];
print &ResolveChannelWildcards($row,@$row[1]);

#
# Item Section
#
$sql=&ItemQuery($tap_id,@$row[24]);
my $q1=$dbh->prepare($sql);
$q1->execute();
my $row1;
while($row1=$q1->fetchrow_arrayref) {
    print &ResolveItemWildcards($row,$row1,@$row[2],$post);
}
$q1->finish();


#
# Footer Section
#
print @$row[3];

#
# Log the access
#
$player_name=$post->param("player");
$player_title="";
if($player_name ne "") {
    my $sql1="select TITLE from PLAYERS where NAME=\"".$player_name."\"";
    $q1=$dbh->prepare($sql1);
    $q1->execute();
    if($row1=$q1->fetchrow_arrayref) {
	$player_title=@$row1[0];
    }
    $q1->finish;
}
&LogAccess("C",$ENV{"REMOTE_ADDR"},$ENV{"HTTP_USER_AGENT"},
	   $ENV{"HTTP_REFERER"},$cmdline{"PLAYER_NAME"},$player_title,
	   $cmdline{"button"},$cmdline{"url"},$cmdline{"brandid"},@$row[5],
	   @$row[6],$tap_id,@$row[26],"","");
$q->finish();

sub ChannelQuery {
    return sprintf "select TAPS.HEADER_XML,TAPS.CHANNEL_XML,TAPS.ITEM_XML,\
                    TAPS.FOOTER_XML,TAPS.DOWNLOAD_MIMETYPE,CHANNELS.NAME,\
                    CHANNELS.TITLE,CHANNELS.DESCRIPTION,\
                    CHANNELS.CATEGORY,CHANNELS.LINK,CHANNELS.COPYRIGHT,\
                    CHANNELS.WEBMASTER,CHANNELS.LANGUAGE,\
                    CHANNELS.AUTHOR,CHANNELS.OWNER,CHANNELS.OWNER_EMAIL,\
                    CHANNELS.SUBTITLE,CHANNELS.CATEGORY_ITUNES,\
                    CHANNELS.KEYWORDS,CHANNELS.EXPLICIT,\
                    CHANNELS.THUMBNAIL_DOWNLOAD_URL,\
                    THUMBNAILS.FILENAME,\
                    TAPS.ORIGIN_DATETIME,TAPS.LAST_BUILD_DATETIME,\
                    TAPS.VISIBILITY_WINDOW,TAPS.ID,TAPS.TITLE \
                    from TAPS right join CHANNELS \
                    on TAPS.CHANNEL_NAME=CHANNELS.NAME \
                    left join THUMBNAILS on \
                    CHANNELS.THUMBNAIL_ID=THUMBNAILS.ID \
                    where TAPS.ID=%u",$_[0];
}


sub ResolveChannelWildcards {
    my $row=$_[0];
    my $thumbnail=@$row[20]."/".@$row[21];
    my $field;
    $_=$_[1];
    $field=&EscapeHtml(@$row[5]);
    s{%CHANNEL_NAME%}{$field}g;
    $field=&EscapeHtml(@$row[6]);
    s{%CHANNEL_TITLE%}{$field}g;
    $field=&EscapeHtml(@$row[7]);
    s{%CHANNEL_DESCRIPTION%}{$field}g;
    $field=&EscapeHtml(@$row[8]);
    s{%CHANNEL_CATEGORY%}{$field}g;
    s{%CHANNEL_LINK%}{@$row[9]}g;
    $field=&EscapeHtml(@$row[10]);
    s{%CHANNEL_COPYRIGHT%}{$field}g;
    $field=&EscapeHtml(@$row[11]);
    s{%CHANNEL_WEBMASTER%}{$field}g;
    $field=&EscapeHtml(@$row[12]);
    s{%CHANNEL_LANGUAGE%}{$field}g;
    $field=&EscapeHtml(@$row[13]);
    s{%CHANNEL_AUTHOR%}{$field}g;
    $field=&EscapeHtml(@$row[14]);
    s{%CHANNEL_OWNER%}{$field}g;
    $field=&EscapeHtml(@$row[15]);
    s{%CHANNEL_OWNER_EMAIL%}{$field}g;
    $field=&EscapeHtml(@$row[16]);
    s{%CHANNEL_SUBTITLE%}{$field}g;
    $field=&EscapeHtml(@$row[17]);
    s{%CHANNEL_CATEGORY_ITUNES%}{$field}g;
    $field=&EscapeHtml(@$row[18]);
    s{%CHANNEL_KEYWORDS%}{$field}g;
    if(@$row[19] eq "Y") {
	s{%CHANNEL_EXPLICIT%}{yes}g;
    }
    if(@$row[19] eq "N") {
	s{%CHANNEL_EXPLICIT%}{no}g;
    }
    if(@$row[19] eq "C") {
	s{%CHANNEL_EXPLICIT%}{clean}g;
    }
    s{%CHANNEL_IMAGE%}{$thumbnail}g;
    my $origin_datetime=&RSSTimeStamp(@$row[22]);
    s{%PUBLISH_DATE%}{$origin_datetime}g;
    my $last_build_datetime=&RSSTimeStamp(@$row[23]);
    s{%BUILD_DATE%}{$last_build_datetime}g;
    my @proto=split "/",$ENV{"SERVER_PROTOCOL"};
    my $tap_url=
	$proto[0]."://".$ENV{"SERVER_NAME"}."/loudwater/feed.pl?tap=".@$row[25];
    s{%TAP_URL%}{$tap_url}g;
    my $generator=sprintf "loudwater %s",$loudwater_version;
    s{%GENERATOR%}{$generator}g;
    return $_;
}


sub ItemQuery {
    my $sql=sprintf "select POSTS.CHANNEL_NAME,POSTS.TITLE,POSTS.DESCRIPTION,\
                     POSTS.SHORT_DESCRIPTION,\
                     POSTS.CATEGORY,POSTS.LINK,POSTS.COPYRIGHT,POSTS.WEBMASTER,\
                     POSTS.COMMENTS,POSTS.AUTHOR,POSTS.KEYWORDS,\
                     POSTS.LANGUAGE,POSTS.ORIGIN_DATETIME,\
                     TAPS.LAST_BUILD_DATETIME,UPLOADS.DOWNLOAD_URL,\
                     DOWNLOAD_PREAMBLE,\
                     UPLOADS.BYTE_LENGTH,PARTS.AUDIO_LENGTH,UPLOADS.TYPE,\
                     TAPS.AUDIO_MIMETYPE,TAPS.VIDEO_MIMETYPE,\
                     THUMBNAILS.FILENAME,\
                     POSTS.AIR_DATE,POSTS.AIR_HOUR,\
                     POSTS.LAST_MODIFIED_DATETIME,UPLOADS.ID \
                     from TAPS right join POSTS \
                     on TAPS.CHANNEL_NAME=POSTS.CHANNEL_NAME right join UPLOADS\
                     on (UPLOADS.TAP_ID=TAPS.ID)&&(UPLOADS.POST_ID=POSTS.ID) \
                     left join PARTS on POSTS.ID=PARTS.POST_ID \
                     left join THUMBNAILS on POSTS.THUMBNAIL_ID=THUMBNAILS.ID \
                     where (TAPS.ID=%u)&&(POSTS.ACTIVE=\"Y\") ",$_[0];
#    print "Content-type: text\html\n\n";
#    print $sql;
#    exit 0;
    if($_[1]>0) {  # Visibility Window
	my @end_date=Today;
	my @start_date=Add_Delta_Days(@end_date,-$_[1]);
	$sql=
	    $sql.sprintf "&&(AIR_DATE>\"%s-%s-%s\")&&(AIR_DATE<=\"%s-%s-%s\") ",
	$start_date[0],$start_date[1],$start_date[2],
	$end_date[0],$end_date[1],$end_date[2];
    }
    $sql=$sql."order by POSTS.AIR_DATE desc,POSTS.AIR_HOUR,\
               POSTS.ORIGIN_DATETIME desc";
    return $sql;
}


sub ResolveItemWildcards {
    my $row=$_[0];
    my $row1=$_[1];
    my $post=$_[3];
    my $field;

    #
    # Build ITEM_CONTENT_URL
    #
    ### Static Implementation ###
    my $item_content_url=@$row1[14];
    my @url=split "//",@$row1[14];
    if(scalar @url==2) {
	$item_content_url=$url[0]."//".@$row1[15].$url[1];
    }
    ### End of Static Implementation ###

    ### Dynamic Implementation ###
#    my $item_content_url=@$row1[15]."http://".$ENV{"SERVER_NAME"}.
#	"/loudwater/track.pl?upload_id=".@$row1[25];
#    if($post->param("player") ne "") {
#	$item_content_url=
#	    $item_content_url."&amp;player=".$post->param("player");
#    }
#    if($post->param("brandid") ne "") {
#	$item_content_url=
#	    $item_content_url."&amp;brandid=".$post->param("brandid");
#    }
    ### End of Dynamic Implementation ###

    $_=&basename(@$row1[14]);
    s{\.}{_}g;
    my $guid=$_;
    $_=&ResolveChannelWildcards($row,$_[2]);
    $field=&EscapeHtml(@$row1[0]);
    s{%ITEM_NAME%}{$field}g;
    $field=&EscapeHtml(@$row1[1]);
    s{%ITEM_TITLE%}{$field}g;
    $field=&EscapeHtml(@$row1[2]);
    s{%ITEM_DESCRIPTION%}{$field}g;
    $field=&EscapeHtml(@$row1[3]);
    s{%ITEM_DESC_SHORT%}{$field}g;
    $field=&EscapeHtml(@$row1[4]);
    s{%ITEM_CATEGORY%}{$field}g;
    s{%ITEM_LINK%}{@$row1[5]}g;
    $field=&EscapeHtml(@$row1[6]);
    s{%ITEM_COPYRIGHT%}{$field}g;
    $field=&EscapeHtml(@$row1[7]);
    s{%ITEM_WEBMASTER%}{$field}g;
    $field=&EscapeHtml(@$row1[8]);
    s{%ITEM_COMMENTS%}{$field}g;
    $field=&EscapeHtml(@$row1[9]);
    s{%ITEM_AUTHOR%}{$field}g;
    $field=&EscapeHtml(@$row1[10]);
    s{%ITEM_KEYWORDS%}{$field}g;
    $field=&EscapeHtml(@$row1[11]);
    s{%ITEM_LANGUAGE%}{$field}g;
    my $origin_datetime=&RSSTimeStamp(@$row1[12]);
    s{%ITEM_PUBLISH_DATE%}{$origin_datetime}g;
    s{%ITEM_CONTENT_URL%}{$item_content_url}g;
    s{%ITEM_CONTENT_LENGTH%}{@$row1[16]}g;
    $timelen=@$row1[17];
    s{%ITEM_CONTENT_MSECS%}{$timelen}g;
    $timelen=&MsecsToString(@$row1[17]);
    s{%ITEM_CONTENT_TIME%}{$timelen}g;
    s{%ITEM_GUID%}{$guid}g;
    if(@$row1[18] eq "A") {
	s{%ITEM_CONTENT_MIMETYPE%}{@$row1[19]}g;
    }
    else {
	s{%ITEM_CONTENT_MIMETYPE%}{@$row1[20]}g;
    }
    $thumbnail=@$row[20]."/".@$row1[21];
    s{%ITEM_IMAGE%}{$thumbnail}g;
    my $air_date=&RSSTimeStamp(@$row1[22]);
    s{%ITEM_AIR_DATE%}{$air_date}g;
    my $air_hour=@$row1[23];
    s{%ITEM_AIR_HOUR%}{$air_hour}g;
    my $last_modified_datetime=&RSSTimeStamp(@$row1[24]);
    s{%ITEM_LAST_MODIFIED_DATETIME%}{$last_modified_datetime}g;

    return $_;
}
