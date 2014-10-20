#!/usr/bin/perl

# track.pl
#
# Serve a media link.
#
# (C) Copyright 2009-2011 Fred Gleason <fredg@paravelsystems.com>
#

use DBI;

do "common.pl";

#
# Banner Sizes
#
$player_banner_vtotal_width=120;
$player_banner_vtotal_height=240;
$player_banner_htotal_width=468;
$player_banner_htotal_height=60;

#
# Load Command Line
#
@ii=split /&/,$ENV{'QUERY_STRING'};
for ($i=0;$i<=$#ii;$i++) {
  @jj=split /=/,$ii[$i];  #/
  $cmdline{$jj[0]}=$jj[1];
}
if($cmdline{"upload_id"} eq "") {
  print "Content-type: text/html\n\n";
  printf "Missing upload_id!";
  exit 0;
}
my $upload_id=$cmdline{"upload_id"};

#
# Fire up the DB connection
#
do "/etc/loudwater_conf.pl";
$dbh=DBI->connect("dbi:mysql:$loudwater_db_dbname:$loudwater_db_hostname",
		  $loudwater_db_username,$loudwater_db_password);
if(!$dbh) {
    print $post->header(-type=>'text/html');
    print "unable to open database\n";
    exit 0;
}

#
# Fetch the upload info from the DB
#
my $sql=sprintf "select POSTS.CHANNEL_NAME,CHANNELS.TITLE,TAPS.ID,\
                 TAPS.TITLE,POSTS.ID,POSTS.TITLE,UPLOADS.DOWNLOAD_URL \
                 from UPLOADS \
                 left join POSTS on UPLOADS.POST_ID=POSTS.ID \
                 left join CHANNELS on POSTS.CHANNEL_NAME=CHANNELS.NAME \
                 left join TAPS on UPLOADS.TAP_ID=TAPS.ID where UPLOADS.ID=%d",
    $cmdline{"upload_id"};

my $q=$dbh->prepare($sql);
$q->execute();
if(!($row=$q->fetchrow_arrayref)) {
    print "Content-type: text/html\n\n";
    printf "Invalid upload id!";
    exit 0;
}
$channel_name=@$row[0];
$channel_title=@$row[1];
$tap_id=@$row[2];
$tap_title=@$row[3];
$post_id=@$row[4];
$post_title=@$row[5];
$download_url=@$row[6];
$q->finish();

#
#  Log the access
#
if(&ShouldCount()) {
    $player_title="";
    if($cmdline{"player"} ne "") {
	my $sql1="select TITLE from PLAYERS where NAME=\"".$cmdline{"player"}."\"";
	$q=$dbh->prepare($sql1);
	$q->execute();
	if($row=$q->fetchrow_arrayref) {
	    $player_title=@$row[0];
	}
	$q->finish();
    }
    &LogAccess("E",$ENV{"REMOTE_ADDR"},$ENV{"HTTP_USER_AGENT"},
	       $ENV{"HTTP_REFERER"},$cmdline{"name"},$player_title,
	       $cmdline{"button"},$cmdline{"url"},$cmdline{"brandid"},
	       $channel_name,$channel_title,$tap_id,$tap_title,$post_id,
	       $post_title);
}

#
# Serve the media link
#
print "Location: ".$download_url."\n\n";


sub ShouldCount()
{
    if($ENV{"HTTP_RANGE"} eq "") {
	return 1;
    }
    my $ret=0;
    @lines=split "\n",$ENV{"HTTP_RANGE"};
    for($i=0;$i<@lines;$i++) {
	@parts=split "=",$lines[$i];
	if($parts[0] eq "bytes") {
	    @ranges=split ",",$parts[1];
	    for($j=0;$j<@ranges;$j++) {
		@endpts=split "-",$ranges[$j];
		if($endpts[0] eq "") {
		    $ret=1;
		}
		if($endpts[0] eq "0") {
		    $ret=1;
		}
	    }
	}
    }
    return $ret;

}
