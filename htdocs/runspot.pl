#!/usr/bin/perl

# runspot.pl
#
# CGI proxy for the Ando RunSpot service.
#
# (C) Copyright 2009 Fred Gleason <fgleason@radiomaerica.org>
#

use CGI;

do "common.pl";

#
# Get Arguments
#
my $post=new CGI;
my $sid=$post->param("SID");
if ($sid==undef) {
    print "Content-type: text/html\n\n";
    print "Missing/Invalid SID\n";
    exit(0);
}
my $ad_format=$post->param("AD_FORMAT");
if ($ad_format==undef) {
    print "Content-type: text/html\n\n";
    print "Missing/Invalid AD_FORMAT\n";
    exit(0);
}
my $minduration=$post->param("MINDURATION");
if ($minduration==undef) {
    $minduration=0;
}
my $maxduration=$post->param("MAXDURATION");
if ($maxduration==undef) {
    print "Content-type: text/html\n\n";
    print "Missing/Invalid MAXDURATION\n";
    exit(0);
}
my $spotlevel=$post->param("SPOTLEVEL");
if ($spotlevel==undef) {
    print "Content-type: text/html\n\n";
    print "Missing/Invalid SPOTLEVEL\n";
    exit(0);
}
my $category_id=$post->param("CATEGORY_ID");
if ($category_id==undef) {
    print "Content-type: text/html\n\n";
    print "Missing/Invalid CATEGORY_ID\n";
    exit(0);
}

#
# Call the RunSpot service
#
my $wget_cmd=sprintf "wget --quiet -O - \"http://collective.andohs.net/amtmsvc/runspotv3.2/service.asmx/RunSpot?sid=%d&adformat=%d&minduration=%d&maxduration=%d&sip=%s&latitude=-1&longitude=-1&zip=-1&spotlevel=%d&categoryID=%d\"",
    $sid,$ad_format,$minduration,$maxduration,$ENV{"REMOTE_ADDR"},$spotlevel,
    $category_id;
print "Content-type: application/xml\n\n";
print `$wget_cmd`."\n";
exit 0;
