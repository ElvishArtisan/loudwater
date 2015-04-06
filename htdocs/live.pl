#!/usr/bin/perl

# live.pl
#
# Serve a live feed record
#
# (C) Copyright 2014 Fred Gleason <fgleason@radiomaerica.org>
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
if($cmdline{"feed"} eq "") {
  print "Content-type: text/html\n\n";
  printf "Missing feed name!";
  exit 0;
}
$feed_name=$cmdline{"feed"};

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
    print "Content-type: text/html\n\n";
    print "unable to open database\n";
    exit 0;
}

#
# Fetch the feed set from the DB
#
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
$now=sprintf "%02d:%02d:%02d",$hour,$min,$sec;
my $sql="select NAME,MOUNT_POINT,TYPE,LOGO_LINK,IS_DEFAULT from FEEDSETS ".
    "where (SET_NAME=\"".$feed_name."\")&&";
if($wday==0) {
    $sql=$sql."(SUN='Y')&&";
}
if($wday==1) {
    $sql=$sql."(MON='Y')&&";
}
if($wday==2) {
    $sql=$sql."(TUE='Y')&&";
}
if($wday==3) {
    $sql=$sql."(WED='Y')&&";
}
if($wday==4) {
    $sql=$sql."(THU='Y')&&";
}
if($wday==5) {
    $sql=$sql."(FRI='Y')&&";
}
if($wday==6) {
    $sql=$sql."(SAT='Y')&&";
}
$sql=$sql."(START_TIME<=\"".$now."\")&&";
$sql=$sql."(END_TIME>\"".$now."\")";

#print "Content-type: text/html\n\n";
#print "SQL: ".$sql."\n";
#exit 0;


print "Content-type: application/xml\n\n";
print "<liveFeeds>\n";
my $q=$dbh->prepare($sql);
$q->execute();
while($row=$q->fetchrow_arrayref) {
    print "  <liveFeed>\n";
    print "    <name>".@$row[0]."</name>\n";
    print "    <mountPoint>".@$row[1]."</mountPoint>\n";
    print "    <type>".@$row[2]."</type>\n";
    print "    <image>".@$row[3]."</image>\n";
    print "    <isDefault>".@$row[4]."</isDefault>\n";
    print "  </liveFeed>\n";
}
print "</liveFeeds>\n";
$q->finish();
