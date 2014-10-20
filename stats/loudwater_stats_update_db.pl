#!/usr/bin/perl

# loudwater_stats_update_db.pl
#
# (C) Copyright 2011 Fred Gleason <fredg@paravelsystems.com>
#
#  $Id: loudwater_stats_update_db.pl,v 1.3 2012/01/04 19:25:13 pcvs Exp $
#
# Check the Loudwater Stats database schema and update it as necessary.
#

use DBI;

do "/etc/loudwater_stats_conf.pl";

sub EscapeString {
    $_=$_[0];
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



#
# Open the database
#
my $dbh=DBI->connect("dbi:mysql:$loudwater_stats_db_dbname:$loudwater_stats_db_hostname",
		     $loudwater_stats_db_username,$loudwater_stats_db_password);
if(!dbh) {
    print "unable to open database\n";
    exit 256;
}

#
# Get the schema version
#
my $sql="create table if not exists VERSION (DB int default 0)";
my $q=$dbh->prepare($sql);
$q->execute();
$q->finish();

$sql="select DB from VERSION";
$q=$dbh->prepare($sql);
$q->execute();
if(!($row=$q->fetchrow_arrayref)) {
    $q->finish();

    $sql="insert into VERSION set DB=0";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="select DB from VERSION";
    $q=$dbh->prepare($sql);
    $q->execute();
}
#if(!($row=$q->fetchrow_arrayref)) {
#    print "unable to initialize database\n";
#    exit 256;
#}
my $db_ver=@$row[0];
$q->finish();

#
# Apply schema updates
#
if($db_ver<1) {
    $sql="create table if not exists DNS_CACHE (\
          IPV4_ADDRESS char(15) not null primary key,\
          HOSTNAME char(255),\
          RECORD_DATETIME datetime not null,\
          index RECORD_DATETIME_IDX(RECORD_DATETIME))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="create table if not exists USER_AGENTS (\
          ID int unsigned not null primary key auto_increment,\
          WHERE_TAG char(64) unique not null,\
          NAME char(64))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


$sql="update VERSION set DB=1";
$q=$dbh->prepare($sql);
$q->execute();
$q->finish();

$dbh->disconnect;
