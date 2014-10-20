#!/usr/bin/perl -w

# common.pl
#
# Loudwater Common Routines
#
# (C) Copyright 2009 Fred Gleason <fgleason@radiomaerica.org>
#

use WWW::Curl::Easy;
use Unix::Syslog qw(:macros);
use Unix::Syslog qw(:subs);
use XML::LibXML;
use HTML::Entities;
use String::Random;

$version="VERSION";

sub EscapeString {
    local $_=$_[0];
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


sub EscapeHtml {
    local $_=$_[0];
    s{&}{&amp;}g;
    s{\"}{&quot;}g;
    s{\'}{&apos;}g;
    s{<}{&lt;}g;
    s{>}{&gt;}g;

    return $_;
}


sub CgiError {
    print "Content-type: text/html\n\n";
    printf "CgiError: %s\n",$_[0];
    exit 0;
}


sub RSSTimeStamp {
    if(!defined($_[0])) {
	return "";
    }
    my @str=split " ",$_[0];

    my @date_parts=split "-",$str[0];

    my $ret=sprintf "%s, %d %s %d %s %s %s",&NameOfDay($str[0]),$date_parts[2],
    &NameOfMonth($date_parts[1]),$date_parts[0],$str[1];
    $ret=StripWhitespace($ret);
    if($#str>0) {
	$ret=" ".$ret." ".USE_TIMEZONE;
    }
    $ret=StripWhitespace($ret);
    return $ret;
}


sub NameOfDay {
    my @parts=split "-",$_[0];
    my $dow=&Day_of_Week($parts[0],$parts[1],$parts[2]);
    my $ret="Unknown";
    if($dow==1) {
	$ret="Mon";
    }
    if($dow==2) {
	$ret="Tue";
    }
    if($dow==3) {
	$ret="Wed";
    }
    if($dow==4) {
	$ret="Thu";
    }
    if($dow==5) {
	$ret="Fri";
    }
    if($dow==6) {
	$ret="Sat";
    }
    if($dow==7) {
	$ret="Sun";
    }
    return $ret;
}


sub NameOfMonth {
    my $ret="Unknown";
    if($_[0]==1) {
	$ret="Jan";
    }
    if($_[0]==2) {
	$ret="Feb";
    }
    if($_[0]==3) {
	$ret="Mar";
    }
    if($_[0]==4) {
	$ret="Apr";
    }
    if($_[0]==5) {
	$ret="May";
    }
    if($_[0]==6) {
	$ret="Jun";
    }
    if($_[0]==7) {
	$ret="Jul";
    }
    if($_[0]==8) {
	$ret="Aug";
    }
    if($_[0]==9) {
	$ret="Sep";
    }
    if($_[0]==10) {
	$ret="Oct";
    }
    if($_[0]==11) {
	$ret="Nov";
    }
    if($_[0]==12) {
	$ret="Dec";
    }
    return $ret;
}


sub MsecsToString {
    my $hour=int($_[0]/3600000);
    my $minute=int(($_[0]-3600000*$hour)/60000);
    my $second=int(($_[0]-3600000*$hour-60000*$minute)/1000);
    my $ret;
    if($hour!=0) {
	$ret=$ret.sprintf "%02d:",$hour;
    }
    if(($hour!=0)||($minute!=0)) {
	$ret=$ret.sprintf "%02d:",$minute;
    }
    $ret=$ret.sprintf "%02d",$second;
    return $ret;
}


sub GetLocalValue {
    my $post=$_[0];
    my $param_name=$_[1];
    my $alt_value=$_[2];

    my $value=$post->param($param_name);
    if($value eq "") {
	return $alt_value;
    }
    return $value;
}


sub GetLocalCheckedValue {
    my $post=$_[0];
    my $param_name=$_[1];
    my $alt_value=$_[2];

    my $value=$post->param($param_name);
    if($value eq "") {
	if($alt_value eq "Y") {
	    return "-checked";
	}
	return "";
    }
    if($value) {
	return "-checked";
    }
    return "";
}


sub LocaleDatetime {
    my $date;
    my $time;
    my $ret;

    if(length($_[0])>=19) {
	$date=substr($_[0],0,10);
	$time=substr($_[0],11,8);
    }
    else {
	if(substr($_[0],4,1) eq "-") {
	    $date=substr($_[0],0,10);
	}
    }
    if(length($date)>0) {
	$ret=sprintf "%s/%s/%s",
	     substr($date,5,2),substr($date,8,2),substr($date,0,4);
    }
    if(length($time)>0) {
	$ret=$ret." - ".$time;
    }
    return $ret;
}


sub SqlDatetime {
    my $date;
    my $time;
    my $ret;

    if(length($_[0])>=19) {
	$date=substr($_[0],0,10);
	$time=substr($_[0],11,8);
    }
    else {
	if(substr($_[0],2,1) eq "/") {
	    $date=substr($_[0],0,10);
	}
    }
    if(length($date)>0) {
	$ret=sprintf "%s-%s-%s",
	     substr($date,6,4),substr($date,0,2),substr($date,3,2);
    }
    if(length($time)>0) {
	$ret=$ret." ".$time;
    }
    return $ret;
}


sub StripWhitespace($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}


sub GetItemMetadataId {
    my($dbh,$channel_url,$item_url)=@_;
    my $id=-1;

    my $sql="select ID from PLAYLIST_METADATA where \
             (PLAYLIST_URL=\"".$channel_url."\")&&\
             (ENCLOSURE_URL=\"".$item_url."\")";
    my $q=$dbh->prepare($sql);
    $q->execute();
    if($row=$q->fetchrow_arrayref) {
	$id=@$row[0];
    }
    else {
	my $body="";
	if(DownloadItem($channel_url,\$body)!=0) {
	    syslog LOG_ERR,"unable to access playlist at %s [%s]",
	    $channel_url,$curl->errbuf();
	    return -1;
	}
	my $parser=XML::LibXML->new();
	my $doc=$parser->parse_string($body);

	my $toptag=$doc->getElementsByTagName("playlist");
	if($toptag->size()>0) {
	    $id=&UpdateXSLT($dbh,$channel_url,$item_url,$doc);
	}

	$toptag=$doc->getElementsByTagName("rss");
	if($toptag->size()>0) {
	    $id=&UpdateRSS($dbh,$channel_url,$item_url,$doc);
	}
    }
    $q->finish();

    return $id;
}


sub UpdateXSLT
{
    my($dbh,$channel_url,$item_url,$doc)=@_;
    my $id=-1;

    #
    # Clear stale entries
    #
    my $sql="delete from PLAYLIST_METADATA where PLAYLIST_URL=\"".
	&EscapeString($channel_url)."\"";
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    #
    # Create new entries
    #
    my $titles=$doc->getElementsByTagName("title");
    print "titles size: ".$titles->size()."\n";
    my $annotations=$doc->getElementsByTagName("annotation");
    print "annotations size: ".$annotations->size()."\n";
    my $images=$doc->getElementsByTagName("image");
    print "images size: ".$images->size()."\n";
    my $infos=$doc->getElementsByTagName("info");
    print "infos size: ".$infos->size()."\n";
    for($i=0;$i<$infos->size();$i++) {
	$sql="insert into PLAYLIST_METADATA set ";
	$sql=$sql."UPDATE_DATETIME=now(),";
	$sql=$sql."PLAYLIST_URL=\"".&EscapeString($channel_url)."\",";
	$sql=$sql."CHANNEL_TITLE=\"".
	    &EscapeString($titles->get_node(1)->to_literal())."\",";
	$sql=$sql."ENCLOSURE_URL=\"".
	    &EscapeString($infos->get_node($i+1)->to_literal())."\",";
	$sql=$sql."ITEM_TITLE=\"".
	    &EscapeString($titles->get_node($i+2)->to_literal())."\",";
	$sql=$sql."ITEM_DESCRIPTION=\"".
	    &EscapeString($annotations->get_node($i+1)->to_literal())."\",";
	$sql=$sql."ITEM_IMAGE_URL=\"".
	    &EscapeString($images->get_node($i+1)->to_literal())."\"";
	my $q=$dbh->prepare($sql);
	$q->execute();
	$q->finish();

	if($infos->get_node($i+1)->to_literal() eq $item_url) {
	    $sql="select LAST_INSERT_ID() from PLAYLIST_METADATA";
	    $q=$dbh->prepare($sql);
	    $q->execute();
	    if($row=$q->fetchrow_arrayref) {
		$id=@$row[0];
	    }
	    $q->finish();
	}
    }

    return $id;
}


sub UpdateRSS
{
    my($dbh,$channel_url,$item_url,$doc)=@_;
    my $id=-1;

    #
    # Clear stale entries
    #
    my $sql="delete from PLAYLIST_METADATA where PLAYLIST_URL=\"".
	&EscapeString($channel_url)."\"";
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    #
    # Create new entries
    #
    my $titles=$doc->getElementsByTagName("title");
    my $descriptions=$doc->getElementsByTagName("description");
    my $enclosures=$doc->getElementsByTagName("enclosure");
    for($i=0;$i<$enclosures->size();$i++) {
	$sql="insert into PLAYLIST_METADATA set ";
	$sql=$sql."UPDATE_DATETIME=now(),";
	$sql=$sql."PLAYLIST_URL=\"".&EscapeString($channel_url)."\",";
	my $url=$enclosures->get_node($i+1)->attributes()->
	    getNamedItem("url")->to_literal();
	$sql=$sql."ENCLOSURE_URL=\"".&EscapeString($url)."\",";
	$sql=$sql."ITEM_TITLE=\"".
	    &EscapeString($titles->get_node($i+1)->to_literal())."\",";
	$sql=$sql."ITEM_DESCRIPTION=\"".
	    &EscapeString($descriptions->get_node($i+1)->to_literal())."\"";
	my $q=$dbh->prepare($sql);
	$q->execute();
	$q->finish();

	if($url eq $item_url) {
	    $sql="select LAST_INSERT_ID() from PLAYLIST_METADATA";
	    $q=$dbh->prepare($sql);
	    $q->execute();
	    if($row=$q->fetchrow_arrayref) {
		$id=@$row[0];
	    }
	    $q->finish();
	}
    }

    return $id;
}


sub DownloadItem
{
    my($url,$bodyptr)=@_;
    my $curl = WWW::Curl::Easy->new;

    $$bodyptr="";
    $curl->setopt(CURLOPT_HEADER,0);
    $curl->setopt(CURLOPT_URL,$url);
    $curl->setopt(CURLOPT_WRITEFUNCTION,\&WriteCallback);
    $curl->setopt(CURLOPT_FILE,$bodyptr);
    return $retcode=$curl->perform;
}


sub WriteCallback
{ 
    my($data,$bodyptr)=@_;
    $$bodyptr=$$bodyptr.$data;

    return length($data)
}


sub GetFullLink
{
    my($dbh,$name,$button,$url,$style,$brandid)=@_;
    my $stylestr="";
    my $brandidstr;

    if($style ne "") {
	$stylestr="&style=".$style;
    }
    if($brandid ne "") {
	$brandidstr="&brandid=".$brandid;
    }
    return "http://".$ENV{"SERVER_NAME"}."/loudwater/player.pl".
	"?name=".$name.
	"&url=".$url.
	"&button=".$button.
	$stylestr.
	$brandidstr;
}


sub GetDirectLink
{
    my($dbh,$name,$button,$url,$style,$brandid)=@_;

    return "http://".$ENV{"SERVER_NAME"}."/".
	&GetDirectLinkString($dbh,$name,$button,$url,$style,$brandid);
}


sub GetDirectLinkString
{
    my($dbh,$name,$button,$url,$style,$brandid)=@_;
    my $link="";

    if($brandid eq "") {
	$brandid=-1;
    }

    #
    # Check if the link already exists
    #
    my $sql=sprintf "select LINK from REMAPS where \
                     (NAME=\"".$name."\")&&\
                     (URL=\"".$url."\")&&\
                     (BUTTON=".$button.")&&\
                     (STYLE=\"".$style."\")&&\
                     (BRANDID=".$brandid.")";

    my $q=$dbh->prepare($sql);
    $q->execute();
    if($row=$q->fetchrow_arrayref) {
	$link=@$row[0];
	$q->finish();
	return $link;
    }
    $q->finish();

    #
    # Create a new mapping
    # Generate a unique link string
    #
    my $gen=new String::Random;
    $gen->{'A'}=['A'..'Z','a'..'z','0'..'9'];
    $link=$gen->randpattern("AAAAAAAAAA");
    $sql="select LINK from REMAPS where LINK=\"".$link."\"";
    $q=$dbh->prepare($sql);
    $q->execute();
    while($row=$q->fetchrow_arrayref) {
	$q->finish();
	$link=$gen->randpattern("AAAAAAAAAA");
	$sql="select LINK from REMAPS where LINK=\"".$link."\"";
	$q=$dbh->prepare($sql);
	$q->execute();
    }
    $q->finish();

    #
    # Create and serve the map entry
    #
    $sql=sprintf "insert into REMAPS set \
                  NAME=\"".$name."\",\
                  URL=\"".$url."\",\
                  BUTTON=".$button.",\
                  STYLE=\"".$style."\",\
                  BRANDID=".$brandid.",
                  LINK=\"".$link."\"";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    return $link;
}


sub LogAccess
{
    #
    # Takes 15 Arguments, as follows:
    #
    #   Type ('P', 'C', 'B' or 'E')
    #   IPv4 Address in dotted-quad
    #   User-agent string
    #   Referrer URL
    #   Player name
    #   Player title
    #   Player button number
    #   Player URL parameter
    #   Brand ID
    #   Channel name
    #   Channel title
    #   Tap ID
    #   Tap title
    #   Post ID
    #   Post title

    #
    # Some sanity checking
    #
    if(scalar(@_)!=15) {
	syslog(LOG_WARNING,"LogAccess called with invalid arguments");
	return;
    }

    #
    # Get current date/time
    #
    my ($sec,$min,$hour,$day,$month,$yr19,@rest)=localtime(time);
    $month++;
    my $year=1900+$yr19;

    #
    # Generate logline
    #
    my $logname=sprintf "%04d%02d%02d.log",$year,$month,$day;
    my $logline=sprintf "\"%04d/%02d/%02d %02d:%02d:%02d\",",
    $year,$month,$day,$hour,$min,$sec;
    foreach $item (@_) {
	$logline=$logline."\"".$item."\",";
    }
    $logline=substr($logline,0,-1);

    #
    # Write to file
    #
    open(FILE,">>/var/log/loudwater/".$logname);
    print FILE $logline."\n";
    close(FILE);
}
