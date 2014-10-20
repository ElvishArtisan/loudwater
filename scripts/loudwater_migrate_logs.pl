#!/usr/bin/perl

# loudwater_migrate_logs.pl
#
# Migrate Loudwater logs from MySQL tables to logfiles in 
# '/var/log/loudwater/'.
#
#  (C) 2011 Fred Gleason <fredg@paravelsystems.com>
#

use DBI;

do "/etc/loudwater_conf.pl";

#
# Open the database
#
my $dbh=DBI->connect("dbi:mysql:$loudwater_db_dbname:$loudwater_db_hostname",
		     $loudwater_db_username,$loudwater_db_password);
if(!dbh) {
    print "unable to open database\n";
    exit 256;
}

#
# Read the ACCESS_LOG table
#
my $sql="select ACCESS_DATETIME,ACCESS_TYPE,IPV4_ADDRESS,USER_AGENT,\
         REFERER_URL,PLAYER_NAME,PLAYER_TITLE,PLAYER_URL,PLAYER_BRANDING,\
         CHANNEL_NAME,CHANNEL_TITLE,CHANNEL_TAP_ID,CHANNEL_TAP_TITLE,\
         POST_ID,POST_TITLE from ACCESS_LOG \
         where (ACCESS_DATETIME is not null)&&(ACCESS_TYPE is not null) \
         order by ACCESS_DATETIME";
my $q=$dbh->prepare($sql);
$q->execute();

#
# Copy data to logfiles
#
while(my $row=$q->fetchrow_arrayref) {
    my $filename=GetLogFilename(@$row[0]);
    if($filename ne "") {
	open(FILE,">>".$filename);
	print FILE "\"".@$row[0]."\",";           # Access Date-time
	print FILE "\"".@$row[1]."\",";           # Access Type
	print FILE "\"".@$row[2]."\",";           # IPv4 Address
	print FILE "\"".@$row[3]."\",";           # User Agent
	print FILE "\"".@$row[4]."\",";           # Referer
	print FILE "\"".@$row[5]."\",";           # Player Name
	print FILE "\"".@$row[6]."\",";           # Player Title
	print FILE "\"\",";                       # Button Number
	print FILE "\"".@$row[7]."\",";           # Player URL
	print FILE "\"".@$row[8]."\",";           # Player Branding
	print FILE "\"".@$row[9]."\",";           # Channel Name
	print FILE "\"".@$row[10]."\",";          # Channel Title
	print FILE "\"".@$row[11]."\",";          # Tap ID
	print FILE "\"".@$row[12]."\",";          # Tap Title
	print FILE "\"".@$row[13]."\",";          # Post ID
	print FILE "\"".@$row[14]."\"\n";         # Post Title
	close(FILE);
    }
}

#
# Clean up
#
$q->finish();
exit 0;


sub GetLogFilename
{
    my($datetime)=@_;

    my @parts=split " ",$datetime;
    if(scalar(@parts)==2) {
	@fields=split "-",$parts[0];
	if(scalar(@fields)==3) {
	    return "/var/log/loudwater/".
		$fields[0].$fields[1].$fields[2].".log";
	}
    }
    return "";
}
