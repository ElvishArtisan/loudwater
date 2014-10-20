#!/usr/bin/perl

# loudwater_stats_finish_reports.pl
#
# (C) Copyright 2011 Fred Gleason <fredg@paravelsystems.com>
#
# Clean up log set after generating reports.
#
#  USAGE: loudwater_stats_finish_reports.pl <table-name>
#
#  OUTPUTS: nothing
#

do "loudwater_stats_common.pl";

if($#ARGV!=0) {
    print "loudwater_stats_finish_reports.pl <table-name>\n";
    exit(256);
}

my $table=$ARGV[0];

my $err="";
$dbh=&OpenDb();

&DeleteTable($dbh,$table);

exit(0);
