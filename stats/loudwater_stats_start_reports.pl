#!/usr/bin/perl

# loudwater_stats_start_reports.pl
#
# Test harness for Loudwater Stats module routines
#
# (C) Copyright 2011 Fred Gleason <fredg@paravelsystems.com>
#
# Generate a log set for one or more reports to use.
#
#  USAGE: loudwater_stats_start_reports.pl <start-date> <end-date>
#
#  OUTPUTS: name of log set table
#

use Date::Manip;
use Socket;

do "loudwater_stats_common.pl";

if($#ARGV!=1) {
    print "loudwater_stats_start_reports.pl <start-date> <end-date>\n";
    exit(256);
}

my $err="";
$dbh=&OpenDb();

my $start_date=ParseDate($ARGV[0]);
my $end_date=ParseDate($ARGV[1]);

$table=&CreateLogSet($dbh,$start_date,$end_date);
&UpdateDnsCache($dbh,$table);
print $table."\n";

exit(0);
