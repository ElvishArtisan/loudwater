#!/usr/bin/perl

# banner.pl
#
# Serve a banner widget
#
# (C) Copyright 2009-2011 Fred Gleason <fgleason@radiomaerica.org>
#

use DBI;

do "common.pl";

#
# Banner Sizes
#
$player_banner_default_vtotal_width=120;
$player_banner_default_vtotal_height=240;
$player_banner_default_htotal_width=468;
$player_banner_default_htotal_height=60;

$player_banner_vtotal_width=$player_banner_default_vtotal_width;
$player_banner_vtotal_height=$player_banner_default_vtotal_height;
$player_banner_htotal_width=$player_banner_default_htotal_width;
$player_banner_htotal_height=$player_banner_default_htotal_height;

#
# Load Command Line
#
@ii=split /&/,$ENV{'QUERY_STRING'};
for ($i=0;$i<=$#ii;$i++) {
  @jj=split /=/,$ii[$i];  #/
  $cmdline{$jj[0]}=$jj[1];
}
if($cmdline{"name"} eq "") {
  print "Content-type: text/html\n\n";
  printf "Missing player name!";
  exit 0;
}
if($cmdline{"width"} ne "") {
  $player_banner_vtotal_width=$cmdline{"width"};
  $player_banner_htotal_width=$cmdline{"width"};
}
if($cmdline{"height"} ne "") {
  $player_banner_vtotal_height=$cmdline{"height"};
  $player_banner_htotal_height=$cmdline{"height"};
}
my $is_https=false;
if($ENV{'HTTPS'} eq "on") {
    $is_https=true;
}

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
# Fetch the player setup from the DB
#
my $sql=sprintf "select TITLE,PLAYLIST_FGCOLOR,PLAYLIST_BGCOLOR,\
                 PLAYLIST_HGCOLOR,PLAYLIST_SGCOLOR,BGCOLOR,\
                 BANNER_VIMAGE_URL,BANNER_VIMAGE_HEIGHT,\
                 BANNER_HIMAGE_URL,BANNER_HIMAGE_WIDTH,BASE_BRANDING_LINK \
                 from PLAYERS where NAME=\"%s\"",
    $cmdline{"name"};

my $q=$dbh->prepare($sql);
$q->execute();
if(!($row=$q->fetchrow_arrayref)) {
    print "Content-type: text/html\n\n";
    printf "Invalid player name!";
    exit 0;
}
$player_title=@$row[0];
$player_playlist_fgcolor=@$row[1];
$player_playlist_bgcolor=@$row[2];
$player_playlist_hgcolor=@$row[3];
$player_playlist_sgcolor=@$row[4];
$player_bgcolor=@$row[5];
$player_banner_vimage_url=@$row[6];
$player_banner_vtext_section="";
$player_banner_vimage_height=@$row[7];
$player_banner_vimage_width=@$row[7]*$player_banner_vtotal_width/
    $player_banner_default_vtotal_width;
$player_banner_vtext_height=
    $player_banner_vtotal_height-$player_banner_vimage_height;
$player_banner_himage_url=@$row[8];
$player_banner_htext_section="";
$player_banner_himage_width=@$row[9]*$player_banner_htotal_width/
    $player_banner_default_htotal_width;

$player_banner_htext_width=
    $player_banner_htotal_width-$player_banner_himage_width;
if($cmdline{"brandid"} ne "") {
    $_=@$row[10];
    if($ENV{'HTTPS'} eq "on") {
	s{http}{https}g;
    }
    my $base_link=$_;
    $player_banner_vimage_url=
	$base_link."vbannerlogo_".$cmdline{"brandid"}.".png";
    $player_banner_vtext_section="background-image:url('".
	$base_link."vbannertext_".$cmdline{"brandid"}.".png');";
    $player_banner_himage_url=
	$base_link."hbannerlogo_".$cmdline{"brandid"}.".png";
    $player_banner_htext_section="background-image:url('".
	$base_link."hbannertext_".$cmdline{"brandid"}.".png');";
#    $player_banner_htext_section=
#	$base_link."hbannertext_".$cmdline{"brandid"}.".png";
}
$q->finish();

if($cmdline{"textcolor"} ne "") {
    $player_playlist_fgcolor="#".$cmdline{"textcolor"};
}

#
#  Log the access
#
if($cmdline{"section"} eq "") {
    &LogAccess("B",$ENV{"REMOTE_ADDRESS"},$ENV{"HTTP_USER_AGENT"},
	       $ENV{"HTTP_REFERER"},$cmdline{"name"},$player_title,
	       $cmdline{"button"},$cmdline{"url"},$cmdline{"brandid"},
	       "","","","");
}

#
# Build Current Channel Data
#
my $current_titles="var current_titles=new Array;\n";
my $current_descriptions="var current_descriptions=new Array;\n";
my $current_enclosure_urls="var current_enclosure_urls=new Array;\n";
my $i=0;
$sql=sprintf "select CURRENT_TITLE,CURRENT_DESCRIPTION,CURRENT_ENCLOSURE_URL \
              from CHANNEL_BUTTONS where (PLAYER_NAME=\"%s\")&&\
              (CURRENT_ENCLOSURE_URL is not null)",
    $cmdline{"name"};
