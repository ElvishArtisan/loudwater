#!/usr/bin/perl

# loudwater_stats_common.pl
#
# Common utility routines for the Loudwater Stats module. 
#
# (C) Copyright 2011 Fred Gleason <fredg@paravelsystems.com>
#

use DBI;
use Text::CSV_XS;
use Date::Manip;
use String::Random;

#
# Open the stats database.
#
#   RETURNS: DB handle.
#
sub OpenDb
{
    do "/etc/loudwater_stats_conf.pl";

    my $dbh=DBI->connect("dbi:mysql:$loudwater_stats_db_dbname:$loudwater_stats_db_hostname",
			 $loudwater_stats_db_username,$loudwater_stats_db_password);
    if(!$dbh) {
	print "unable to open database\n";
	exit 256;
    }
    return $dbh;
}


#
# Get a count of the number of unique IP addresses that match the specified
# WHERE clause in the specified log set.
#
#   RETURNS: number of unique IP addresses
#
sub IpCount
{
    my($dbh,$table,$where)=@_;
    my %addresses;

    $sql="select IPV4_ADDRESS from ".$table." where ".$where;
    my $q=$dbh->prepare($sql);
    $q->execute();
    while($row=$q->fetchrow_arrayref) {
	$addresses{@$row[0]}++;
    }
    return keys(%addresses);
}


#
# Get the set of user agent strings found in the specified log set.
#
#   RETURNS: Hash of number of occurances, indexed by string value.
#
sub GetUserAgents
{
    my($table,$where)=@_;
    my %agents;

    $sql="select USER_AGENT from ".$table;
    if($where ne "") {
	$sql=$sql." where ".$where;
    }
    my $q=$dbh->prepare($sql);
    $q->execute();
    while($row=$q->fetchrow_arrayref) {
	$agents{@$row[0]}++;
    }
    return %agents;
}

#
# Create a 'log set' table that analysis operations can be performed
# against, populated with data from the indicated dates (inclusive). The
# table as created contains *no* indices beyond the primary key; analysis
# routines should create appropriate indices as required.
#
#  NOTE: This must be kept in sync with any changes made to the LoadLog()
#        and InsertValuesLine() functions below!
#
#   RETURNS: The name of the table created.
#
sub CreateLogSet()
{
    my($dbh,$start_date,$end_date)=@_;
    my $rand=new String::Random;
    my $table=$rand->randpattern("CCCCCCCCCC")."_ACCESS";
    my $err="";
    my $id=1;

    $sql="create table if not exists ".$table." (\
          ID int unsigned not null primary key auto_increment,\
          ACCESS_DATETIME datetime not null,\
          ACCESS_TYPE enum('P','B','C','E'),\
          IPV4_ADDRESS char(16) not null,\
          USER_AGENT char(255),\
          REFERER_URL char(255),\
          PLAYER_NAME char(8),\
          PLAYER_TITLE char(255),\
          BUTTON_NUMBER int unsigned,\
          PLAYER_URL char(255),\
          PLAYER_BRANDING int unsigned,\
          CHANNEL_NAME char(8),\
          CHANNEL_TITLE char(255),\
          CHANNEL_TAP_ID int unsigned,\
          CHANNEL_TAP_TITLE char(64),\
          POST_ID int unsigned,\
          POST_TITLE char(255))";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $date=$start_date;
    while(Date_Cmp($date,$end_date)<=0) {
	$id=&LoadLog($dbh,$table,
		     "/var/log/loudwater/".UnixDate($date,"%Y%m%d").".log",$id);
	$date=DateCalc($date,"1day",\$err);
    }

    return $table;
}

