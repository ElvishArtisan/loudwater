#!/usr/bin/perl

# player.pl
#
# Serve an audio player
#
# (C) Copyright 2009 Fred Gleason <fgleason@radiomaerica.org>
#

use DBI;
use URI::Escape;

do "common.pl";

#
# Load Command Line
#
@ii=split /&/,$ENV{'QUERY_STRING'};
for ($i=0;$i<=$#ii;$i++) {
  @jj=split /=/,$ii[$i];  #/
  $cmdline{$jj[0]}=uri_unescape($jj[1]);
}
if($cmdline{"name"} eq "") {
  print "Content-type: text/html\n\n";
  printf "Missing player name!";
  exit 0;
}
$player_style=$cmdline{"style"};
$player_url_button=-1;
if($cmdline{"button"} ne "") {
  $player_url_button=$cmdline{"button"};
}

#
# Get the Server Configuration
#
$cgi_server_name=$ENV{'SERVER_NAME'};

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
my $sql=sprintf "select NAME,TITLE,PLAYLIST_FGCOLOR,PLAYLIST_BGCOLOR,\
                 PLAYLIST_HGCOLOR,PLAYLIST_SGCOLOR,BGCOLOR,SPLASH_LINK,\
                 LIVE_LINK,DEFAULT_LINK,\
                 AUDIO_LOGO_LINK,VIDEO_LOGO_LINK,BASE_BRANDING_LINK,SID,\
                 GATEWAY_QUALITY,BUTTON_SECTION_IMAGE,\
                 BUTTON_COLUMNS,BUTTON_ROWS,TOP_BANNER_CODE,SIDE_BANNER_CODE,\
                 OPTIONAL_LINK_CODE,HEAD_CODE,USE_SYNCHED_BANNERS,LAYOUT,\
                 PLAYLIST_POSITION,\
                 SOCIAL_TEST,SOCIAL_FACEBOOK,SOCIAL_FACEBOOK_ADMIN,\
                 SOCIAL_DISPLAY_LINK from PLAYERS where NAME=\"%s\"",
    $cmdline{"name"};

my $q=$dbh->prepare($sql);
$q->execute();
if(!($row=$q->fetchrow_arrayref)) {
    print "Content-type: text/html\n\n";
    printf "Invalid player name!";
    exit 0;
}
$player_title=@$row[1];
$player_playlist_fgcolor=@$row[2];
$player_playlist_bgcolor=@$row[3];
$player_playlist_hgcolor=@$row[4];
$player_playlist_sgcolor=@$row[5];
$player_bgcolor=@$row[6];
$player_splash_link=@$row[7];
$player_live_link=@$row[8];
$player_default_link=@$row[9];
my $brandid=$cmdline{"brandid"};
if($brandid eq "") {
    $player_audio_logo_link=@$row[10];
    $player_video_logo_link=@$row[11];
    $player_gateway_link="";
}
else {
    $player_audio_logo_link=@$row[12]."/audiologo_".$brandid.".jpg";
    $player_video_logo_link=@$row[12]."/videologo_".$brandid.".jpg";
    $player_gateway_link=@$row[12]."/gateway_".$brandid.".flv";
}
$player_sid=@$row[13];
$player_gateway_quality="adURL_low";
if(@$row[14]==2) {
    $player_gateway_quality="adURL_med";
}
if(@$row[14]==3) {
    $player_gateway_quality="adURL_high";
}
$player_button_section_image=@$row[15];
$player_button_columns=@$row[16];
$player_button_rows=@$row[17];
$player_top_banner=&SimplifyWhitespace(@$row[18]);
$player_side_banner=&SimplifyWhitespace(@$row[19]);
$player_optional_link_code=@$row[20];
$head_script=&SimplifyWhitespace(@$row[21]);
$synched_banners=@$row[22];
$player_layout=@$row[23];

#
# Define Player Size
#
my $player_width=430;
my $player_height=365;
my $player_displayheight=300;
my $player_playlistsize=75;
my $player_videowidth=430;
if($player_layout eq "S") {
  if($player_style eq "sparse") {
#      $player_height=365;
#      $player_displayheight=300;
#      $player_playlistsize=360;
#      $player_videowidth=430;
#      $player_width=$player_playlistsize+$player_videowidth;
      $player_height=350;
      $player_displayheight=300;
      $player_playlistsize=280;
      $player_videowidth=345;
      $player_width=$player_playlistsize+$player_videowidth;
  }
}
if($player_layout eq "W") {
  if($player_style eq "sparse") {
    $player_videowidth=640;
    $player_height=360;
    $player_displayheight=360;
    $player_playlistsize=360;
    $player_width=$player_playlistsize+$player_videowidth;
  }
  else {
    $player_width=640;
    $player_height=360;
    $player_displayheight=360;
    $player_playlistsize=75;
  }
}
$player_playlist_position=@$row[24];
$social_test=@$row[25];
$social_facebook=@$row[26];
$social_facebook_admin=@$row[27];
$social_display_link=@$row[28];
$q->finish();