$q=$dbh->prepare($sql);
$q->execute();

#
# Serve XML List
#
if($cmdline{"section"} eq "parts") {
    my $brandarg;
    $brandid=$cmdline{"brandid"};
    if($brandid ne "") {
	$brandarg="&amp;brandid=".&EscapeHtml($brandid);
    }
    print "Content-type: application/xml\n\n";
    print "<bannerData>\n";
    my $i=0;
    while(($row=$q->fetchrow_arrayref)) {
	print "  <channel".$i.">\n";
	print "    <title>".&EscapeHtml(@$row[0])."</title>\n";
	print "    <currentEpisode>".&EscapeHtml(@$row[1])."</currentEpisode>\n";
	print "    <currentUrl>http://".
	    @ENV{"SERVER_NAME"}.
	    "/loudwater/player.pl?name=".$cmdline{"name"}."&amp;url=".
	    &EscapeHtml(@$row[2]).$brandarg."</currentUrl>\n";
	print "  </channel".$i.">\n";
	$i++;
    }
    print "</bannerData>\n";
    exit 0;
}

#
# Serve Banner
#
while(($row=$q->fetchrow_arrayref)) {
    $current_titles=$current_titles.
	"current_titles[".$i."]='".&EscapeString(@$row[0])."';\n";
    $current_descriptions=$current_descriptions.
	"current_descriptions[".$i."]='".&EscapeString(@$row[1])."';\n";
    $current_enclosure_urls=$current_enclosure_urls.
	"current_enclosure_urls[".$i."]='".&EscapeString(@$row[2])."';\n";
    $i++;
}
$q->finish();

#
# Serve Banner
#
$current_time=1000*time;
print "Content-type: text/html\n\n";
if($cmdline{"section"} eq "head") {
    open SOURCE,"<","banner.js";
}
else {
    if($cmdline{"style"} eq "horizontal") {
	open SOURCE,"<","hbanner.html";
    }
    else {
	open SOURCE,"<","vbanner.html";
    }
}
$url_link=$cmdline{"url"};
$brandid=$cmdline{"brandid"};
if($cmdline{"upload"} ne "") {
    $sql=sprintf "select DOWNLOAD_URL from UPLOADS where ID=%u",
    $cmdline{"upload"};
    $q=$dbh->prepare($sql);
    $q->execute();
    if($row=$q->fetchrow_arrayref) {
	$url_link=@$row[0];
    }
    $q->finish();
}
if($url_link ne "") {
    $url_arg="&url=".$url_link;
}
if($brandid ne "") {
    $url_arg=$url_arg."&brandid=".$brandid;
    $brandid_arg="&brandid=".$brandid;
}
$player_path="http://".$ENV{'SERVER_NAME'}."/loudwater/player.pl";
$player_random=int(rand(10000000000));
while(<SOURCE>) {
    s{%RANDOM%}{$player_random}g;
    s{%CURRENT_TIME%}{$current_time}g;
    s{%NAME%}{$cmdline{"name"}}g;
    s{%TITLE%}{$player_title}g;
    s{%PLAYLIST_FGCOLOR%}{$player_playlist_fgcolor}g;
    s{%PLAYLIST_BGCOLOR%}{$player_playlist_bgcolor}g;
    s{%PLAYLIST_HGCOLOR%}{$player_playlist_hgcolor}g;
    s{%PLAYLIST_SGCOLOR%}{$player_playlist_sgcolor}g;
    s{%BGCOLOR%}{$player_bgcolor}g;
    s{%BANNER_VIMAGE_URL%}{$player_banner_vimage_url}g;
    s{%BANNER_VTEXT_SECTION%}{$player_banner_vtext_section}g;
    s{%BANNER_VTOTAL_WIDTH%}{$player_banner_vtotal_width}g;
    s{%BANNER_VTOTAL_HEIGHT%}{$player_banner_vtotal_height}g;
    s{%BANNER_VIMAGE_HEIGHT%}{$player_banner_vimage_height}g;
    s{%BANNER_VTEXT_HEIGHT%}{$player_banner_vtext_height}g;
    s{%BANNER_HIMAGE_URL%}{$player_banner_himage_url}g;
    s{%BANNER_HTEXT_SECTION%}{$player_banner_htext_section}g;
    s{%BANNER_HTOTAL_WIDTH%}{$player_banner_htotal_width}g;
    s{%BANNER_HTOTAL_HEIGHT%}{$player_banner_htotal_height}g;
    s{%BANNER_HIMAGE_WIDTH%}{$player_banner_himage_width}g;
    s{%BANNER_HTEXT_WIDTH%}{$player_banner_htext_width}g;
    s{%CURRENT_TITLES%}{$current_titles}g;
    s{%CURRENT_DESCRIPTIONS%}{$current_descriptions}g;
    s{%CURRENT_ENCLOSURE_URLS%}{$current_enclosure_urls}g;
    s{%URL_ARG%}{$url_arg}g;
    s{%BRANDID_ARG%}{$brandid_arg}g;
    s{%PLAYER_PATH%}{$player_path}g;
    print $_;
}
close SOURCE;


sub SimplifyWhitespace {
    local $_;
    $_=$_[0];
    s/\s+/ /g;
    s/^\s//;
    s/\s$//;
    return $_;
}