#
# Delete a table in the database.  Use this to remove a log set created by
# CreateLogSet() after analysis is complete.
#
#   RETURNS: nothing
#
sub DeleteTable()
{
    my($dbh,$table)=@_;

    $sql="drop table ".$table;
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


#
# MySQL Optimized Insert, used by CreateLogSet()
#
#  This is about twice as fast as the "standard" version below, but uses
#  a special, non-standard MySQL syntax.
#
#  NOTE: The companion InsertValuesLine() function must be kept in sync
#        with any changes made to the access table schema in CreateLogSet()!
#
sub LoadLog()
{
    my($dbh,$table,$filename,$id)=@_;
    my $count=0;

    if(!open FILE,$filename) {
	return $id;
    }

    my $csv=new Text::CSV_XS;

    while(<FILE>) {
	$count=0;
	my $sql=sprintf "insert into ".$table." values ";
	if($csv->parse($_)) {
	    $sql=$sql.&InsertValuesLine($id++,$csv);
	    while(<FILE>&&($count++<10)) {
		if($csv->parse($_)) {
		    $sql=$sql.",".&InsertValuesLine($id++,$csv);
		}
	    }
#	    print $sql."\n";

	    my $q=$dbh->prepare($sql);
	    $q->execute();
	    $q->finish();
	}
	else {
	    print "Error in: ".$filename."\n";
	}
    }

    close(FILE);
    return $id;
}


#
# Low level routine, used by the 'optimized' version of LoadLog().
#
sub InsertValuesLine
{
    my ($count,$csv)=@_;
    my @fields=$csv->fields();
    my $sql="";
	$sql=$sql."(".$count.",";                     # ID
	$sql=$sql."'".$fields[0]."',";                # ACCESS_DATETIME
	$sql=$sql."'".$fields[1]."',";                # ACCESS_TYPE
	$sql=$sql."'".$fields[2]."',";                # IPV4_ADDRESS
	$sql=$sql."'".&SqlEscape($fields[3])."',";    # USER_AGENT
	$sql=$sql."'".&SqlEscape($fields[4])."',";    # REFERER_URL
	$sql=$sql."'".&SqlEscape($fields[5])."',";    # PLAYER_NAME
	$sql=$sql."'".&SqlEscape($fields[6])."',";    # PLAYER_TITLE
	$sql=$sql.&SqlNumeric($fields[7]).",";        # BUTTON_NUMBER
	$sql=$sql."'".&SqlEscape($fields[8])."',";    # PLAYER_URL
	$sql=$sql.&SqlNumeric($fields[9]).",";        # PLAYER_BRANDING
	$sql=$sql."'".&SqlEscape($fields[10])."',";   # CHANNEL_NAME
	$sql=$sql."'".&SqlEscape($fields[11])."',";   # CHANNEL_TITLE
	$sql=$sql.&SqlNumeric($fields[12]).",";       # CHANNEL_TAP_ID
	$sql=$sql."'".&SqlEscape($fields[13])."',";   # CHANNEL_TAP_TITLE
	$sql=$sql.&SqlNumeric($fields[12]).",";       # POST_ID
	$sql=$sql."'".&SqlEscape($fields[13])."')";   # POST_TITLE
    return $sql;
}


#
# SQL Standard 'Single Row' Insert, used by CreateLogSet()
#
#  This is about half as fast as the optimized version above, but uses
#  standard SQLv2 syntax.
#
#  NOTE: This must be kept in sync with any changes made to the access
#        table schema in CreateLogSet()!
#
#sub LoadLog()
#{
#    my($dbh,$table,$filename)=@_;
#    my $count=0;
#
#    if(!open FILE,$filename) {
#	return 0;
#    }
#
#    my $csv=new Text::CSV_XS;
#
#    while(<FILE>) {
#	if($csv->parse($_)) {
#	    my @fields=$csv->fields();
#	    my $sql=sprintf "insert into ".$table." set ";
#	    $sql=$sql."ACCESS_DATETIME=\"".$fields[0]."\",";
#	    $sql=$sql."ACCESS_TYPE=\"".$fields[1]."\",";
#	    $sql=$sql."IPV4_ADDRESS=\"".$fields[2]."\",";
#	    $sql=$sql."USER_AGENT=\"".&SqlEscape($fields[3])."\",";
#	    $sql=$sql."REFERER_URL=\"".&SqlEscape($fields[4])."\",";
#	    $sql=$sql."PLAYER_NAME=\"".&SqlEscape($fields[5])."\",";
#	    $sql=$sql."PLAYER_TITLE=\"".&SqlEscape($fields[6])."\",";
#	    $sql=$sql."BUTTON_NUMBER=".&SqlNumeric($fields[7]).",";
#	    $sql=$sql."PLAYER_URL=\"".&SqlEscape($fields[8])."\",";
#	    $sql=$sql."PLAYER_BRANDING=".&SqlNumeric($fields[9]).",";
#	    $sql=$sql."CHANNEL_NAME=\"".&SqlEscape($fields[10])."\",";
#	    $sql=$sql."CHANNEL_TITLE=\"".&SqlEscape($fields[11])."\",";
#	    $sql=$sql."CHANNEL_TAP_ID=".&SqlNumeric($fields[12]).",";
#	    $sql=$sql."CHANNEL_TAP_TITLE=\"".&SqlEscape($fields[13])."\",";
#	    $sql=$sql."POST_ID=".&SqlNumeric($fields[14]).",";
#	    $sql=$sql."POST_TITLE=\"".&SqlEscape($fields[15])."\"";
#
#	    my $q=$dbh->prepare($sql);
#	    $q->execute();
#	    $q->finish();
#	}
#	else {
#	    print "Error in: ".$filename."\n";
#	}
#    }
#
#    close(FILE);
#    return 1;
#}

#
# Update the DNS cache with values from the specialized log set table.
# Cache values older than 30 days will be deleted as part of the process.
#
#   RETURNS: nothing
#
sub UpdateDnsCache
{
    my($dbh,$table)=@_;
    my $err="";

    #
    # Flush the cache
    #
    my $sql="delete from DNS_CACHE where RECORD_DATETIME<\"".
	UnixDate(DateCalc(&Now(),"-30days",\$err),"%Y-%m-%d %k:%M:%S")."\"";
    &RunQuery($dbh,$sql);

    #
    # Build the address table
    #
    my %addrs;
    $sql="select IPV4_ADDRESS from ".$table;
    my $q=$dbh->prepare($sql);
    $q->execute();
    while($row=$q->fetchrow_arrayref) {
	$addresses{@$row[0]}++;
    }

    #
    # PTR Lookup
    #
    while(my($addr,$qty)=each(%addresses)) {
	$sql="select IPV4_ADDRESS from DNS_CACHE where IPV4_ADDRESS=\"".
	    $addr."\"";
	$q=$dbh->prepare($sql);
	$q->execute();
	if(!($row=$q->fetchrow_arrayref)) {
	    $q->finish();
	    my @dns=gethostbyaddr(inet_aton($addr),AF_INET);
	    if($dns[0] eq "") {
		$sql="insert into DNS_CACHE set ";
		$sql=$sql."IPV4_ADDRESS=\"".$addr."\",";
		$sql=$sql."HOSTNAME=null,";
		$sql=$sql."RECORD_DATETIME=now()";
	    }
	    else {
		$sql="insert into DNS_CACHE set ";
		$sql=$sql."IPV4_ADDRESS=\"".$addr."\",";
		$sql=$sql."HOSTNAME=\"".&SqlEscape($dns[0])."\",";
		$sql=$sql."RECORD_DATETIME=now()";
	    }
	    $q=$dbh->prepare($sql);
	    $q->execute();
	    #print $addr.": ".$dns[0]."\n";
	}
    }
    $q->finish();
}


sub SqlEscape
{
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


sub SqlNumeric
{
    my($str)=@_;

    if($str==0) {
	return "null";
    }

    return $str;
}

#
# Return the current datetime
#
sub Now
{
    return ParseDateString("epoch ".time());
}


#
# Run an action query
#
sub RunQuery
{
    my($dbh,$sql)=@_;

    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}
