#!/usr/bin/perl
#
# remap.pl
#
# The remapper script for Loudwater
#
# (C) Copy 2011 Fred Gleason <fredg@paravelsystems.com>
#
#   $Id: remap.pl,v 1.3 2012/04/10 22:53:49 pcvs Exp $
#

use DBI;

do "common.pl";

#
# Get the request parameters
#
my $request_uri=substr($ENV{"REQUEST_URI"},1);
if(length($request_uri) eq 0) {
    print "Content-type: text/html\n";
    print "Status: 500\n";
    print "\n";
    print "Missing REQUEST_URI\n";
    exit 0;
}
if($request_uri eq "crossdomain.xml") {
    open SOURCE,"<","/srv/www/htdocs/crossdomain.xml";
    print "Content-type: application/xml\n\n";
    while(<SOURCE>) {
        print $_;
    }
    close SOURCE;
}
if(length($request_uri) ne 10) {
    print "Content-type: text/html\n";
    print "Status: 404\n";
    print "object not found\n";
    print "\n";
    exit 0;
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
    print "Content-type: text/html\n";
    print "Status: 500\n";
    print "\n";
    print "unable to open database\n";
    exit 0;
}

#
# Look up the remap
#
my $sql=sprintf "select NAME,URL,BUTTON,STYLE,BRANDID from REMAPS \
                 where LINK=\"".$request_uri."\"";
my $q=$dbh->prepare($sql);
$q->execute();
if(!($row=$q->fetchrow_arrayref)) {
    print "Content-type: text/html\n";
    print "Status: 404\n";
    print "\n";
    print "object not found\n";
    exit 0;
}

#
# Serve the redirect
#
my $location="Location: http://".$ENV{"SERVER_NAME"}.
    "/loudwater/player.pl?name=".@$row[0]."&url=".@$row[1]."&button=".@$row[2];
if(@$row[3] ne "") {
    $location=$location."&style=".@$row[3];
}
if(@$row[4]>=0) {
    $location=$location."&brandid=".@$row[4];
}
$q->finish();

print $location."\n\n";

exit 0;