#
# Build the Social Media Row
#
$player_social_media_row="";
$player_facebook_headers="";
$player_metadata_id=-1;
if($cmdline{"button"} ne "") {
    $sql="select CLICK_LINK from CHANNEL_BUTTONS where \
          (PLAYER_NAME=\"".$cmdline{"name"}."\")&&\
          (BUTTON_NUMBER=".$cmdline{"button"}.")";
    $q1=$dbh->prepare($sql);
    $q1->execute();
    if($row1=$q1->fetchrow_arrayref) {
	$player_metadata_id=&GetItemMetadataId($dbh,@$row1[0],$cmdline{"url"});
    }
    $q1->finish();
}
if($social_test eq "Y") {  # Test Service
  $player_social_media_row=$player_social_media_row.
      "<tr><td id=\"social_test\" align=\"center\"><img onclick=\"SocialTest();\" src=\"social_test.png\" border=\"0\" /></td><td>&nbsp;</td></tr>";
}
if($social_display_link eq "Y") {  # Display Episode Links
  $player_social_media_row=$player_social_media_row.
      "<tr><td id=\"social_display_link\" align=\"center\">&nbsp;</td><td>&nbsp;</td></tr>";
}
if($social_facebook eq "Y") {  # FaceBook
  $player_social_media_row=$player_social_media_row.
      "<tr><td height=\"35\" id=\"social_facebook\">&nbsp;</td></tr>";
  $player_facebook_headers=
      "<script type=\"text/javascript\" src=\"facebook.js\"></script>\n";
  if($player_metadata_id>=0) {
      $sql="select ITEM_TITLE,ITEM_DESCRIPTION,ITEM_IMAGE_URL,CHANNEL_TITLE,ENCLOSURE_URL from PLAYLIST_METADATA where ID=".$player_metadata_id;
      $q1=$dbh->prepare($sql);
      $q1->execute();
      if($row1=$q1->fetchrow_arrayref) {
	  my $site_name=@$row1[3];
	  if($site_name eq "") {
	      $site_name=@$row1[0];
	  }
	  $player_facebook_headers=$player_facebook_headers.
	      "<meta property=\"og:title\" content=\"".@$row1[0]."\"/>\n";
	  $player_facebook_headers=$player_facebook_headers.
	      "<meta property=\"og:type\" content=\"article\"/>\n";
	  $player_facebook_headers=$player_facebook_headers.
	      "<meta property=\"og:image\" content=\"".@$row1[2]."\"/>\n";
	  $player_facebook_headers=$player_facebook_headers.
	      "<meta property=\"og:url\" content=\"".
	      &GetFullLink($dbh,$cmdline{"name"},$cmdline{"button"},
			     $cmdline{"url"},$cmdline{"style"},
			     $cmdline{"brandid"})."\"/>\n";
	  $player_facebook_headers=$player_facebook_headers.
	      "<meta property=\"og:site_name\" content=\"".$site_name."\"/>\n";
	  $player_facebook_headers=$player_facebook_headers.
	      "<meta property=\"fb:admins\" content=\"".$social_facebook_admin.
	      "\"/>\n";
	  $player_facebook_headers=$player_facebook_headers.
	      "<meta property=\"og:description\" content=\"".@$row1[1]."\"/>\n";
	  $player_facebook_headers=$player_facebook_headers.
	      "<meta property=\"og:locale\" content=\"en_US\"/>\n";
      }
      $q1->finish();
  }
}

#
#  Log the access
#
if($cmdline{"section"} eq "") {
    &LogAccess("P",$ENV{"REMOTE_ADDR"},$ENV{"HTTP_USER_AGENT"},
	       $ENV{"HTTP_REFERER"},$cmdline{"name"},$player_title,
	       $cmdline{"button"},$cmdline{"url"},$cmdline{"brandid"},
	       "","","","","","");
}

#
# Build the Button Arrays
#
$sql=sprintf "select BUTTON_NUMBER,IMAGE_LINK,ACTIVE_IMAGE_LINK,CLICK_LINK,\
              SID,MODE from CHANNEL_BUTTONS where PLAYER_NAME=\"%s\" \
              order by BUTTON_NUMBER",$cmdline{"name"}; 
