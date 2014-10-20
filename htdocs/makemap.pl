#!/usr/bin/perl
#
# makemap.pl
#
# The makemap web service for Loudwater
#
# (C) Copy 2011 Fred Gleason <fredg@paravelsystems.com>
#
#   $Id: makemap.pl,v 1.1 2011/12/09 23:06:13 pcvs Exp $
#

use CGI;
use DBI;

do "common.pl";

#
# Get the request parameters
#
my $post=new CGI;
my $name=$post->param("NAME");
if(length($name) eq 0) {
    print "Content-type: text/html\n";
    print "Status: 404\n\n";
    print "missing NAME\n";
    print "\n";
    exit 0;
}

my $url=$post->param("URL");
if(length($name) eq 0) {
    print "Content-type: text/html\n";
    print "Status: 404\n\n";
    print "missing URL\n";
    print "\n";
    exit 0;
}
my $button=$post->param("BUTTON");
if(length($button) eq 0) {
    print "Content-type: text/html\n";
    print "Status: 404\n\n";
    print "missing BUTTON\n";
    print "\n";
    exit 0;
}
my $style=$post->param("STYLE");
my $brandid=$post->param("BRANDID");

#print "Content-type: text/html\n\n";
#print "HERE\n";

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
    print "Status: 500\n\n";
    print "unable to open database\n";
    exit 0;
}

#
# Serve the link
#
print "Content-type: application/xml\n";
print "Status: 200\n\n";
print "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
print "<remap>\n";
print "  <name>".$name."</name>\n";
print "  <url>".$url."</url>\n";
print "  <button>".$button."</button>\n";
print "  <style>".$style."</style>\n";
print "  <brandid>".$brandid."</brandid>\n";
print "  <link>".&GetDirectLink($dbh,$name,$button,$url,$style,$brandid).
    "</link>\n";
print "</remap>\n";

exit 0;
