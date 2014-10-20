#!/usr/bin/perl

# statest.pl
#
# Test harness for Loudwater Stats module routines
#
# (C) Copyright 2011 Fred Gleason <fredg@paravelsystems.com>
#

use Date::Manip;
use Socket;

do "loudwater_stats_common.pl";

my $err="";
$dbh=&OpenDb();

my $start_date=ParseDate("2011-12-01");
my $end_date=ParseDate("2011-12-01");


# #############TIMING MEASUREMENT SYSTEM ###############
my $start_time=time();
# #############TIMING MEASUREMENT SYSTEM ###############

#$table=&CreateLogSet($dbh,$start_date,$end_date);
#&UpdateDnsCache($dbh,$table);
#&DeleteLogSet($table);

#my $where="";
my $sql="select NAME,WHERE_TAG from USER_AGENTS order by NAME";
my $q=$dbh->prepare($sql);
$q->execute();
while($row=$q->fetchrow_arrayref) {
#    $where=$where."(USER_AGENT not like \"%".@$row[1]."%\")&&";
    print @$row[0].": ".&IpCount("CVQNJKKCWM_ACCESS","USER_AGENT like \"%".
				 @$row[1]."%\"")."\n";
}
$q->finish();

#print "\n";
#print "where: ".$where."\n";

#my %agents=&GetUserAgents("CVQNJKKCWM_ACCESS","");
#while(my($agent,$qty)=each(%agents)) {
#    print $qty.": ".$agent."\n";
#}
#print keys(%agents)." unique agent strings found\n";


# #############TIMING MEASUREMENT SYSTEM ###############
my $end_time=time();
my $interval=$end_time-$start_time;
print "operation took ".$interval." seconds.\n";
# #############TIMING MEASUREMENT SYSTEM ###############