$q=$dbh->prepare($sql);
$q->execute();
while($row=$q->fetchrow_arrayref) {
    @player_selector_button_images[@$row[0]]=@$row[1];
    @player_selector_active_button_images[@$row[0]]=@$row[2];
    $player_ondemand_button_links=$player_ondemand_button_links.
	sprintf "ondemand_button_links[%d]=\'%s\';",@$row[0],@$row[3];
    $player_channel_sids=$player_channel_sids.
	sprintf "channel_sids[%d]=%d;",@$row[0],@$row[4];
    $player_button_modes=$player_button_modes.
	sprintf "button_modes[%d]=%d;",@$row[0],@$row[5];
}
$q->finish();

#
# Build the live stream schedule
#
$sql=sprintf "select SUN,MON,TUE,WED,THU,FRI,SAT,START_HOUR,RUN_LENGTH,\
              LIVE_LINK,LOGO_LINK,SID from LIVE_SEGMENTS \
              where PLAYER_NAME=\"%s\" order by START_HOUR",
    $cmdline{"name"};
$q=$dbh->prepare($sql);
    $q->execute();
my @count;
while($row=$q->fetchrow_arrayref) {
    for($i=0;$i<7;$i++) {
	if(@$row[$i] eq "Y") {
	    $player_live_start_hours[$i]=$player_live_start_hours[$i].
		sprintf "start_hours[%d][%d]=%d;",$i,$count[$i],@$row[7];
	    $player_live_lengths[$i]=$player_live_lengths[$i].
		sprintf "start_lengths[%d][%d]=%d;",$i,$count[$i],@$row[8];
	    $player_live_links[$i]=$player_live_links[$i].
		sprintf "live_links[%d][%d]=\'%s\';",$i,$count[$i],@$row[9];
	    $player_live_logos[$i]=$player_live_logos[$i].
		sprintf "live_logos[%d][%d]=\'%s\';",$i,$count[$i],@$row[10];
	    $player_live_sids[$i]=$player_live_sids[$i].
		sprintf "live_sids[%d][%d]=%d;",$i,$count[$i],@$row[11];
	    $count[$i]++;
	}
    }
}
$q->finish();

#
# Build Button Image Arrays
#
$player_button_images="";
$player_active_button_images="";
for($i=0;$i<$player_button_rows;$i++) {
  for($j=0;$j<$player_button_columns;$j++) {
    $bnum=$i*$player_button_columns+$j;
    $player_button_images=$player_button_images."button_images[".
	$bnum."]=\"".@player_selector_button_images[$bnum]."\";\n";
    $player_active_button_images=$player_active_button_images.
	"active_button_images[".
	$bnum."]=\"".@player_selector_active_button_images[$bnum]."\";\n";
  }
}

#
# Build button section
#
$button_table="";
if(($player_button_section_image eq "")||($cmdline{"style"} ne "")) {
  $button_table=$button_table."<table cellpadding=\"0\" cellpadding=\"0\" border=\"0\">\n";
  for($i=0;$i<$player_button_rows;$i++) {
    $button_table=$button_table."<tr>\n";
    for($j=0;$j<$player_button_columns;$j++) {
      $bnum=$i*$player_button_columns+$j;
      $button_table=$button_table.sprintf("<td id=\"button%d\"><a href=\"javascript:PlayButton(%d)\" style=\"text-decoration:none\">\n",$bnum,$bnum);
      $button_table=$button_table.sprintf("<img src=\"%s\" border=\"0\" /></a></td>\n",@player_selector_button_images[$bnum]);
    }
    $button_table=$button_table.sprintf("</tr>");
  }
  $button_table=$button_table."</table>\n";
}
else {
  $button_table=$button_table."<table cellpadding=\"0\" cellpadding=\"0\" border=\"0\" height=\"111\">\n";
  $button_table=$button_table."<tr>\n";
  $button_table=$button_table."<td align=\"center\"><img border=\"0\" width=\"300\" src=\"";
  $button_table=$button_table.$player_button_section_image;
  $button_table=$button_table."\" />\n";
  $button_table=$button_table."</td>\n";
  $button_table=$button_table."</tr>\n";
  $button_table=$button_table."</table>\n";
}

#
# Genrate Ando Tracking Tag
#
$ando_tag="";
if($player_sid!=0) {
  open TAG,"<","andotag.html";
  while(<TAG>) {
    s{%SID%}{$player_sid}g;
    $ando_tag=$ando_tag.$_;
  }
  close TAG;
}

#
# Serve Player
#
$current_time=1000*time;
print "Content-type: text/html\n\n";
if($cmdline{"section"} eq "head") {
  open SOURCE,"<","player.js";
}
else {
  if($cmdline{"style"} eq "sparse") {
    open SOURCE,"<","player-sparse.html";
  }
  else {
    open SOURCE,"<","player.html";
  }
}
$url_link=$cmdline{"url"};
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
}

$youtube_link="";
if($cmdline{"youtube"} ne "") {
  $youtube_link="http://www.youtube.com/v/".$cmdline{"youtube"};
  $url_arg="&youtube=".$cmdline{"youtube"};
}

$player_random=int(rand(10000000000));
while(<SOURCE>) {
  s{%RANDOM%}{$player_random}g;
  s{%SERVER_NAME%}{$cgi_server_name}g;
  s{%CURRENT_TIME%}{$current_time}g;
  s{%PLAYLIST_POSITION%}{$player_playlist_position}g;
  s{%STYLE%}{$player_style}g;
  s{%NAME%}{$cmdline{"name"}}g;
  s{%BRANDID%}{$brandid}g;
  s{%TITLE%}{$player_title}g;
  s{%PLAYLIST_FGCOLOR%}{$player_playlist_fgcolor}g;
  s{%PLAYLIST_BGCOLOR%}{$player_playlist_bgcolor}g;
  s{%PLAYLIST_HGCOLOR%}{$player_playlist_hgcolor}g;
  s{%PLAYLIST_SGCOLOR%}{$player_playlist_sgcolor}g;
  s{%BGCOLOR%}{$player_bgcolor}g;
  s{%AUDIO_LOGO_LINK%}{$player_audio_logo_link}g;
  s{%VIDEO_LOGO_LINK%}{$player_video_logo_link}g;
  s{%GATEWAY_LINK%}{$player_gateway_link}g;
  s{%URL_LINK%}{$url_link}g;
  s{%URL_BUTTON%}{$player_url_button}g;
  s{%URL_ARG%}{$url_arg}g;
  s{%YOUTUBE_LINK%}{$youtube_link}g;
  s{%SPLASH_LINK%}{$player_splash_link}g;
  s{%SID%}{$player_sid}g;
  s{%DEFAULT_LINK%}{$player_default_link}g;
  s{%LIVE_BUTTON_IMAGE%}{$player_live_button_image}g;
  s{%ONDEMAND_BUTTON_LINKS%}{$player_ondemand_button_links}g;
  s{%CHANNEL_SIDS%}{$player_channel_sids}g;
  s{%BUTTON_MODES%}{$player_button_modes}g;
  s{%BUTTON_IMAGES%}{$player_button_images}g;
  s{%ACTIVE_BUTTON_IMAGES%}{$player_active_button_images}g;
  s{%TOP_BANNER%}{$player_top_banner}g;
  s{%SIDE_BANNER%}{$player_side_banner}g;
  s{%OPTIONAL_LINK_CODE%}{$player_optional_link_code}g;
  s{%HEAD_SCRIPT%}{$head_script}g;
  s{%FACEBOOK_HEADERS%}{$player_facebook_headers}g;
  s{%SOCIAL_DISPLAY_LINK%}{$social_display_link}g;
  s{%BUTTON_TABLE%}{$button_table}g;
  s{%ANDO_TAG%}{$ando_tag}g;
  if($synched_banners eq "Y") {
      s{%SYNCHED_BANNERS%}{synched_banners=true;}g;
  }
  else {
      s{%SYNCHED_BANNERS%}{synched_banners=false;}g;
  }
  s{%PLAYER_WIDTH%}{$player_width}g;
  s{%PLAYER_HEIGHT%}{$player_height}g;
  s{%PLAYER_DISPLAYHEIGHT%}{$player_displayheight}g;
  s{%PLAYER_VIDEOWIDTH%}{$player_videowidth}g;
  s{%PLAYLIST_SIZE%}{$player_playlistsize}g;
  s{%BUTTON_SECTION_IMAGE%}{$player_button_section_image}g;
  for($i=0;$i<7;$i++) {
    $tag=sprintf "%%START_HOURS_%d%%",$i;
    s{$tag}{$player_live_start_hours[$i]}g;
    $tag=sprintf "%%START_LENGTHS_%d%%",$i;
    s{$tag}{$player_live_lengths[$i]}g;
    $tag=sprintf "%%LIVE_LINKS_%d%%",$i;
    s{$tag}{$player_live_links[$i]}g;
    $tag=sprintf "%%LIVE_LOGOS_%d%%",$i;
    s{$tag}{$player_live_logos[$i]}g;
    $tag=sprintf "%%LIVE_SIDS_%d%%",$i;
    s{$tag}{$player_live_sids[$i]}g;
  }
  if($cmdline{"style"} eq "") {
    s{%USE_BANNERS%}{1}g;
  }
  else {
    s{%USE_BANNERS%}{0}g;
  }
  s{%SOCIAL_MEDIA_ROW%}{$player_social_media_row}g;
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
