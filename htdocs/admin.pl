#!/usr/bin/perl

# admin.pl
#
# Loudwater Administrative Interface
#
# (C) Copyright 2009 Fred Gleason <fgleason@radiomaerica.org>
#

use CGI;
use DBI;
use Date::Format;
use File::Basename;
use WWW::Curl::Easy;

#
# Job States
#
# FIXME: This must be kept in sync with the values in 'lwpd/common.h'.
#
use constant JOB_STATE_COMPLETE=>0;
use constant JOB_STATE_UPLOADING=>1;
use constant JOB_STATE_INGEST_QUEUED=>2;
use constant JOB_STATE_INGESTING=>3;
use constant JOB_STATE_ENCODE_QUEUED=>4;
use constant JOB_STATE_ENCODING=>5;
use constant JOB_STATE_DISTRIBUTION_QUEUED=>6;
use constant JOB_STATE_DISTRIBUTING=>7;
use constant JOB_STATE_DELETION_QUEUED=>8;
use constant JOB_STATE_DELETING=>9;
use constant JOB_STATE_TAP_DELETION_QUEUED=>10;
use constant JOB_STATE_LAST_GOOD_STATE=>99;
use constant JOB_STATE_INTERNAL_ERROR=>100;
use constant JOB_STATE_UNKNOWN_FILETYPE_ERROR=>101;
use constant JOB_STATE_ENCODER_ERROR=>102;
use constant JOB_STATE_DISTRIBUTION_ERROR=>103;
use constant JOB_STATE_TAP_DELETION_ERROR=>104;
use constant JOB_STATE_MISSING_ENCODER_ERROR=>105;

#
# Queue File Types
#
# FIXME: This must be kept in sync with the values in 'lwpd/common.h'.
#
use constant FILE_TYPE_INGEST=>1;
use constant FILE_TYPE_ENCODE=>2;
use constant FILE_TYPE_UPLOAD=>3;

#
# Button Modes
#
# FIXME: These must be kept in sync with the values in 'htdocs/player.js'.
#
use constant BUTTON_MODE_ONDEMAND=>0;
use constant BUTTON_MODE_LIVEFEED=>1;

#
# CGI Operations
#
# FIXME: These must be kept in sync with the values in 'htdocs/admin.js'.
#
use constant COMMAND_LOGOUT=>0;
use constant COMMAND_MAIN_MENU=>1;
use constant COMMAND_LIST_USERS=>2;
use constant COMMAND_ADD_USER=>3;
use constant COMMAND_COMMIT_ADD_USER=>4;
use constant COMMAND_EDIT_USER=>5;
use constant COMMAND_COMMIT_EDIT_USER=>6;
use constant COMMAND_DELETE_USER=>7;
use constant COMMAND_COMMIT_DELETE_USER=>8;
use constant COMMAND_CHANGE_USER_PASSWORD=>9;
use constant COMMAND_COMMIT_CHANGE_USER_PASSWORD=>10;
use constant COMMAND_LIST_PLAYERS=>11;
use constant COMMAND_ADD_PLAYER=>12;
use constant COMMAND_COMMIT_ADD_PLAYER=>13;
use constant COMMAND_EDIT_PLAYER=>14;
use constant COMMAND_COMMIT_EDIT_PLAYER=>15;
use constant COMMAND_DELETE_PLAYER=>16;
use constant COMMAND_COMMIT_DELETE_PLAYER=>17;
use constant COMMAND_LIST_LIVESEGMENTS=>18;
use constant COMMAND_COMMIT_ADD_LIVESEGMENT=>19;
use constant COMMAND_EDIT_LIVESEGMENT=>20;
use constant COMMAND_COMMIT_EDIT_LIVESEGMENT=>21;
use constant COMMAND_COMMIT_DELETE_LIVESEGMENT=>22;
use constant COMMAND_LIST_BUTTONS=>23;
use constant COMMAND_EDIT_BUTTON=>24;
use constant COMMAND_COMMIT_EDIT_BUTTON=>25;
use constant COMMAND_LIST_CHANNELS=>26;
use constant COMMAND_ADD_CHANNEL=>27;
use constant COMMAND_COMMIT_ADD_CHANNEL=>28;
use constant COMMAND_EDIT_CHANNEL=>29;
use constant COMMAND_COMMIT_EDIT_CHANNEL=>30;
use constant COMMAND_DELETE_CHANNEL=>31;
use constant COMMAND_COMMIT_DELETE_CHANNEL=>32;
use constant COMMAND_EDIT_CHANNEL_PERMS=>33;
use constant COMMAND_COMMIT_CHANNEL_PERMS=>34;
use constant COMMAND_LIST_CONTENT_CHANNELS=>35;
use constant COMMAND_LIST_CHANNEL_LINKS=>36;
use constant COMMAND_LIST_POSTS=>37;
use constant COMMAND_ADD_POST=>38;
use constant COMMAND_UPLOAD_ADD_POST=>39;
use constant COMMAND_COMMIT_ADD_POST=>40;
use constant COMMAND_EDIT_POST=>41;
use constant COMMAND_COMMIT_EDIT_POST=>42;
use constant COMMAND_DELETE_POST=>43;
use constant COMMAND_COMMIT_DELETE_POST=>44;
use constant COMMAND_LIST_SERVERS=>45;
use constant COMMAND_ADD_SERVER=>46;
use constant COMMAND_UPLOAD_ADD_SERVER=>47;
use constant COMMAND_COMMIT_ADD_SERVER=>48;
use constant COMMAND_EDIT_SERVER=>49;
use constant COMMAND_COMMIT_EDIT_SERVER=>50;
use constant COMMAND_DELETE_SERVER=>51;
use constant COMMAND_COMMIT_DELETE_SERVER=>52;
use constant COMMAND_ADD_TAP=>53;
use constant COMMAND_COMMIT_ADD_TAP=>54;
use constant COMMAND_EDIT_TAP=>55;
use constant COMMAND_COMMIT_EDIT_TAP=>56;
use constant COMMAND_DELETE_TAP=>57;
use constant COMMAND_COMMIT_DELETE_TAP=>58;
use constant COMMAND_VIEW_JOBS=>59;
use constant COMMAND_RESTART_JOB=>60;
use constant COMMAND_DELETE_JOB=>61;
use constant COMMAND_LIST_THUMBNAILS=>62;
use constant COMMAND_ADD_THUMBNAIL=>63;
use constant COMMAND_COMMIT_ADD_THUMBNAIL=>64;
use constant COMMAND_DELETE_THUMBNAIL=>65;
use constant COMMAND_COMMIT_DELETE_THUMBNAIL=>66;
use constant COMMAND_COMMIT_SET_DEFAULT_THUMBNAIL=>67;
use constant COMMAND_SELECT_THUMBNAIL=>68;
use constant COMMAND_COMMIT_SELECT_THUMBNAIL=>69;
use constant COMMAND_LIST_UPLOADS=>70;
use constant COMMAND_LIST_FEEDSETS=>71;
use constant COMMAND_ADD_FEED=>72;
use constant COMMAND_EDIT_FEED=>73;
use constant COMMAND_COMMIT_EDIT_FEED=>74;
use constant COMMAND_DELETE_FEED=>75;
use constant COMMAND_COMMIT_DELETE_FEED=>76;

use constant BGCOLOR1=>'#E0E0E0';
use constant BGCOLOR2=>'#F0F0F0';

use constant SELECT_THUMBNAILS=>0;
use constant MANAGE_THUMBNAILS=>1;

#
# Globals
#
my $name="";
my $password="";
my $session_id="";
my $post="";
my $auth_user_name="";
my $manage_users_priv=0;
my $manage_players_priv=0;
my $manage_channels_priv=0;
my $manage_servers_priv=0;
my $manage_content_priv=0;
my $authenticated=0;
my $new_post_id=0;
my $new_tap_id=0;
my $new_segment_id=0;

do "common.pl";
do "/etc/loudwater_conf.pl";

sub ServeTimeControl {
    my $control_name=$_[0];
    my $value=$_[1];
    my @hours=["00","01","02","03","04","05","06","07","08","09","10","11",
	       "12","13","14","15","16","17","18","19","20","21","22","23"];
    my @minsecs=["00","01","02","03","04","05","06","07","08","09",
		 "10","11","12","13","14","15","16","17","18","19",
		 "20","21","22","23","24","25","26","27","28","29",
		 "30","31","32","33","34","35","36","37","38","39",
		 "40","41","42","43","44","45","46","47","48","49",
		 "50","51","52","53","54","55","56","57","58","59"];
    my @f0=split ":",$value;

    print $post->popup_menu($control_name."_HOUR",@hours,@f0[0]);
    print ":";
    print $post->popup_menu($control_name."_MIN",@minsecs,@f0[1]);
    print ":";
    print $post->popup_menu($control_name."_SEC",@minsecs,@f0[2]);
}


sub ReadTimeControl {
    my $control_name=$_[0];

    my $hour=$post->param($control_name."_HOUR");
    my $min=$post->param($control_name."_MIN");
    my $sec=$post->param($control_name."_SEC");

    return sprintf("%02d:%02d:%02d",$hour,$min,$sec);
}    


sub ServeCheckControl {
    my $control_name=$_[0];
    my $value=$_[1];

    my $user_tag="";
    if($value eq "Y") {
	$user_tag="-checked";
    }
    print $post->input({-type=>"checkbox",-name=>$control_name,
			-value=>"1",$user_tag});
}


sub ReadCheckControl {
    my $control_name=$_[0];
    my $ret="N";

    if($post->param($control_name) eq "1") {
	$ret="Y";
    }

    return $ret;
}

sub UpdatePostStatus {
    my $post_id=$_[0];
    my $sql=sprintf "select ID from JOBS where POST_ID=%u",$post_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(!(my $row=$q->fetchrow_arrayref)) {
	$sql=sprintf "update POSTS set PROCESSING=\"N\" where ID=%u",$post_id;
	my $q1=$dbh->prepare($sql);
	$q1->execute();
	$q1->finish();
    }
    $q->finish();
}

sub JobStatusString {
    my $ret=sprintf "Unknown [code: %d]",$_[0];
    if($_[0]==JOB_STATE_COMPLETE) {
	$ret="<strong>Complete</strong>";
    }
    if($_[0]==JOB_STATE_UPLOADING) {
	$ret="Uploading";
    }
    if($_[0]==JOB_STATE_INGEST_QUEUED) {
	$ret="Queued for Ingest";
    }
    if($_[0]==JOB_STATE_INGESTING) {
	$ret="Ingesting";
    }
    if($_[0]==JOB_STATE_ENCODE_QUEUED) {
	$ret="Queued for Encoding";
    }
    if($_[0]==JOB_STATE_ENCODING) {
	$ret="Encoding";
    }
    if($_[0]==JOB_STATE_DISTRIBUTION_QUEUED) {
	$ret="Queued for Distribution";
    }
    if($_[0]==JOB_STATE_DISTRIBUTING) {
	$ret="Distributing";
    }
    if($_[0]==JOB_STATE_DELETION_QUEUED) {
	$ret="Queued for Deletion";
    }
    if($_[0]==JOB_STATE_DELETING) {
	$ret="Deleting";
    }
    if($_[0]==JOB_STATE_TAP_DELETION_QUEUED) {
	$ret="Deleting Post";
    }
    if($_[0]==JOB_STATE_INTERNAL_ERROR) {
	$ret="Internal Processing Error";
    }
    if($_[0]==JOB_STATE_UNKNOWN_FILETYPE_ERROR) {
	$ret="Unknown File Type";
    }
    if($_[0]==JOB_STATE_ENCODER_ERROR) {
	$ret="Encoder Error";
    }
    if($_[0]==JOB_STATE_DISTRIBUTION_ERROR) {
	$ret="Upload Error";
    }
    if($_[0]==JOB_STATE_TAP_DELETION_ERROR) {
	$ret="Upload Deletion Error";
    }
    if($_[0]==JOB_STATE_MISSING_ENCODER_ERROR) {
	$ret="Missing/Invalid Encoder";
    }
    if(($_[0]>JOB_STATE_LAST_GOOD_STATE)&&(@_>=2)) {
	$ret=$ret.": ".$_[1];
    }

    return $ret;
}

sub JobStatusColor {
    if($_[0]<=JOB_STATE_LAST_GOOD_STATE) {
	return "#007700";
    }
    return sprintf "#FF0000",$_[0];
}

#
# FIXME: This must be kept in sync with the QueueFilePath() method in 
#        'lwpd/common.cpp'
#
sub QueueFilePath {
    $file_type=$_[0];
    $post_id=$_[1];
    $partnum=$_[2];
    $extension=$_[3];

    my $path="/var/cache/loudwater/";
    if($file_type==FILE_TYPE_INGEST) {
	$path=$path."ingest/";
    }
    if($file_type==FILE_TYPE_ENCODE) {
	$path=$path."encode/";
    }
    if($file_type==FILE_TYPE_UPLOAD) {
	$path=$path."upload/";
    }
    $path=$path.sprintf "%09d_%03d.%s",$post_id,$partnum,$extension;
    return $path;
}

sub DeletePost {
    $post_id=$_[0];
    my $sql=sprintf "update POSTS set PROCESSING=\"N\",DELETING=\"Y\" \
                     where ID=%d",$post_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

sub ChannelAuthorized {
    my $sql=sprintf "select CHANNEL_NAME from CHANNEL_PERMS \
                     where (USER_NAME=\"%s\")&&(CHANNEL_NAME=\"%s\")",
	&EscapeString($auth_user_name),&EscapeString($_[0]);
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(!(my $row=$q->fetchrow_arrayref)) {
	$q->finish();
	return 0;
    }
    $q->finish();
    return 1;
}

sub PostAuthorized {
    #
    # FIXME: This query needs to be optimized
    #
    my $sql=sprintf "select POSTS.ID from POSTS \
                     left join CHANNELS on POSTS.CHANNEL_NAME=CHANNELS.NAME \
                     left join CHANNEL_PERMS \
                     on CHANNELS.NAME=CHANNEL_PERMS.CHANNEL_NAME \
                     where (CHANNEL_PERMS.USER_NAME=\"%s\")&&(POSTS.ID=%u)",
		     &EscapeString($auth_user_name),$_[0];
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(!(my $row=$q->fetchrow_arrayref)) {
	$q->finish();
	return 0;
    }
    $q->finish();
    return 1;
}

sub Authenticate {
    #
    # Purge Stale IDs
    #
    my $sql=sprintf "delete from WEB_CONNECTIONS where TIME_STAMP<\"%s\"",
    time2str("%Y-%m-%d %k:%M:%S",time()-900);

    #
    # Look for valid session ID
    #
    $session_id=$post->param("SESSION_ID");
    if($session_id eq "") {
	return 0;
    }
    $sql=sprintf "select LOGIN_NAME from WEB_CONNECTIONS \
                  where SESSION_ID=\"%s\"",$session_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(!($row=$q->fetchrow_arrayref)) {
	$q->finish();
	return 0;
    }
    $auth_user_name=@$row[0];
    $q->finish();

    #
    # Get user privileges
    #
    $sql=sprintf "select MANAGE_USERS_PRIV,MANAGE_PLAYERS_PRIV,\
                  MANAGE_CHANNELS_PRIV,MANAGE_SERVERS_PRIV \
                  from USERS where NAME=\"%s\"",
	&EscapeString($auth_user_name);
    $q=$dbh->prepare($sql);
    $q->execute();
    if(!($row=$q->fetchrow_arrayref)) {
	$q->finish();
	return 0;
    }
    if(@$row[0] eq 'Y') {
	$manage_users_priv=1;
    }
    else {
	$manage_users_priv=0;
    }
    if(@$row[1] eq 'Y') {
	$manage_players_priv=1;
    }
    else {
	$manage_players_priv=0;
    }
    if(@$row[2] eq 'Y') {
	$manage_channels_priv=1;
    }
    else {
	$manage_channels_priv=0;
    }
    if(@$row[3] eq 'Y') {
	$manage_servers_priv=1;
    }
    else {
	$manage_servers_priv=0;
    }
    $q->finish();

    $sql=sprintf "select CHANNEL_NAME from CHANNEL_PERMS \
                  where USER_NAME=\"%s\"",
	&EscapeString($auth_user_name);
    $q=$dbh->prepare($sql);
    $q->execute();
    if($row=$q->fetchrow_arrayref) {
	$manage_content_priv=1;
    }
    $q->finish();

    return 1;
}

sub LogIn {
    #
    # Validate User
    #
    my $row;
    my $name=$post->param("NAME");
    my $password=$post->param("PASSWORD");
    my $sql=sprintf "select MANAGE_USERS_PRIV,MANAGE_PLAYERS_PRIV,\
                     MANAGE_CHANNELS_PRIV,MANAGE_SERVERS_PRIV from USERS \
                     where (NAME=\"%s\")&&\
                     (PASSWORD=\"%s\")",
		     &EscapeString($name),&EscapeString($password);
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(!($row=$q->fetchrow_arrayref)) {
	$q->finish();
	return 0;
    }
    if(@$row[0] eq "Y") {
	$manage_users_priv=1;
    }
    else {
	$manage_users_priv=0;
    }
    if(@$row[1] eq "Y") {
	$manage_players_priv=1;
    }
    else {
	$manage_players_priv=0;
    }
    if(@$row[2] eq 'Y') {
	$manage_channels_priv=1;
    }
    else {
	$manage_channels_priv=0;
    }
    if(@$row[3] eq 'Y') {
	$manage_servers_priv=1;
    }
    else {
	$manage_servers_priv=0;
    }
    $q->finish();

    $sql=sprintf "select CHANNEL_NAME from CHANNEL_PERMS \
                  where USER_NAME=\"%s\"",
	&EscapeString($name);
    $q=$dbh->prepare($sql);
    $q->execute();
    if($row=$q->fetchrow_arrayref) {
	$manage_content_priv=1;
    }
    $q->finish();

    #
    # Generate Session ID
    #
    $session_id=int(rand(999999999));
    $sql=sprintf "insert into WEB_CONNECTIONS set \
                  LOGIN_NAME=\"%s\",\
                  SESSION_ID=%d,\
                  IP_ADDRESS=\"%s\",\
                  TIME_STAMP=now()",
		  &EscapeString($name),
		  $session_id,
		  $ENV{"REMOTE_ADDR"};
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $command=COMMAND_MAIN_MENU;
    return 1;
}


sub LogOut {
    $sql=sprintf "delete from WEB_CONNECTIONS where SESSION_ID=%d",$session_id;
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
    &ServeLogin;
    exit 0;
}


sub ServeLogin {
    print $post->header(-type=>'text/html');

    print "<head>\n";
    print $post->title("Loudwater Login");
    print "</head>\n";

    print "<body>\n";

    print "<table bgcolor=\"".BGCOLOR1.
	"\" cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,-value=>0});

    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<strong>Loudwater User Login</strong>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->td({-align=>"right"},"Login:");
    print $post->td({-align=>"left"},$post->input({-type=>"text",-name=>NAME}));
    print "</tr>\n";

    print "<tr>\n";
    print $post->td({-align=>"right"},"Password:");
    print $post->td({-align=>"left"},$post->input({-type=>"password",
						 -name=>"PASSWORD"}));
    print "</tr>\n";

    print "<tr>\n";
    print $post->td("&nbsp;");
    print $post->td({-align=>"right"},$post->input({-type=>"submit",-value=>OK}));
    print "</tr>\n";
    print "</form>\n";
    print "</table>\n";

    print "</body>\n";
}


sub ServeMainMenu {
    print $post->header(-type=>'text/html');

    print "<head>\n";
    print $post->title("Loudwater Main Menu");
    print "</head>\n";

    print "<body>\n";
    print "<table bgcolor=\"".BGCOLOR1.
	"\" cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";

    print "<tr>\n";
    print $post->td({-align=>"center"},"<strong>Loudwater Main Menu</strong>");
    print "</tr>\n";

    # Manage Users Button
    if($manage_users_priv) {
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_USERS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print "<tr>\n";
	print $post->
	    td({-align=>"center"},$post->input({-type=>"submit",
						-value=>"Manage Users"}));
	print "</tr>\n";
	print "</form>\n";
    }

    # Manage Servers Button
    if($manage_servers_priv) {
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_SERVERS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print "<tr>\n";
	print $post->td({-align=>"center"},$post->input({-type=>"submit",
						  -value=>"Manage Servers"}));
	print "</tr>\n";
	print "</form>\n";
    }

    # Manage Live Streams Button
    if($manage_players_priv) {
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_FEEDSETS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print "<tr>\n";
	print $post->td({-align=>"center"},$post->input({-type=>"submit",
						  -value=>"Manage Live Streams"}));
	print "</tr>\n";
	print "</form>\n";
    }

    # Manage Players Button
    if($manage_players_priv) {
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_PLAYERS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print "<tr>\n";
	print $post->td({-align=>"center"},$post->input({-type=>"submit",
						  -value=>"Manage Players"}));
	print "</tr>\n";
	print "</form>\n";
    }

    # Manage Channels Button
    if($manage_channels_priv) {
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_CHANNELS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print "<tr>\n";
	print $post->td({-align=>"center"},$post->input({-type=>"submit",
						  -value=>"Manage Channels"}));
	print "</tr>\n";
	print "</form>\n";
    }

    # Manage Content Button
    if($manage_content_priv) {
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_CONTENT_CHANNELS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print "<tr>\n";
	print $post->td({-align=>"center"},$post->input({-type=>"submit",
						  -value=>"Manage Content"}));
	print "</tr>\n";
	print "</form>\n";
    }

    print "<tr>\n";
    print $post->td("&nbsp;");
    print "</tr>\n";

    # Logout Button
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LOGOUT});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,-value=>$session_id});
    print "<tr>\n";
    print $post->td({-align=>"center"},$post->input({-type=>"submit",
						   -value=>"Logout"}));
    print "</tr>\n";
    print "</form>\n";

    print "</table>\n";
    print "</body>\n";
}


sub ServeListUsers {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater User List");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select NAME,FULL_NAME,MANAGE_USERS_PRIV,\
                    MANAGE_PLAYERS_PRIV,MANAGE_CHANNELS_PRIV,\
                    MANAGE_SERVERS_PRIV \
                    from USERS order by NAME";
    my $q=$dbh->prepare($sql);
    $q->execute();

    print "<tr>\n";
    print $post->td({-colspan=>6,-align=>"center"},
		    "<big><big>Loudwater User List</big></big>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->th({-align=>"center"},"Login Name");
    print $post->th({-align=>"center"},"Full Name");
    print $post->th({-align=>"center"},"Manage<br>Users");
    print $post->th({-align=>"center"},"Manage<br>Players");
    print $post->th({-align=>"center"},"Manage<br>Channels");
    print $post->th({-align=>"center"},"Manage<br>Servers");
    print $post->th({-align=>"center"},"&nbsp;");
    print $post->th({-align=>"center"},"&nbsp;");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    while(my $row=$q->fetchrow_arrayref) {
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"left"},@$row[0]);
	if(@$row[1] eq "") {
	    print $post->td("&nbsp;");
	}
	else {
	    print $post->td({-align=>"left"},@$row[1]);
	}
	if(@$row[2] eq "Y") {
	    print $post->td({-align=>"center"},"Yes");
	}
	else {
	    print $post->td({-align=>"center"},"No");
	}
	if(@$row[3] eq "Y") {
	    print $post->td({-align=>"center"},"Yes");
	}
	else {
	    print $post->td({-align=>"center"},"No");
	}
	if(@$row[4] eq "Y") {
	    print $post->td({-align=>"center"},"Yes");
	}
	else {
	    print $post->td({-align=>"center"},"No");
	}
	if(@$row[5] eq "Y") {
	    print $post->td({-align=>"center"},"Yes");
	}
	else {
	    print $post->td({-align=>"center"},"No");
	}
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_USER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>USER_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Edit});
	print "</td>\n";
	print "</form>\n";
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_DELETE_USER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>USER_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Delete});
	print "</td>\n";
	print "</form>\n";
	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_ADD_USER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Add User"});
    print "</td>\n";
    print "</form>\n";

    print $post->td({-colspan=>6},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_MAIN_MENU});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";

    exit 0;
}


sub ServeAddUser {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Add User");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Add User</big></big>");
    print "</tr>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_ADD_USER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print "<tr>\n";
    print $post->td({-bgcolor=>BGCOLOR1,-align=>"right"},"<strong>User Name:</strong>");
    print $post->td({-bgcolor=>BGCOLOR1,-align=>"left"},
		    $post->input({-type=>"text",-size=>40,-maxlength=>32,
				  -name=>USER_NAME}));
    print "</tr>\n";

    #
    # OK Button
    #
    print "<tr>\n";
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"OK"}));
    print "</form>\n";

    #
    # Cancel Button
    #
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_USERS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Cancel"}));
    print "</form>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitAddUser {
    my $user_name=$post->param("USER_NAME");
    my $sql=sprintf "insert into USERS set NAME=\"%s\"",
                     &EscapeString($user_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeEditUser {
    my $user_name=$post->param("USER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit User");
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select NAME,FULL_NAME,EMAIL_ADDRESS,PHONE_NUMBER,
                    MANAGE_USERS_PRIV,MANAGE_PLAYERS_PRIV,MANAGE_CHANNELS_PRIV,\
                    MANAGE_SERVERS_PRIV \
                    from USERS where NAME=\"%s\"",&EscapeString($user_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>4,-align=>"center"},
			"<big><big>Edit User</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_USER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>USER_NAME,
			    -value=>$user_name});

	#
	# User Name
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong>Login Name:</strong>");
	print $post->td({-colspan=>2,-align=>"left"},@$row[0]);
	print $post->td({-align=>"right"},
			$post->input({-type=>"button",-value=>"Change Password",
			-onclick=>sprintf "changeUserPassword(%d,\'%s\')",
				      $session_id,$user_name}));
	print "</tr>\n";

	#
	# Full Name
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong>Full Name:</strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"FULL_NAME",-type=>"text",-size=>40,
				      -maxlength=>255,
				      -name=>"FULL_NAME",
		   -value=>&GetLocalValue($post,"FULL_NAME",@$row[1])}));
	print "</tr>\n";

	#
	# E-Mail Address
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong>E-Mail Address:</strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-type=>"text",-size=>40,-maxlength=>255,
				      -id=>"EMAIL_ADDRESS",
				      -name=>"EMAIL_ADDRESS",
		  -value=>&GetLocalValue($post,"EMAIL_ADDRESS",@$row[2])}));
	print "</tr>\n";

	#
	# Phone Number
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong>Phone Number:</strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-type=>"text",-size=>40,-maxlength=>255,
				      -id=>"PHONE_NUMBER",-name=>"PHONE_NUMBER",
		  -value=>&GetLocalValue($post,"PHONE_NUMBER",@$row[3])}));
	print "</tr>\n";

	#
	# User Permissions
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-colspan=>4,-align=>"center"},
			"<strong>User Permissions</strong>");
	print "</tr>\n";

	#
	# Manage Users
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},
			$post->input({-type=>"checkbox",
				      -id=>"MANAGE_USERS_PRIV",
				      -name=>"MANAGE_USERS_PRIV",
				      -value=>"1",
	       &GetLocalCheckedValue($post,"MANAGE_USERS_PRIV",@$row[4])}));
	print $post->td({-colspan=>3,-align=>"left"},"Manage Users");
	print "</tr>\n";

	#
	# Manage Players
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},
		      $post->input({-type=>"checkbox",
				    -id=>"MANAGE_PLAYERS_PRIV",
				    -name=>"MANAGE_PLAYERS_PRIV",
				    -value=>"1",
	       &GetLocalCheckedValue($post,"MANAGE_PLAYERS_PRIV",@$row[5])}));
	print $post->td({-colspan=>3,-align=>"left"},"Manage Players");
	print "</tr>\n";

	#
	# Manage Channels
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	my $channel_tag;
	if(@$row[6] eq "Y") {
	    $channel_tag="-checked";
	}
	print $post->td({-align=>"right"},
		      $post->input({-type=>"checkbox",
				    -id=>"MANAGE_CHANNELS_PRIV",
				    -name=>"MANAGE_CHANNELS_PRIV",
				    -value=>"1",
	       &GetLocalCheckedValue($post,"MANAGE_CHANNELS_PRIV",@$row[6])}));
	print $post->td({-colspan=>3,-align=>"left"},"Manage Channels");
	print "</tr>\n";

	#
	# Manage Servers
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},
		      $post->input({-type=>"checkbox",
				    -id=>"MANAGE_SERVERS_PRIV",
				    -name=>"MANAGE_SERVERS_PRIV",
				    -value=>"1",
	       &GetLocalCheckedValue($post,"MANAGE_SERVERS_PRIV",@$row[7])}));

	print $post->td({-colspan=>3,-align=>"left"},"Manage Servers");
	print "</tr>\n";

	#
	# Authorized Channels
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-valign=>"top",-align=>"right"},
			"<strong>Authorized Channels:</strong>");
	print "<td colspan=\"2\" align=\"left\">\n";
	print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"1\">\n";
	print "<tr bgcolor=\"".BGCOLOR2."\">\n";
	print "<th>NAME</th>\n";
	print "<th>TITLE</th>\n";
	print "</tr>\n";
	$sql=sprintf "select CHANNEL_PERMS.CHANNEL_NAME,CHANNELS.TITLE \
                      from CHANNEL_PERMS left join CHANNELS \
                      on CHANNEL_PERMS.CHANNEL_NAME=CHANNELS.NAME \
                      where CHANNEL_PERMS.USER_NAME=\"%s\" \
                      order by CHANNEL_PERMS.CHANNEL_NAME",
		      &EscapeString($user_name);
	my $q1=$dbh->prepare($sql);
	$q1->execute();
	while(my $row1=$q1->fetchrow_arrayref) {
	    print "<tr>\n";
	    print $post->td({-align=>"center",bgcolor=>"#FFFFFF"},@$row1[0]);
	    print $post->td({-align=>"left",bgcolor=>"#FFFFFF"},@$row1[1]);
	    print "</tr>\n";
	}
	$q1->finish();

	print "</table>\n";
	print "</td>\n";

	print $post->td({-align=>"left",-valign=>"top"},
			$post->input({-type=>"button",
				      -value=>"Edit\nChannels",
				      -onclick=>sprintf "authorizeChannels(%d,\'%s\')",$session_id,$user_name}));
	print "</tr>\n";

	#
	# OK Button
	#
	print "<tr>\n";
	print $post->td({-align=>"left"},
			$post->input({-type=>"submit",-value=>"OK"}));
	print "</form>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_USERS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->td({-colspan=>"3",-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";

    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitEditUser {
    my $user_name=$post->param("USER_NAME");
    my $users_priv="N";
    if($post->param("MANAGE_USERS_PRIV")) {
	$users_priv="Y";
    }
    my $players_priv="N";
    if($post->param("MANAGE_PLAYERS_PRIV")) {
	$players_priv="Y";
    }
    my $channels_priv="N";
    if($post->param("MANAGE_CHANNELS_PRIV")) {
	$channels_priv="Y";
    }
    my $servers_priv="N";
    if($post->param("MANAGE_SERVERS_PRIV")) {
	$servers_priv="Y";
    }
    my $sql=sprintf "update USERS set \
                     FULL_NAME=\"%s\",\
                     EMAIL_ADDRESS=\"%s\",\
                     PHONE_NUMBER=\"%s\",\
                     MANAGE_USERS_PRIV=\"%s\",\
                     MANAGE_PLAYERS_PRIV=\"%s\",\
                     MANAGE_CHANNELS_PRIV=\"%s\",\
                     MANAGE_SERVERS_PRIV=\"%s\" \
                     where NAME=\"%s\"",
		     &EscapeString($post->param("FULL_NAME")),
		     &EscapeString($post->param("EMAIL_ADDRESS")),
		     &EscapeString($post->param("PHONE_NUMBER")),
		     $users_priv,
		     $players_priv,
		     $channels_priv,
		     $servers_priv,
		     &EscapeString($user_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeDeleteUser {
    my $user_name=$post->param("USER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit User");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Are you sure that you want to delete this user?");
    print "</tr>\n";

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_DELETE_USER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>USER_NAME,
			-value=>$user_name});
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"Yes"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_USERS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"No"}));
    print "</form>\n";

    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitDeleteUser {
    my $user_name=$post->param("USER_NAME");
    my $sql=sprintf "delete from USERS where NAME=\"%s\"",
                     &EscapeString($user_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeChangeUserPassword {
    my $user_name=$post->param("USER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Change User Password");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_CHANGE_USER_PASSWORD});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>USER_NAME,
			-value=>$user_name});
    print $post->input({-type=>"hidden",-name=>"FULL_NAME",
			-value=>$post->param("FULL_NAME")});
    print $post->input({-type=>"hidden",-name=>"EMAIL_ADDRESS",
			-value=>$post->param("EMAIL_ADDRESS")});
    print $post->input({-type=>"hidden",-name=>"PHONE_NUMBER",
			-value=>$post->param("PHONE_NUMBER")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_USERS_PRIV",
			-value=>$post->param("MANAGE_USERS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_PLAYERS_PRIV",
			-value=>$post->param("MANAGE_PLAYERS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_CHANNELS_PRIV",
			-value=>$post->param("MANAGE_CHANNELS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_SERVERS_PRIV",
			-value=>$post->param("MANAGE_SERVERS_PRIV")});
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Change Password</big></big>");
    print "</tr>\n";

    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-align=>"right"},"<strong>Password:</strong>");
    print $post->td({-align=>"left"},
		    $post->input({-type=>"password",-name=>"PASSWORD1"}));
    print "</tr>\n";

    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-align=>"right"},"&nbsp;");
    print $post->td({-align=>"left"},
		    $post->input({-type=>"password",-name=>"PASSWORD2"}));
    print "</tr>\n";

    print "<tr>\n";
    print $post->td({-align=>"left"},$post->input({-type=>"submit",-value=>"OK"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_EDIT_USER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>USER_NAME,
			-value=>$user_name});
    print $post->input({-type=>"hidden",-name=>"FULL_NAME",
			-value=>$post->param("FULL_NAME")});
    print $post->input({-type=>"hidden",-name=>"EMAIL_ADDRESS",
			-value=>$post->param("EMAIL_ADDRESS")});
    print $post->input({-type=>"hidden",-name=>"PHONE_NUMBER",
			-value=>$post->param("PHONE_NUMBER")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_USERS_PRIV",
			-value=>$post->param("MANAGE_USERS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_PLAYERS_PRIV",
			-value=>$post->param("MANAGE_PLAYERS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_CHANNELS_PRIV",
			-value=>$post->param("MANAGE_CHANNELS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_SERVERS_PRIV",
			-value=>$post->param("MANAGE_SERVERS_PRIV")});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Cancel"}));
    print "</form>\n";

    print "</tr>\n";
}


sub CommitChangeUserPassword {
    my $user_name=$post->param("USER_NAME");
    my $password1=$post->param("PASSWORD1");
    my $password2=$post->param("PASSWORD2");
    if($password1 eq $password2) {
	my $sql=sprintf "update USERS set PASSWORD=\"%s\" where NAME=\"%s\"",
	&EscapeString($password1),&EscapeString($user_name);
	my $q=$dbh->prepare($sql);
	$q->execute();
	$q->finish();
	return 1;
    }
    return 0;
}


sub ServeUserPasswordInvalid {
    my $user_name=$post->param("USER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Change Password");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-align=>"center"},"The passwords don't match, password <strong>not</strong> changed!");
    print "</tr>\n";

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_EDIT_USER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>USER_NAME,
			-value=>$user_name});
    print $post->input({-type=>"hidden",-name=>"FULL_NAME",
			-value=>$post->param("FULL_NAME")});
    print $post->input({-type=>"hidden",-name=>"EMAIL_ADDRESS",
			-value=>$post->param("EMAIL_ADDRESS")});
    print $post->input({-type=>"hidden",-name=>"PHONE_NUMBER",
			-value=>$post->param("PHONE_NUMBER")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_USERS_PRIV",
			-value=>$post->param("MANAGE_USERS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_PLAYERS_PRIV",
			-value=>$post->param("MANAGE_PLAYERS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_CHANNELS_PRIV",
			-value=>$post->param("MANAGE_CHANNELS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_SERVERS_PRIV",
			-value=>$post->param("MANAGE_SERVERS_PRIV")});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"OK"}));
    print "</form>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub ServeEditChannelPerms {
    my $user_name=$post->param("USER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Channel Authorizations");
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";

    print "<tr>\n";
    print $post->td({-colspan=>3,-align=>"center"},
		    "<big><big>Channel Authorizations</big></big>");
    print "</tr>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-id=>COMMAND,-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_CHANNEL_PERMS});
    print $post->input({-id=>SESSION_ID,-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-id=>USER_NAME,-type=>"hidden",-name=>USER_NAME,
			-value=>$user_name});
    print $post->input({-type=>"hidden",-name=>"FULL_NAME",
			-value=>$post->param("FULL_NAME")});
    print $post->input({-type=>"hidden",-name=>"EMAIL_ADDRESS",
			-value=>$post->param("EMAIL_ADDRESS")});
    print $post->input({-type=>"hidden",-name=>"PHONE_NUMBER",
			-value=>$post->param("PHONE_NUMBER")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_USERS_PRIV",
			-value=>$post->param("MANAGE_USERS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_PLAYERS_PRIV",
			-value=>$post->param("MANAGE_PLAYERS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_CHANNELS_PRIV",
			-value=>$post->param("MANAGE_CHANNELS_PRIV")});
    print $post->input({-type=>"hidden",-name=>"MANAGE_SERVERS_PRIV",
			-value=>$post->param("MANAGE_SERVERS_PRIV")});

    #
    # Generate active channels list
    #
    my $sql=
	sprintf "select CHANNEL_PERMS.CHANNEL_NAME,CHANNELS.TITLE \
                 from CHANNEL_PERMS left join CHANNELS \
                 on CHANNEL_PERMS.CHANNEL_NAME=CHANNELS.NAME \
                 where CHANNEL_PERMS.USER_NAME=\"%s\" \
                 order by CHANNEL_PERMS.CHANNEL_NAME",
	        &EscapeString($user_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    my @active_names;
    my @active_chans;
    my $active_count=0;
    my $row;
    while($row=$q->fetchrow_arrayref) {
	$active_names[$active_count]=@$row[0];
	$active_chans[$active_count++]=@$row[0]." - ".@$row[1];
    }
    $q->finish();

    #
    # Generate full channel list
    #
    $sql=sprintf "select NAME,TITLE from CHANNELS order by NAME";
    $q=$dbh->prepare($sql);
    $q->execute();

    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-align=>"center"},"<strong>Available Channels</strong>");
    print $post->td({-align=>"center"},"&nbsp;");
    print $post->td({-align=>"center"},"<strong>Authorized Channels</strong>");
    print "</tr>\n";

    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print "<td align=\"center\">\n";
    print "<select id=\"CHANNEL_NAMES\" name=\"CHANNEL_NAMES\" size=\"12\" multiple>\n";
    while(my $row=$q->fetchrow_arrayref) {
	my $chan=@$row[0]." - ".@$row[1];
	my $match=0;
	for(my $i=0;$i<$active_count;$i++) {
	    if($active_chans[$i] eq $chan) {
		$match=1;
	    }
	}
	if($match==0) {
	    print $post->option({-value=>@$row[0]},$chan);
	}
    }
    print "</select>\n";
    print "</td>\n";

    print "<td align=\"center\">\n";
    print "<table cellpadding=\"0\" cellspacing=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print "<td align=\"center\">\n";
    print $post->input({-type=>"button",-name=>"MOVE_FROM",-value=>">",
			-onclick=>"editChannelPermsMoveFrom()"});
    print "</td>\n";
    print "</tr>\n";

    print "<tr>\n";
    print "<td align=\"center\">\n";
    print $post->input({-type=>"button",-name=>"MOVE_TO",-value=>"<",
			-onclick=>"editChannelPermsMoveTo()"});
    print "</td>\n";
    print "</tr>\n";

    print "<tr>\n";
    print $post->td("&nbsp;");
    print "</tr>\n";
    print "</td>\n";

    print "<td align=\"center\">\n";
    print "<tr>\n";
    print "<td align=\"center\">\n";
    print $post->input({-type=>"button",-name=>"MOVE_ALL_FROM",-value=>">>",
			-onclick=>"editChannelPermsMoveAllFrom()"});
    print "</td>\n";
    print "</tr>\n";

    print "<tr>\n";
    print "<td align=\"center\">\n";
    print $post->input({-type=>"button",-name=>"MOVE_ALL_TO",-value=>"<<",
			-onclick=>"editChannelPermsMoveAllTo()"});
    print "</td>\n";
    print "</tr>\n";
    print "</table>\n";

    print "<td align=\"center\">\n";
    print "<select id=\"AUTHORIZED_CHANNEL_NAMES\" name=\"AUTHORIZED_CHANNEL_NAMES\" size=\"12\" multiple>\n";
    for(my $i=0;$i<$active_count;$i++) {
	print $post->option({-value=>$active_names[$i]},$active_chans[$i]);    
    }
    print "</select>\n";
    print "</td>\n";

    print "</tr>\n";

    #
    # OK Button
    #
    print "<tr>\n";
    print $post->td({-align=>"left"},
		    $post->input({-type=>"button",-name=>"OK",-value=>"OK",
				  -onclick=>"submitChannelPerms()"}));
    print "</form>\n";

    print $post->td("&nbsp;");
    
    #
    # Cancel Button
    #
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_EDIT_USER});
    print $post->input({-type=>"hidden",-name=>USER_NAME,
			-value=>$user_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-id=>"FULL_NAME",-name=>"FULL_NAME",
			-value=>$post->param("FULL_NAME")});
    print $post->input({-type=>"hidden",-id=>"EMAIL_ADDRESS",
			-name=>"EMAIL_ADDRESS",
			-value=>$post->param("EMAIL_ADDRESS")});
    print $post->input({-type=>"hidden",-id=>"PHONE_NUMBER",
			-name=>"PHONE_NUMBER",
			-value=>$post->param("PHONE_NUMBER")});
    print $post->input({-type=>"hidden",-id=>"MANAGE_USERS_PRIV",
			-name=>"MANAGE_USERS_PRIV",
			-value=>$post->param("MANAGE_USERS_PRIV")});
    print $post->input({-type=>"hidden",-id=>"MANAGE_PLAYERS_PRIV",
			-name=>"MANAGE_PLAYERS_PRIV",
			-value=>$post->param("MANAGE_PLAYERS_PRIV")});
    print $post->input({-type=>"hidden",-id=>"MANAGE_CHANNELS_PRIV",
			-name=>"MANAGE_CHANNELS_PRIV",
			-value=>$post->param("MANAGE_CHANNELS_PRIV")});
    print $post->input({-type=>"hidden",-id=>"MANAGE_SERVERS_PRIV",
			-name=>"MANAGE_SERVERS_PRIV",
			-value=>$post->param("MANAGE_SERVERS_PRIV")});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Cancel"}));
    print "</form>\n";
    print "</tr>\n";
    
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitChannelPerms {
    my @names=$post->param;
    my $count=0;
    my $user_name=$post->param("USER_NAME");
    my $sql=sprintf "delete from CHANNEL_PERMS where USER_NAME=\"%s\"",
	&EscapeString($user_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $sql="select NAME from CHANNELS";
    $q=$dbh->prepare($sql);
    $q->execute();
    while(my $row=$q->fetchrow_arrayref) {
	if(defined $post->param(@$row[0])) {
	    $sql=sprintf "insert into CHANNEL_PERMS set \
                          USER_NAME=\"%s\",\
                          CHANNEL_NAME=\"%s\"",
			  &EscapeString($user_name),
			  &EscapeString(@$row[0]);
	    my $q1=$dbh->prepare($sql);
	    $q1->execute();
	    $q1->finish();
	}
    }    
    $q->finish();
}


sub ServeListPlayers {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Player List");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select NAME,TITLE from PLAYERS order by NAME";
    my $q=$dbh->prepare($sql);
    $q->execute();

    print "<tr>\n";
    print $post->td({-colspan=>6,-align=>"center"},
		    "<big><big>Loudwater Player List</big></big>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->th({-align=>"center"},"Name");
    print $post->th({-align=>"center"},"Title");
    print $post->th({-align=>"center"},"&nbsp;");
    print $post->th({-align=>"center"},"&nbsp;");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    while(my $row=$q->fetchrow_arrayref) {
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"left"},@$row[0]);
	if(@$row[1] eq "") {
	    print $post->td("&nbsp;");
	}
	else {
	    print $post->td({-align=>"left"},@$row[1]);
	}
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_PLAYER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Edit});
	print "</td>\n";
	print "</form>\n";
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_DELETE_PLAYER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Delete});
	print "</td>\n";
	print "</form>\n";

	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_ADD_PLAYER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Add Player"});
    print "</td>\n";
    print "</form>\n";

    print $post->td({-colspan=>2},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_MAIN_MENU});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub ServeAddPlayer {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Add Player");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Add Player</big></big>");
    print "</tr>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_ADD_PLAYER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print "<tr>\n";
    print $post->td({-bgcolor=>BGCOLOR1,-align=>"right"},"<strong><a href=\"admin-doc.html#new_player_name\" target=\"docs\">Player Name:</a></strong>");
    print $post->td({-bgcolor=>BGCOLOR1,-align=>"left"},
		    $post->input({-type=>"text",-size=>40,-maxlength=>32,
				  -name=>PLAYER_NAME}));
    print "</tr>\n";

    #
    # OK Button
    #
    print "<tr>\n";
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"OK"}));
    print "</form>\n";

    #
    # Cancel Button
    #
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_PLAYERS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Cancel"}));
    print "</form>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitAddPlayer {
    my $player_name=$post->param("PLAYER_NAME");
    my $sql=sprintf "insert into PLAYERS set NAME=\"%s\"",
                     &EscapeString($player_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeEditPlayer {
    my $player_name=$post->param("PLAYER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Player");
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select TITLE,LAYOUT,PLAYLIST_POSITION,PLAYLIST_FGCOLOR,\
                     PLAYLIST_BGCOLOR,\
                     PLAYLIST_HGCOLOR,PLAYLIST_SGCOLOR,BGCOLOR,SPLASH_LINK,\
                     LIVE_LINK,DEFAULT_LINK,\
                     AUDIO_LOGO_LINK,VIDEO_LOGO_LINK,LIVE_DIVIDER_HOUR,\
                     LIVE_ONDEMAND_LINK,LIVE_LIVE1_LINK,LIVE_LIVE2_LINK,\
                     LIVE_INACTIVE_LINK,SID,GATEWAY_QUALITY,\
                     USE_SYNCHED_BANNERS,\
                     BUTTON_SECTION_IMAGE,BUTTON_COLUMNS,BUTTON_ROWS,\
                     TOP_BANNER_CODE,SIDE_BANNER_CODE,\
                     OPTIONAL_LINK_CODE,HEAD_CODE,BASE_BRANDING_LINK,\
                     BANNER_HIMAGE_URL,BANNER_HIMAGE_WIDTH,\
                     BANNER_VIMAGE_URL,BANNER_VIMAGE_HEIGHT,\
                     SOCIAL_TEST,SOCIAL_FACEBOOK,SOCIAL_FACEBOOK_ADMIN,\
                     SOCIAL_DISPLAY_LINK from PLAYERS where NAME=\"%s\"",
		     &EscapeString($player_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>3,-align=>"center"},
			"<big><big>Edit Player</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_PLAYER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>$player_name});

	#
	# GENERAL Section
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"center"},"<strong>GENERAL</strong>");
	print $post->td({-colspan=>3,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# Player Name
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#player_name\" target=\"docs\">Player Name:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},$player_name);
	print "</tr>\n";

	#
	# Title
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#title\" target=\"docs\">Title:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"TITLE",-name=>"TITLE",
	       -value=>&GetLocalValue($post,"TITLE",@$row[0])}));
	print "</tr>\n";

	#
	# Layout
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#layout\" target=\"docs\">Layout:</a></strong>");
	print "<td colspan=\"3\" align=\"left\">\n";
	print "<select id=\"LAYOUT\" name=\"LAYOUT\">\n";
        if(&GetLocalValue($post,"LAYOUT",@$row[1]) eq "S") {
	    print $post->option({-value=>"S",-selected},"Standard");
	    print $post->option({-value=>"W"},"Wide-Screen");
	}
	else {
	    print $post->option({-value=>"S"},"Standard");
	    print $post->option({-value=>"W",-selected},"Wide-Screen");
	}
	print "</select>\n";	
	print "</td>\n";
	print "</tr>\n";

	#
	# Playlist Position
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#playlist_position\" target=\"docs\">Playlist Position:</a></strong>");
	print "<td colspan=\"3\" align=\"left\">\n";
	print "<select id=\"PLAYLIST_POSITION\" name=\"PLAYLIST_POSITION\">\n";
        if(&GetLocalValue($post,"PLAYLIST_POSITION",@$row[2]) eq "left") {
	    print $post->option({-value=>"left",-selected},"Left");
	    print $post->option({-value=>"right"},"Right");
	    print $post->option({-value=>"bottom"},"Bottom");
	    print $post->option({-value=>"over"},"Over");
	    print $post->option({-value=>"none"},"None");
	}
	else {
	    if(&GetLocalValue($post,"PLAYLIST_POSITION",@$row[2]) eq "right") {
		print $post->option({-value=>"left"},"Left");
		print $post->option({-value=>"right",-selected},"Right");
		print $post->option({-value=>"bottom"},"Bottom");
		print $post->option({-value=>"over"},"Over");
		print $post->option({-value=>"none"},"None");
	    }
	    else {
		if(&GetLocalValue($post,"PLAYLIST_POSITION",@$row[2]) eq "bottom") {
		    print $post->option({-value=>"left"},"Left");
		    print $post->option({-value=>"right"},"Right");
		    print $post->option({-value=>"bottom",-selected},"Bottom");
		    print $post->option({-value=>"over"},"Over");
		    print $post->option({-value=>"none"},"None");
		}
		else {
		    if(&GetLocalValue($post,"PLAYLIST_POSITION",@$row[2]) eq "over") {
			print $post->option({-value=>"left"},"Left");
			print $post->option({-value=>"right"},"Right");
			print $post->option({-value=>"bottom"},"Bottom");
			print $post->option({-value=>"over",-selected},"Over");
			print $post->option({-value=>"none"},"None");
		    }
		    else {
			print $post->option({-value=>"left"},"Left");
			print $post->option({-value=>"right"},"Right");
			print $post->option({-value=>"bottom"},"Bottom");
			print $post->option({-value=>"over"},"Over");
			print $post->option({-value=>"none",-selected},"None");
		    }
		}
	    }
	}
	print "</select>\n";	
	print "</td>\n";
	print "</tr>\n";

	#
	# Playlist Text Color
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#playlist_fgcolor\" target=\"docs\">Playlist Text Color:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>8,-maxlength=>7,-type=>"text",
				      -id=>"PLAYLIST_FGCOLOR",
				      -name=>"PLAYLIST_FGCOLOR",
	       -value=>&GetLocalValue($post,"PLAYLIST_FGCOLOR",@$row[3])}));
	print "</tr>\n";

	#
	# Playlist Background Color
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#playlist_bgcolor\" target=\"docs\">Playlist Background Color:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>8,-maxlength=>7,-type=>"text",
				      -id=>"PLAYLIST_BGCOLOR",
				      -name=>"PLAYLIST_BGCOLOR",
	       -value=>&GetLocalValue($post,"PLAYLIST_BGCOLOR",@$row[4])}));
	print "</tr>\n";

	#
	# Playlist Highlight Color
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#playlist_hgcolor\" target=\"docs\">Playlist Highlight Color:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>8,-maxlength=>7,-type=>"text",
				      -id=>"PLAYLIST_HGCOLOR",
				      -name=>"PLAYLIST_HGCOLOR",
	       -value=>&GetLocalValue($post,"PLAYLIST_HGCOLOR",@$row[5])}));
	print "</tr>\n";

	#
	# Screen Background Color
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#playlist_sgcolor\" target=\"docs\">Screen Background Color:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>8,-maxlength=>7,-type=>"text",
				      -id=>"PLAYLIST_SGCOLOR",
				      -name=>"PLAYLIST_SGCOLOR",
	       -value=>&GetLocalValue($post,"PLAYLIST_SGCOLOR",@$row[6])}));
	print "</tr>\n";

	#
	# Overall Background Color
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#bgcolor\" target=\"docs\">Overall Background Color:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>8,-maxlength=>7,-type=>"text",
				      -id=>"BGCOLOR",-name=>"BGCOLOR",
	       -value=>&GetLocalValue($post,"BGCOLOR",@$row[7])}));
	print "</tr>\n";

	#
	# Splash Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#splash_link\" target=\"docs\">Splash Link:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"SPLASH_LINK",-name=>"SPLASH_LINK",
	       -value=>&GetLocalValue($post,"SPLASH_LINK",@$row[8])}));
	print "</tr>\n";

	#
	# Audio Logo Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#audio_logo_link\" target=\"docs\">Audio Logo Link:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"AUDIO_LOGO_LINK",
				      -name=>"AUDIO_LOGO_LINK",
	      -value=>&GetLocalValue($post,"AUDIO_LOGO_LINK",@$row[11])}));
	print "</tr>\n";

	#
	# Video Logo Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#video_logo_link\" target=\"docs\">Video Logo Link:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"VIDEO_LOGO_LINK",
				      -name=>"VIDEO_LOGO_LINK",
	       -value=>&GetLocalValue($post,"VIDEO_LOGO_LINK",@$row[12])}));
	print "</tr>\n";

	#
	# Custom Branding Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#base_branding_link\" target=\"docs\">Custom Branding Link:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"BASE_BRANDING_LINK",
				      -name=>"BASE_BRANDING_LINK",
	       -value=>&GetLocalValue($post,"BASE_BRANDING_LINK",@$row[28])}));
	print "</tr>\n";

	#
	# Optional Link Code
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-valign=>"top",-align=>"right"},
			"<strong><a href=\"admin-doc.html#link_button_code\" target=\"docs\">Link Button Code:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->textarea({-rows=>3,-columns=>60,
					 -id=>"OPTIONAL_LINK_CODE",
					 -name=>"OPTIONAL_LINK_CODE",
	      -value=>&GetLocalValue($post,"OPTIONAL_LINK_CODE",@$row[26])}));
	print "</tr>\n";

	#
	# Spacer
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-colspan=>4,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# BANNERS Section
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"center"},"<strong>BANNERS</strong>");
	print $post->td({-colspan=>3,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# Horizontal Logo URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#banner_himage_url\" target=\"docs\">Horizontal Logo URL:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"BANNER_HIMAGE_URL",
				      -name=>"BANNER_HIMAGE_URL",
	       -value=>&GetLocalValue($post,"BANNER_HIMAGE_URL",@$row[29])}));
	print "</tr>\n";

	#
	# Horizontal Logo Width
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#banner_himage_width\" target=\"docs\">Horizontal Logo Width:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>4,-maxlength=>3,-type=>"text",
				      -id=>"BANNER_HIMAGE_WIDTH",
				      -name=>"BANNER_HIMAGE_WIDTH",
	       -value=>&GetLocalValue($post,"BANNER_HIMAGE_WIDTH",@$row[30])}));
	print "</tr>\n";

	#
	# Vertical Logo URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#banner_vimage_url\" target=\"docs\">Vertical Logo URL:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"BANNER_VIMAGE_URL",
				      -name=>"BANNER_VIMAGE_URL",
	       -value=>&GetLocalValue($post,"BANNER_VIMAGE_URL",@$row[31])}));
	print "</tr>\n";

	#
	# Vertical Logo Height
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#banner_vimage_height\" target=\"docs\">Vertical Logo Width:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>4,-maxlength=>3,-type=>"text",
				      -id=>"BANNER_VIMAGE_HEIGHT",
				      -name=>"BANNER_VIMAGE_HEIGHT",
	       -value=>&GetLocalValue($post,"BANNER_VIMAGE_HEIGHT",@$row[32])}));
	print "</tr>\n";

	#
	# Spacer
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-colspan=>4,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# LIVE STREAMING Section
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"center"},"<strong>LIVE STREAMING</strong>");
	print $post->td({-colspan=>3,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# Default Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#default_link\" target=\"docs\">Default Link:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"DEFAULT_LINK",
				      -name=>"DEFAULT_LINK",
	       -value=>&GetLocalValue($post,"DEFAULT_LINK",@$row[10])}));
	print "</tr>\n";

	#
	# Live Segments
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#live_segments\" target=\"docs\">Live Segments (UTC):</a></strong>");
	print "<td colspan=\"3\" align=\"left\">\n";
	print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"1\">\n";
	print "<tr bgcolor=\"".BGCOLOR2."\">\n";
	print "<th>Start</th>\n";
	print "<th>Hours</th>\n";
	print "<th>Mo</th>\n";
	print "<th>Tu</th>\n";
	print "<th>We</th>\n";
	print "<th>Th</th>\n";
	print "<th>Fr</th>\n";
	print "<th>Sa</th>\n";
	print "<th>Su</th>\n";
	print $post->th({-colspan=>"2",-align=>"center"},
			$post->input({-type=>"button",
				-value=>"Add Live Segment",
				-onclick=>sprintf "addLiveSegment(%d,\'%s\')",
				      $session_id,$player_name}));
	print "</tr>\n";

	$sql=sprintf "select SUN,MON,TUE,WED,THU,FRI,SAT,START_HOUR,RUN_LENGTH,\
                      ID from LIVE_SEGMENTS where PLAYER_NAME=\"%s\"\
                      order by START_HOUR",&EscapeString($player_name);
	my $q1=$dbh->prepare($sql);
	$q1->execute();
	while(my $row1=$q1->fetchrow_arrayref) {
	    print "<tr bgcolor=\"#FFFFFF\">\n";
	    print $post->td({-align=>"center"},@$row1[7].":00:00");
	    print $post->td({-align=>"center"},@$row1[8]/3600);
	    print $post->td({-align=>"center"},@$row1[1]);
	    print $post->td({-align=>"center"},@$row1[2]);
	    print $post->td({-align=>"center"},@$row1[3]);
	    print $post->td({-align=>"center"},@$row1[4]);
	    print $post->td({-align=>"center"},@$row1[5]);
	    print $post->td({-align=>"center"},@$row1[6]);
	    print $post->td({-align=>"center"},@$row1[0]);
	    print $post->td({-align=>"left"}, 
		     $post->input({-type=>"button",-value=>"Edit",
			 -onclick=>sprintf "editLiveSegment(%d,\'%s\',%d)",
				   $session_id,$player_name,@$row1[9]}));
	    print $post->td({-align=>"right"},
		     $post->input({-type=>"button",-value=>"Delete",
		         -onclick=>sprintf "deleteLiveSegment(%d,\'%s\',%d)",
				   $session_id,$player_name,@$row1[9]}));
	    print "</tr>\n";
	}
	print "</table>\n";
	print "</td>\n";
	print "</tr>\n";

	#
	# Spacer
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-colspan=>4,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# ANDO AD INJECTION Section
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"center"},"<strong>ANDO AD INJECTION</strong>");
	print $post->td({-colspan=>3,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# ANDO Station ID
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#ando_station_id\" target=\"docs\">ANDO Station ID:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>6,-maxlength=>6,-type=>"text",
				      -id=>"SID",-name=>"SID",
	       -value=>&GetLocalValue($post,"SID",@$row[18])}));
	print "</tr>\n";

	#
	# Gateway Quality
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#ad_quality\" target=\"docs\">Ad Quality:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>5,-maxlength=>2,-type=>"text",
				      -id=>"GATEWAY_QUALITY",
				      -name=>"GATEWAY_QUALITY",
	       -value=>&GetLocalValue($post,"GATEWAY_QUALITY",@$row[19])}));
	print "</tr>\n";

	#
	# Synched Banners
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#use_synched_banners\" target=\"docs\">Use Synched Banners:</a></strong>");
	print "<td colspan=\"3\" align=\"left\">\n";
	print "<select id=\"USE_SYNCHED_BANNERS\" name=\"USE_SYNCHED_BANNERS\">\n";
        if(&GetLocalValue($post,"USE_SYNCHED_BANNERS",@$row[20]) eq "Y") {
	    print $post->option({-value=>"Y",-selected},"Yes");
	    print $post->option({-value=>"N"},"No");
	}
	else {
	    print $post->option({-value=>"Y"},"Yes");
	    print $post->option({-value=>"N",-selected},"No");
	}
	print "</select>\n";	
	print "</td>\n";
	print "</tr>\n";

	#
	# Spacer
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-colspan=>4,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# CHANNEL BUTTONS Section
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"center"},"<strong>CHANNEL BUTTONS</strong>");
	print $post->td({-colspan=>3,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# Button Section Image Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#button_section_image_link\" target=\"docs\">Button Section Image Link:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"BUTTON_SECTION_IMAGE",
				      -name=>"BUTTON_SECTION_IMAGE",
	      -value=>&GetLocalValue($post,"BUTTON_SECTION_IMAGE",@$row[21])}));
	print "</tr>\n";

	#
	# Button Columns
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#button_columns\" target=\"docs\">Button Columns:</a></strong>");
	print $post->td({-align=>"left"},
			$post->input({-size=>5,-maxlength=>2,-type=>"text",
				      -id=>"BUTTON_COLUMNS",
				      -name=>"BUTTON_COLUMNS",
	       -value=>&GetLocalValue($post,"BUTTON_COLUMNS",@$row[22])}));
	print $post->td({-colspan=>"2",-align=>"left"},
			$post->input({-type=>"button",-value=>"Edit Buttons",
				  -onclick=>sprintf "editButtons(%d,\'%s\')",
				      $session_id,$player_name}));
	print "</tr>\n";

	#
	# Button Rows
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#button_rows\" target=\"docs\">Button Rows:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>5,-maxlength=>2,-type=>"text",
				      -id=>"BUTTON_ROWS",
				      -name=>"BUTTON_ROWS",
	       -value=>&GetLocalValue($post,"BUTTON_ROWS",@$row[23])}));
	print "</tr>\n";

	#
	# Spacer
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-colspan=>4,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# BANNERS Section
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"center"},"<strong>BANNERS</strong>");
	print $post->td({-colspan=>3,-align=>"left"},"&nbsp;");
	print "</tr>\n";

	#
	# Head Code
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-valign=>"top",-align=>"right"},
			"<strong><a href=\"admin-doc.html#head_code\" target=\"docs\">Head Code:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->textarea({-rows=>3,-columns=>60,
					 -id=>"HEAD_CODE",
					 -name=>"HEAD_CODE",
	       -value=>&GetLocalValue($post,"HEAD_CODE",@$row[27])}));
	print "</tr>\n";

	#
	# Top Banner Code
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-valign=>"top",-align=>"right"},
			"<strong><a href=\"admin-doc.html#top_banner_code\" target=\"docs\">Top Banner Code:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->textarea({-rows=>3,-columns=>60,
					 -id=>"TOP_BANNER_CODE",
					 -name=>"TOP_BANNER_CODE",
	       -value=>&GetLocalValue($post,"TOP_BANNDER_CODE",@$row[24])}));
	print "</tr>\n";

	#
	# Side Banner Code
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-valign=>"top",-align=>"right"},
			"<strong><a href=\"admin-doc.html#side_banner_code\" target=\"docs\">Side Banner Code:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->textarea({-rows=>3,-columns=>60,
					 -id=>"SIDE_BANNER_CODE",
					 -name=>"SIDE_BANNER_CODE",
	       -value=>&GetLocalValue($post,"SIDE_BANNER_CODE",@$row[25])}));
	print "</tr>\n";

	#
	# SOCIAL MEDIA Section
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"center"},"<strong>SOCIAL MEDIA</strong>");
	print $post->td({-colspan=>3,-align=>"left"},"&nbsp;");
	print "</tr>\n";

 	#
	# TEST Social Media Server
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#social_test\" target=\"docs\">Test Service:</a></strong>");
	print "<td colspan=\"3\" align=\"left\">\n";
	print "<select id=\"SOCIAL_TEST\" name=\"SOCIAL_TEST\">\n";
        if(&GetLocalValue($post,"SOCIAL_TEST",@$row[33]) eq "Y") {
	    print $post->option({-value=>"Y",-selected},"Yes");
	    print $post->option({-value=>"N"},"No");
	}
	else {
	    print $post->option({-value=>"Y"},"Yes");
	    print $post->option({-value=>"N",-selected},"No");
	}
	print "</select>\n";	
	print "</td>\n";
	print "</tr>\n";

 	#
	# DISPLAY LINK Social Media Server
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#social_display_link\" target=\"docs\">Display Episode Links:</a></strong>");
	print "<td colspan=\"3\" align=\"left\">\n";
	print "<select id=\"SOCIAL_DISPLAY_LINK\" name=\"SOCIAL_DISPLAY_LINK\">\n";
        if(&GetLocalValue($post,"SOCIAL_TEST",@$row[36]) eq "Y") {
	    print $post->option({-value=>"Y",-selected},"Yes");
	    print $post->option({-value=>"N"},"No");
	}
	else {
	    print $post->option({-value=>"Y"},"Yes");
	    print $post->option({-value=>"N",-selected},"No");
	}
	print "</select>\n";	
	print "</td>\n";
	print "</tr>\n";

	#
	# FACEBOOK Social Media Server
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#social_facebook\" target=\"docs\">FaceBook:</a></strong>");
	print "<td colspan=\"3\" align=\"left\">\n";
	print "<select id=\"SOCIAL_FACEBOOK\" name=\"SOCIAL_FACEBOOK\">\n";
        if(&GetLocalValue($post,"SOCIAL_FACEBOOK",@$row[34]) eq "Y") {
	    print $post->option({-value=>"Y",-selected},"Yes");
	    print $post->option({-value=>"N"},"No");
	}
	else {
	    print $post->option({-value=>"Y"},"Yes");
	    print $post->option({-value=>"N",-selected},"No");
	}
	print "</select>\n";	
	print "</td>\n";
	print "</tr>\n";

	#
	# FACEBOOK Administrator ID
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#social_facebook_admin\" target=\"docs\">Facebook Administrator ID:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"SOCIAL_FACEBOOK_ADMIN",
				      -name=>"SOCIAL_FACEBOOK_ADMIN",
	       -value=>&GetLocalValue($post,"SOCIAL_FACEBOOK_ADMIN",@$row[35])}));
	print "</tr>\n";


	#
	# OK Button
	#
	print "<tr>\n";
	print $post->td({-colspan=>"2",-align=>"left"},
			$post->input({-type=>"submit",-value=>"OK"}));
	print "</form>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_PLAYERS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";
    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitEditPlayer {
    my $player_name=$post->param("PLAYER_NAME");
    my $sql=sprintf "update PLAYERS set \
                     TITLE=\"%s\",\
                     LAYOUT=\"%s\",\
                     PLAYLIST_POSITION=\"%s\",\
                     PLAYLIST_FGCOLOR=\"%s\",\
                     PLAYLIST_BGCOLOR=\"%s\",\
                     PLAYLIST_HGCOLOR=\"%s\",\
                     PLAYLIST_SGCOLOR=\"%s\",\
                     BGCOLOR=\"%s\",\
                     SPLASH_LINK=\"%s\",\
                     DEFAULT_LINK=\"%s\",\
                     AUDIO_LOGO_LINK=\"%s\",\
                     VIDEO_LOGO_LINK=\"%s\",\
                     BANNER_VIMAGE_URL=\"%s\",\
                     BANNER_VIMAGE_HEIGHT=%d,\
                     BANNER_HIMAGE_URL=\"%s\",\
                     BANNER_HIMAGE_WIDTH=%d,\
                     SID=%d,\
                     GATEWAY_QUALITY=%d,\
                     USE_SYNCHED_BANNERS=\"%s\",\
                     BUTTON_SECTION_IMAGE=\"%s\",\
                     BUTTON_COLUMNS=%d,\
                     BUTTON_ROWS=%d,\
                     TOP_BANNER_CODE=\"%s\",\
                     SIDE_BANNER_CODE=\"%s\",\
                     OPTIONAL_LINK_CODE=\"%s\",\
                     HEAD_CODE=\"%s\",\
                     BASE_BRANDING_LINK=\"%s\",\
                     SOCIAL_TEST=\"%s\",\
                     SOCIAL_DISPLAY_LINK=\"%s\",\
                     SOCIAL_FACEBOOK=\"%s\",\
                     SOCIAL_FACEBOOK_ADMIN=\"%s\" \
                     where NAME=\"%s\"",
		     &EscapeString($post->param("TITLE")),
		     $post->param("LAYOUT"),
		     $post->param("PLAYLIST_POSITION"),
		     &EscapeString($post->param("PLAYLIST_FGCOLOR")),
		     &EscapeString($post->param("PLAYLIST_BGCOLOR")),
		     &EscapeString($post->param("PLAYLIST_HGCOLOR")),
		     &EscapeString($post->param("PLAYLIST_SGCOLOR")),
		     &EscapeString($post->param("BGCOLOR")),
		     &EscapeString($post->param("SPLASH_LINK")),
		     &EscapeString($post->param("DEFAULT_LINK")),
		     &EscapeString($post->param("AUDIO_LOGO_LINK")),
		     &EscapeString($post->param("VIDEO_LOGO_LINK")),
		     &EscapeString($post->param("BANNER_VIMAGE_URL")),
		     &EscapeString($post->param("BANNER_VIMAGE_HEIGHT")),
		     &EscapeString($post->param("BANNER_HIMAGE_URL")),
		     &EscapeString($post->param("BANNER_HIMAGE_WIDTH")),
		     &EscapeString($post->param("SID")),
		     &EscapeString($post->param("GATEWAY_QUALITY")),
		     $post->param("USE_SYNCHED_BANNERS"),
		     &EscapeString($post->param("BUTTON_SECTION_IMAGE")),
		     &EscapeString($post->param("BUTTON_COLUMNS")),
		     &EscapeString($post->param("BUTTON_ROWS")),
		     &EscapeString($post->param("TOP_BANNER_CODE")),
		     &EscapeString($post->param("SIDE_BANNER_CODE")),
		     &EscapeString($post->param("OPTIONAL_LINK_CODE")),
		     &EscapeString($post->param("HEAD_CODE")),
		     &EscapeString($post->param("BASE_BRANDING_LINK")),
		     $post->param("SOCIAL_TEST"),
		     $post->param("SOCIAL_DISPLAY_LINK"),
		     $post->param("SOCIAL_FACEBOOK"),
		     &EscapeString($post->param("SOCIAL_FACEBOOK_ADMIN")),
		     &EscapeString($player_name);
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    #
    # Verify Channel Buttons
    #
    $button_columns=$post->param("BUTTON_COLUMNS");
    $button_rows=$post->param("BUTTON_ROWS");
    for(my $i=0;$i<$button_columns;$i++) {
	for(my $j=0;$j<$button_rows;$j++) {
	    $sql=sprintf "insert into CHANNEL_BUTTONS set \
                          PLAYER_NAME=\"%s\",\
                          BUTTON_NUMBER=%d",
                          &EscapeString($player_name),
			  $button_rows*$i+$j;
	    $q=$dbh->prepare($sql);
	    $q->execute();
	    $q->finish();
	}
    }
}


sub ServeDeletePlayer {
    my $player_name=$post->param("PLAYER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Player");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Are you sure that you want to delete this player?");
    print "</tr>\n";

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_DELETE_PLAYER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			-value=>$player_name});
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"Yes"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_PLAYERS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"No"}));
    print "</form>\n";

    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitDeletePlayer {
    my $player_name=$post->param("PLAYER_NAME");
    my $sql=sprintf "delete from PLAYERS where NAME=\"%s\"",
                     &EscapeString($player_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeListLivesegments {
    my $player_name=$post->param("PLAYER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Live Segment List");
    print "</head>\n";

    print "<body>\n";
    print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"0\">\n";

    #
    # Page Title
    #
    print "<tr>\n";
    print $post->td({-colspan=>11,-align=>"center"},
		     "<big><big>Live Segments</big></big>");
    print "</tr>\n";
    print "<tr>\n";
    printf "<td colspan=\"11\" align=\"center\"><big>Player \"%s\"</big></td>\n",$player_name;
    print "</tr>\n";

    #
    # Segment Table
    #
    
    my $bgcolor=BGCOLOR1;
    $sql=sprintf "select SUN,MON,TUE,WED,THU,FRI,SAT,START_HOUR,RUN_LENGTH,\
                  LIVE_LINK,LOGO_LINK,SID,ID from LIVE_SEGMENTS \
                  where PLAYER_NAME=\"%s\" order by START_HOUR",
		  &EscapeString($player_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    while(my $row=$q->fetchrow_arrayref) {
	print "<tr bgcolor=\"#FFFFFF\">\n";
	print "<th><a href=\"admin-doc.html#live_link\" target=\"docs\">Start Time</a></th>\n";
	print "<th><a href=\"admin-doc.html#run_hours\" target=\"docs\">Run Hours</a></th>\n";
	print "<th><a href=\"admin-doc.html#run_on\" target=\"docs\">Mon</a></th>\n";
	print "<th><a href=\"admin-doc.html#run_on\" target=\"docs\">Tue</a></th>\n";
	print "<th><a href=\"admin-doc.html#run_on\" target=\"docs\">Wed</a></th>\n";
	print "<th><a href=\"admin-doc.html#run_on\" target=\"docs\">Thu</a></th>\n";
	print "<th><a href=\"admin-doc.html#run_on\" target=\"docs\">Fri</a></th>\n";
	print "<th><a href=\"admin-doc.html#run_on\" target=\"docs\">Sat</a></th>\n";
	print "<th><a href=\"admin-doc.html#run_on\" target=\"docs\">Sun</a></th>\n";
	print "<th>&nbsp;</th>\n";
	print "<th>&nbsp;</th>\n";
	print "</tr>\n";
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"center"},@$row[7].":00:00");
	print $post->td({-align=>"center"},@$row[8]/3600);
	print $post->td({-align=>"center"},@$row[1]);
	print $post->td({-align=>"center"},@$row[2]);
	print $post->td({-align=>"center"},@$row[3]);
	print $post->td({-align=>"center"},@$row[4]);
	print $post->td({-align=>"center"},@$row[5]);
	print $post->td({-align=>"center"},@$row[6]);
	print $post->td({-align=>"center"},@$row[0]);
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_LIVESEGMENT});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>SEGMENT_ID,
			    -value=>@$row[12]});
	print $post->input({-type=>"submit",-value=>Edit});
	print "</td>\n";
	print "</form>\n";
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_DELETE_LIVESEGMENT});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>$player_name});
	print $post->input({-type=>"hidden",-name=>SEGMENT_ID,
			    -value=>@$row[12]});
	print $post->input({-type=>"submit",-value=>Delete});
	print "</td>\n";
	print "</form>\n";
	print "</tr>\n";

	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#live_link\" target=\"docs\">Live Link:</a></strong>");
	print $post->td({-colspan=>10,-align=>"left"},@$row[9]);
	print "</tr>\n";

	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#logo_link\" target=\"docs\">Logo Link:</a></strong>");
	print $post->td({-colspan=>10,-align=>"left"},@$row[10]);
	print "</tr>\n";

	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#logo_sid\" target=\"docs\">Ando SID:</a></strong>");
	print $post->td({-colspan=>10,-align=>"left"},@$row[11]);
	print "</tr>\n";

	print "<tr bgcolor=\"#FFFFFF\">\n";
	print $post->td("&nbsp;");
	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_ADD_LIVESEGMENT});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			-value=>$player_name});
    print $post->input({-type=>"submit",-value=>"Add Segment"});
    print "</td>\n";
    print "</form>\n";

    print $post->td({-colspan=>2},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td colspan=\"9\" align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_EDIT_PLAYER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			-value=>$player_name});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub AddLiveSegment {
}


sub CommitAddLivesegment {
    my $player_name=$post->param("PLAYER_NAME");
    my $sql=sprintf 
	"insert into LIVE_SEGMENTS set PLAYER_NAME=\"%s\"",
	&EscapeString($player_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
    $new_segment_id=$dbh->{q{mysql_insertid}};
}


sub ServeEditLivesegment {
    my $segment_id=$new_segment_id;
    if($segment_id==0) {
	$segment_id=$post->param("SEGMENT_ID");
    }
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Live Segment");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select SUN,MON,TUE,WED,THU,FRI,SAT,START_HOUR,RUN_LENGTH,\
                     PLAYER_NAME,LIVE_LINK,LOGO_LINK,SID from LIVE_SEGMENTS \
                     where ID=%d order by START_HOUR",$segment_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>3,-align=>"center"},
			"<big><big>Edit Live Segment</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_LIVESEGMENT});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>@$row[9]});
	print $post->input({-type=>"hidden",-name=>SEGMENT_ID,
			    -value=>$segment_id});

	#
	# Live Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#live_link\" target=\"docs\">Live Link:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>60,-maxlength=>255,
				      -name=>LIVE_LINK,-value=>@$row[10]}));
	print "</tr>\n";

	#
	# Logo Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#logo_link\" target=\"docs\">Logo Link:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>60,-maxlength=>255,
				      -name=>LOGO_LINK,-value=>@$row[11]}));
	print "</tr>\n";

	#
	# SID
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#logo_sid\" target=\"docs\">Ando Station ID:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>5,-maxlength=>5,
				      -name=>"SEGMENT_SID",-value=>@$row[12]}));
	print "</tr>\n";

	#
	# Start Time
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#start_time\" target=\"docs\">Start Time (UTC):</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>1,-maxlength=>2,
				      -name=>START_HOUR,-value=>@$row[7]}).
			":00:00");
	print "</tr>\n";

	#
	# Run Hours
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#run_hours\" target=\"docs\">Run Hours:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>2,-maxlength=>2,
				      -name=>RUN_LENGTH,
				      -value=>@$row[8]/3600}));
	print "</tr>\n";

	#
	# Days of the Week
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-colspan=>3,-align=>"center"},
			"<strong><a href=\"admin-doc.html#run_on\" target=\"docs\">Run On</a></strong>");
	print "</tr>\n";

	#
	# Monday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	my $user_tag;
	if(@$row[1] eq "Y") {
	    $user_tag="-checked";
	}
	print $post->td({-align=>"right"},
			$post->input({-type=>"checkbox",-name=>MON,
				      -value=>"1",$user_tag}));
	print $post->td({-colspan=>2,-align=>"left"},"Monday");
	print "</tr>\n";

	#
	# Tuesday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	$user_tag="";
	if(@$row[2] eq "Y") {
	    $user_tag="-checked";
	}
	print $post->td({-align=>"right"},
			$post->input({-type=>"checkbox",-name=>TUE,
				      -value=>"1",$user_tag}));
	print $post->td({-colspan=>2,-align=>"left"},"Tuesday");
	print "</tr>\n";

	#
	# Wednesday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	$user_tag="";
	if(@$row[3] eq "Y") {
	    $user_tag="-checked";
	}
	print $post->td({-align=>"right"},
			$post->input({-type=>"checkbox",-name=>WED,
				      -value=>"1",$user_tag}));
	print $post->td({-colspan=>2,-align=>"left"},"Wednesday");
	print "</tr>\n";

	#
	# Thursday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	$user_tag="";
	if(@$row[4] eq "Y") {
	    $user_tag="-checked";
	}
	print $post->td({-align=>"right"},
			$post->input({-type=>"checkbox",-name=>THU,
				      -value=>"1",$user_tag}));
	print $post->td({-colspan=>2,-align=>"left"},"Thursday");
	print "</tr>\n";

	#
	# Friday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	$user_tag="";
	if(@$row[5] eq "Y") {
	    $user_tag="-checked";
	}
	print $post->td({-align=>"right"},
			$post->input({-type=>"checkbox",-name=>FRI,
				      -value=>"1",$user_tag}));
	print $post->td({-colspan=>2,-align=>"left"},"Friday");
	print "</tr>\n";

	#
	# Saturday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	$user_tag="";
	if(@$row[6] eq "Y") {
	    $user_tag="-checked";
	}
	print $post->td({-align=>"right"},
			$post->input({-type=>"checkbox",-name=>SAT,
				      -value=>"1",$user_tag}));
	print $post->td({-colspan=>2,-align=>"left"},"Saturday");
	print "</tr>\n";

	#
	# Sunday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	$user_tag="";
	if(@$row[0] eq "Y") {
	    $user_tag="-checked";
	}
	print $post->td({-align=>"right"},
			$post->input({-type=>"checkbox",-name=>SUN,
				      -value=>"1",$user_tag}));
	print $post->td({-colspan=>2,-align=>"left"},"Sunday");
	print "</tr>\n";

	#
	# OK Button
	#
	print "<tr>\n";
	print $post->input({-type=>"hidden",-name=>"TITLE",-id=>"TITLE",
			    -value=>$post->param("TITLE")});
	print $post->input({-type=>"hidden",-name=>"SPLASH_LINK",
			    -id=>"SPLASH_LINK",
			    -value=>$post->param("SPLASH_LINK")});
	print $post->input({-type=>"hidden",-name=>"AUDIO_LOGO_LINK",
			    -id=>"AUDIO_LOGO_LINK",
			    -value=>$post->param("AUDIO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"VIDEO_LOGO_LINK",
			    -id=>"VIDEO_LOGO_LINK",
			    -value=>$post->param("VIDEO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"OPTIONAL_LINK_CODE",
			    -id=>"OPTIONAL_LINK_CODE",
			    -value=>$post->param("OPTIONAL_LINK_CODE")});
	print $post->input({-type=>"hidden",-name=>"DEFAULT_LINK",
			    -id=>"DEFAULT_LINK",
			    -value=>$post->param("DEFAULT_LINK")});
	print $post->input({-type=>"hidden",-name=>"SID",
			    -id=>"SID",
			    -value=>$post->param("SID")});
	print $post->input({-type=>"hidden",-name=>"GATEWAY_QUALITY",
			    -id=>"GATEWAY_QUALITY",
			    -value=>$post->param("GATEWAY_QUALITY")});
	print $post->input({-type=>"hidden",-name=>"USE_SYNCHED_BANNERS",
			    -id=>"USE_SYNCHED_BANNERS",
			    -value=>$post->param("USE_SYNCHED_BANNERS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_SECTION_IMAGE",
			    -id=>"BUTTON_SECTION_IMAGE",
			    -value=>$post->param("BUTTON_SECTION_IMAGE")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_COLUMNS",
			    -id=>"BUTTON_COLUMNS",
			    -value=>$post->param("BUTTON_COLUMNS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_ROWS",
			    -id=>"BUTTON_ROWS",
			    -value=>$post->param("BUTTON_ROWS")});
	print $post->input({-type=>"hidden",-name=>"HEAD_CODE",
			    -id=>"HEAD_CODE",
			    -value=>$post->param("HEAD_CODE")});
	print $post->input({-type=>"hidden",-name=>"TOP_BANNER_CODE",
			    -id=>"TOP_BANNER_CODE",
			    -value=>$post->param("TOP_BANNER_CODE")});
	print $post->input({-type=>"hidden",-name=>"SIDE_BANNER_CODE",
			    -id=>"SIDE_BANNER_CODE",
			    -value=>$post->param("SIDE_BANNER_CODE")});
	print $post->td({-align=>"left"},
			$post->input({-type=>"submit",-value=>"OK"}));
	print "</form>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_PLAYER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>@$row[9]});
	print $post->input({-type=>"hidden",-name=>"TITLE",-id=>"TITLE",
			    -value=>$post->param("TITLE")});
	print $post->input({-type=>"hidden",-name=>"SPLASH_LINK",
			    -id=>"SPLASH_LINK",
			    -value=>$post->param("SPLASH_LINK")});
	print $post->input({-type=>"hidden",-name=>"AUDIO_LOGO_LINK",
			    -id=>"AUDIO_LOGO_LINK",
			    -value=>$post->param("AUDIO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"VIDEO_LOGO_LINK",
			    -id=>"VIDEO_LOGO_LINK",
			    -value=>$post->param("VIDEO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"OPTIONAL_LINK_CODE",
			    -id=>"OPTIONAL_LINK_CODE",
			    -value=>$post->param("OPTIONAL_LINK_CODE")});
	print $post->input({-type=>"hidden",-name=>"DEFAULT_LINK",
			    -id=>"DEFAULT_LINK",
			    -value=>$post->param("DEFAULT_LINK")});
	print $post->input({-type=>"hidden",-name=>"SID",
			    -id=>"SID",
			    -value=>$post->param("SID")});
	print $post->input({-type=>"hidden",-name=>"GATEWAY_QUALITY",
			    -id=>"GATEWAY_QUALITY",
			    -value=>$post->param("GATEWAY_QUALITY")});
	print $post->input({-type=>"hidden",-name=>"USE_SYNCHED_BANNERS",
			    -id=>"USE_SYNCHED_BANNERS",
			    -value=>$post->param("USE_SYNCHED_BANNERS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_SECTION_IMAGE",
			    -id=>"BUTTON_SECTION_IMAGE",
			    -value=>$post->param("BUTTON_SECTION_IMAGE")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_COLUMNS",
			    -id=>"BUTTON_COLUMNS",
			    -value=>$post->param("BUTTON_COLUMNS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_ROWS",
			    -id=>"BUTTON_ROWS",
			    -value=>$post->param("BUTTON_ROWS")});
	print $post->input({-type=>"hidden",-name=>"HEAD_CODE",
			    -id=>"HEAD_CODE",
			    -value=>$post->param("HEAD_CODE")});
	print $post->input({-type=>"hidden",-name=>"TOP_BANNER_CODE",
			    -id=>"TOP_BANNER_CODE",
			    -value=>$post->param("TOP_BANNER_CODE")});
	print $post->input({-type=>"hidden",-name=>"SIDE_BANNER_CODE",
			    -id=>"SIDE_BANNER_CODE",
			    -value=>$post->param("SIDE_BANNER_CODE")});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";

    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitEditLivesegment {
    my $segment_id=$post->param("SEGMENT_ID");
    my $sun="N";
    if($post->param("SUN")) {
	$sun="Y";
    }
    my $mon="N";
    if($post->param("MON")) {
	$mon="Y";
    }
    my $tue="N";
    if($post->param("TUE")) {
	$tue="Y";
    }
    my $wed="N";
    if($post->param("WED")) {
	$wed="Y";
    }
    my $thu="N";
    if($post->param("THU")) {
	$thu="Y";
    }
    my $fri="N";
    if($post->param("FRI")) {
	$fri="Y";
    }
    my $sat="N";
    if($post->param("SAT")) {
	$sat="Y";
    }
    my $sql=sprintf "update LIVE_SEGMENTS set \
                     START_HOUR=%d,\
                     RUN_LENGTH=%d,\
                     LIVE_LINK=\"%s\",
                     LOGO_LINK=\"%s\",
                     SID=%d,\
                     SUN=\"%s\",\
                     MON=\"%s\",\
                     TUE=\"%s\",\
                     WED=\"%s\",\
                     THU=\"%s\",\
                     FRI=\"%s\",\
                     SAT=\"%s\" \
                     where ID=%d",
		     $post->param("START_HOUR"),
		     $post->param("RUN_LENGTH")*3600,
		     &EscapeString($post->param("LIVE_LINK")),
		     &EscapeString($post->param("LOGO_LINK")),
                     $post->param("SEGMENT_SID"),
		     $sun,
		     $mon,
		     $tue,
		     $wed,
		     $thu,
		     $fri,
		     $sat,
		     $segment_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub CommitDeleteLivesegment {
    my $segment_id=$post->param("SEGMENT_ID");
    my $sql=sprintf "delete from LIVE_SEGMENTS where ID=%d",$segment_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeListButtons {
    my $player_name=$post->param("PLAYER_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Channel Buttons");
    print "</head>\n";

    print "<body>\n";
    print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"0\">\n";

    #
    # Page Title
    #
    print "<tr>\n";
    print $post->td({-colspan=>11,-align=>"center"},
		     "<big><big>Channel Buttons</big></big>");
    print "</tr>\n";
    print "<tr>\n";
    printf "<td colspan=\"4\" align=\"center\"><big>Player \"%s\"</big></td>\n",$player_name;
    print "</tr>\n";

    print "<tr><td colspan=\"4\">&nbsp;</td></tr>\n";

    print "<tr><td>&nbsp;</td><td align=\"center\">IDLE</td>\n";
    print "<td align=\"center\">ACTIVE</td><td>&nbsp;</td></tr>\n";

    #
    # Button Table
    #
    my $bgcolor=BGCOLOR1;
    $sql=sprintf "select BUTTON_NUMBER,IMAGE_LINK,ACTIVE_IMAGE_LINK \
                  from CHANNEL_BUTTONS \
                  where PLAYER_NAME=\"%s\" order by BUTTON_NUMBER",
	&EscapeString($player_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    my $button_num=1;
    while(my $row=$q->fetchrow_arrayref) {
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"center",-valign=>"top"},"Button ".(@$row[0]+1));
	if(@$row[1] eq "") {
	    print $post->td({-align=>"center"},"[none]");
	}
	else {
	    print $post->td({-align=>"center"},"<img src=\"".@$row[1]."\">");
	}
	if(@$row[2] eq "") {
	    print $post->td({-align=>"center"},"[none]");
	}
	else {
	    print $post->td({-align=>"center"},"<img src=\"".@$row[2]."\">");
	}
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_BUTTON});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>$player_name});
	print $post->input({-type=>"hidden",-name=>BUTTON_NUMBER,
			    -value=>@$row[0]});
	print $post->input({-type=>"hidden",-name=>"TITLE",-id=>"TITLE",
			    -value=>$post->param("TITLE")});
	print $post->input({-type=>"hidden",-name=>"SPLASH_LINK",
			    -id=>"SPLASH_LINK",
			    -value=>$post->param("SPLASH_LINK")});
	print $post->input({-type=>"hidden",-name=>"AUDIO_LOGO_LINK",
			    -id=>"AUDIO_LOGO_LINK",
			    -value=>$post->param("AUDIO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"VIDEO_LOGO_LINK",
			    -id=>"VIDEO_LOGO_LINK",
			    -value=>$post->param("VIDEO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"OPTIONAL_LINK_CODE",
			    -id=>"OPTIONAL_LINK_CODE",
			    -value=>$post->param("OPTIONAL_LINK_CODE")});
	print $post->input({-type=>"hidden",-name=>"DEFAULT_LINK",
			    -id=>"DEFAULT_LINK",
			    -value=>$post->param("DEFAULT_LINK")});
	print $post->input({-type=>"hidden",-name=>"SID",
			    -id=>"SID",
			    -value=>$post->param("SID")});
	print $post->input({-type=>"hidden",-name=>"GATEWAY_QUALITY",
			    -id=>"GATEWAY_QUALITY",
			    -value=>$post->param("GATEWAY_QUALITY")});
	print $post->input({-type=>"hidden",-name=>"USE_SYNCHED_BANNERS",
			    -id=>"USE_SYNCHED_BANNERS",
			    -value=>$post->param("USE_SYNCHED_BANNERS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_SECTION_IMAGE",
			    -id=>"BUTTON_SECTION_IMAGE",
			    -value=>$post->param("BUTTON_SECTION_IMAGE")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_COLUMNS",
			    -id=>"BUTTON_COLUMNS",
			    -value=>$post->param("BUTTON_COLUMNS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_ROWS",
			    -id=>"BUTTON_ROWS",
			    -value=>$post->param("BUTTON_ROWS")});
	print $post->input({-type=>"hidden",-name=>"HEAD_CODE",
			    -id=>"HEAD_CODE",
			    -value=>$post->param("HEAD_CODE")});
	print $post->input({-type=>"hidden",-name=>"TOP_BANNER_CODE",
			    -id=>"TOP_BANNER_CODE",
			    -value=>$post->param("TOP_BANNER_CODE")});
	print $post->input({-type=>"hidden",-name=>"SIDE_BANNER_CODE",
			    -id=>"SIDE_BANNER_CODE",
			    -value=>$post->param("SIDE_BANNER_CODE")});
	print $post->input({-type=>"submit",-value=>Edit});
	print "</td>\n";
	print "</form>\n";
	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";

    print $post->td({-colspan=>2},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td colspan=\"9\" align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_EDIT_PLAYER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			-value=>$player_name});


    print $post->input({-type=>"hidden",-name=>"TITLE",-id=>"TITLE",
			-value=>$post->param("TITLE")});
    print $post->input({-type=>"hidden",-name=>"SPLASH_LINK",
			-id=>"SPLASH_LINK",
			-value=>$post->param("SPLASH_LINK")});
    print $post->input({-type=>"hidden",-name=>"AUDIO_LOGO_LINK",
			-id=>"AUDIO_LOGO_LINK",
			-value=>$post->param("AUDIO_LOGO_LINK")});
    print $post->input({-type=>"hidden",-name=>"VIDEO_LOGO_LINK",
			-id=>"VIDEO_LOGO_LINK",
			-value=>$post->param("VIDEO_LOGO_LINK")});
    print $post->input({-type=>"hidden",-name=>"OPTIONAL_LINK_CODE",
			-id=>"OPTIONAL_LINK_CODE",
			-value=>$post->param("OPTIONAL_LINK_CODE")});
    print $post->input({-type=>"hidden",-name=>"DEFAULT_LINK",
			-id=>"DEFAULT_LINK",
			-value=>$post->param("DEFAULT_LINK")});
    print $post->input({-type=>"hidden",-name=>"SID",
			-id=>"SID",
			-value=>$post->param("SID")});
    print $post->input({-type=>"hidden",-name=>"GATEWAY_QUALITY",
			-id=>"GATEWAY_QUALITY",
			-value=>$post->param("GATEWAY_QUALITY")});
    print $post->input({-type=>"hidden",-name=>"USE_SYNCHED_BANNERS",
			-id=>"USE_SYNCHED_BANNERS",
			-value=>$post->param("USE_SYNCHED_BANNERS")});
    print $post->input({-type=>"hidden",-name=>"BUTTON_SECTION_IMAGE",
			-id=>"BUTTON_SECTION_IMAGE",
			-value=>$post->param("BUTTON_SECTION_IMAGE")});
    print $post->input({-type=>"hidden",-name=>"BUTTON_COLUMNS",
			-id=>"BUTTON_COLUMNS",
			-value=>$post->param("BUTTON_COLUMNS")});
    print $post->input({-type=>"hidden",-name=>"BUTTON_ROWS",
			-id=>"BUTTON_ROWS",
			-value=>$post->param("BUTTON_ROWS")});
    print $post->input({-type=>"hidden",-name=>"HEAD_CODE",
			-id=>"HEAD_CODE",
			-value=>$post->param("HEAD_CODE")});
    print $post->input({-type=>"hidden",-name=>"TOP_BANNER_CODE",
			-id=>"TOP_BANNER_CODE",
			-value=>$post->param("TOP_BANNER_CODE")});
    print $post->input({-type=>"hidden",-name=>"SIDE_BANNER_CODE",
			-id=>"SIDE_BANNER_CODE",
			-value=>$post->param("SIDE_BANNER_CODE")});


    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub ServeEditButton {
    my $player_name=$post->param("PLAYER_NAME");
    my $button_number=$post->param("BUTTON_NUMBER");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Button");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select IMAGE_LINK,ACTIVE_IMAGE_LINK,CLICK_LINK,SID,MODE \
                     from CHANNEL_BUTTONS \
                     where (PLAYER_NAME=\"%s\")&&(BUTTON_NUMBER=%d)",
	&EscapeString($player_name),$button_number;
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>3,-align=>"center"},
			"<big><big>Edit Channel Button</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_BUTTON});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>$player_name});
	print $post->input({-type=>"hidden",-name=>BUTTON_NUMBER,
			    -value=>$button_number});

	#
	# Idle Image Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#image_url\" target=\"docs\">Image URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>80,-maxlength=>255,
				      -name=>IMAGE_LINK,-value=>@$row[0]}));
	print "</tr>\n";

	#
	# Active Image Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#active_image_url\" target=\"docs\">Active Image URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>80,-maxlength=>255,
				      -name=>ACTIVE_IMAGE_LINK,-value=>@$row[1]}));
	print "</tr>\n";

	#
	# Click Through Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#clickthrough_url\" target=\"docs\">Click-Through URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>80,-maxlength=>255,
				      -name=>CLICK_LINK,-value=>@$row[2]}));
	print "</tr>\n";

	#
	# SID
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#button_sid\" target=\"docs\">Ando Station ID:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>5,-maxlength=>5,
				      -name=>SID,-value=>@$row[3]}));
	print "</tr>\n";

	#
	# Mode
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#button_mode\" target=\"docs\">Button Mode:</a></strong>");
       	print "<td colspan=\"2\" align=\"left\">\n";
      	print "<select id=\"MODE\" name=\"MODE\">\n";
        if(@$row[4]==BUTTON_MODE_LIVEFEED) {
	    print $post->option({-value=>BUTTON_MODE_LIVEFEED,-selected},"Live Feed");
	    print $post->option({-value=>BUTTON_MODE_ONDEMAND},"OnDemand Channel");
	}
#        if(@$row[3]==BUTTON_MODE_ONDEMAND) {
        if(@$row[4]==BUTTON_MODE_ONDEMAND) {
	    print $post->option({-value=>BUTTON_MODE_LIVEFEED},"Live Feed");
	    print $post->option({-value=>BUTTON_MODE_ONDEMAND,-selected},"OnDemand Channel");
	}
	print "</select>\n";
	print "</td>\n";
	print "</tr>\n";

	#
	# OK Button
	#
	print "<tr>\n";
	print $post->input({-type=>"hidden",-name=>"TITLE",-id=>"TITLE",
			    -value=>$post->param("TITLE")});
	print $post->input({-type=>"hidden",-name=>"SPLASH_LINK",
			    -id=>"SPLASH_LINK",
			    -value=>$post->param("SPLASH_LINK")});
	print $post->input({-type=>"hidden",-name=>"AUDIO_LOGO_LINK",
			    -id=>"AUDIO_LOGO_LINK",
			    -value=>$post->param("AUDIO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"VIDEO_LOGO_LINK",
			    -id=>"VIDEO_LOGO_LINK",
			    -value=>$post->param("VIDEO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"OPTIONAL_LINK_CODE",
			    -id=>"OPTIONAL_LINK_CODE",
			    -value=>$post->param("OPTIONAL_LINK_CODE")});
	print $post->input({-type=>"hidden",-name=>"DEFAULT_LINK",
			    -id=>"DEFAULT_LINK",
			    -value=>$post->param("DEFAULT_LINK")});
	print $post->input({-type=>"hidden",-name=>"SID",
			    -id=>"SID",
			    -value=>$post->param("SID")});
	print $post->input({-type=>"hidden",-name=>"GATEWAY_QUALITY",
			    -id=>"GATEWAY_QUALITY",
			    -value=>$post->param("GATEWAY_QUALITY")});
	print $post->input({-type=>"hidden",-name=>"USE_SYNCHED_BANNERS",
			    -id=>"USE_SYNCHED_BANNERS",
			    -value=>$post->param("USE_SYNCHED_BANNERS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_SECTION_IMAGE",
			    -id=>"BUTTON_SECTION_IMAGE",
			    -value=>$post->param("BUTTON_SECTION_IMAGE")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_COLUMNS",
			    -id=>"BUTTON_COLUMNS",
			    -value=>$post->param("BUTTON_COLUMNS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_ROWS",
			    -id=>"BUTTON_ROWS",
			    -value=>$post->param("BUTTON_ROWS")});
	print $post->input({-type=>"hidden",-name=>"HEAD_CODE",
			    -id=>"HEAD_CODE",
			    -value=>$post->param("HEAD_CODE")});
	print $post->input({-type=>"hidden",-name=>"TOP_BANNER_CODE",
			    -id=>"TOP_BANNER_CODE",
			    -value=>$post->param("TOP_BANNER_CODE")});
	print $post->input({-type=>"hidden",-name=>"SIDE_BANNER_CODE",
			    -id=>"SIDE_BANNER_CODE",
			    -value=>$post->param("SIDE_BANNER_CODE")});
	print $post->td({-align=>"left"},
			$post->input({-type=>"submit",-value=>"OK"}));
	print "</form>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_BUTTONS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>PLAYER_NAME,
			    -value=>$player_name});
	print $post->input({-type=>"hidden",-name=>"TITLE",-id=>"TITLE",
			    -value=>$post->param("TITLE")});
	print $post->input({-type=>"hidden",-name=>"SPLASH_LINK",
			    -id=>"SPLASH_LINK",
			    -value=>$post->param("SPLASH_LINK")});
	print $post->input({-type=>"hidden",-name=>"AUDIO_LOGO_LINK",
			    -id=>"AUDIO_LOGO_LINK",
			    -value=>$post->param("AUDIO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"VIDEO_LOGO_LINK",
			    -id=>"VIDEO_LOGO_LINK",
			    -value=>$post->param("VIDEO_LOGO_LINK")});
	print $post->input({-type=>"hidden",-name=>"OPTIONAL_LINK_CODE",
			    -id=>"OPTIONAL_LINK_CODE",
			    -value=>$post->param("OPTIONAL_LINK_CODE")});
	print $post->input({-type=>"hidden",-name=>"DEFAULT_LINK",
			    -id=>"DEFAULT_LINK",
			    -value=>$post->param("DEFAULT_LINK")});
	print $post->input({-type=>"hidden",-name=>"SID",
			    -id=>"SID",
			    -value=>$post->param("SID")});
	print $post->input({-type=>"hidden",-name=>"GATEWAY_QUALITY",
			    -id=>"GATEWAY_QUALITY",
			    -value=>$post->param("GATEWAY_QUALITY")});
	print $post->input({-type=>"hidden",-name=>"USE_SYNCHED_BANNERS",
			    -id=>"USE_SYNCHED_BANNERS",
			    -value=>$post->param("USE_SYNCHED_BANNERS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_SECTION_IMAGE",
			    -id=>"BUTTON_SECTION_IMAGE",
			    -value=>$post->param("BUTTON_SECTION_IMAGE")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_COLUMNS",
			    -id=>"BUTTON_COLUMNS",
			    -value=>$post->param("BUTTON_COLUMNS")});
	print $post->input({-type=>"hidden",-name=>"BUTTON_ROWS",
			    -id=>"BUTTON_ROWS",
			    -value=>$post->param("BUTTON_ROWS")});
	print $post->input({-type=>"hidden",-name=>"HEAD_CODE",
			    -id=>"HEAD_CODE",
			    -value=>$post->param("HEAD_CODE")});
	print $post->input({-type=>"hidden",-name=>"TOP_BANNER_CODE",
			    -id=>"TOP_BANNER_CODE",
			    -value=>$post->param("TOP_BANNER_CODE")});
	print $post->input({-type=>"hidden",-name=>"SIDE_BANNER_CODE",
			    -id=>"SIDE_BANNER_CODE",
			    -value=>$post->param("SIDE_BANNER_CODE")});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";

    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitEditButton {
    my $player_name=$post->param("PLAYER_NAME");
    my $button_number=$post->param("BUTTON_NUMBER");
    my $sid=$post->param('SID');
    my $mode=$post->param('MODE');
    my $sql=sprintf "update CHANNEL_BUTTONS set \
                     IMAGE_LINK=\"%s\",\
                     ACTIVE_IMAGE_LINK=\"%s\",\
                     CLICK_LINK=\"%s\",\
                     SID=%d,\
                     MODE=%d \
                     where (PLAYER_NAME=\"%s\")&&(BUTTON_NUMBER=%d)",
		     &EscapeString($post->param("IMAGE_LINK")),
		     &EscapeString($post->param("ACTIVE_IMAGE_LINK")),
		     &EscapeString($post->param("CLICK_LINK")),
		     $sid,
		     $mode,
		     &EscapeString($player_name),
		     $button_number;
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeListChannels {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Channel List");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select NAME,TITLE,DESCRIPTION from CHANNELS order by NAME";
    my $q=$dbh->prepare($sql);
    $q->execute();

    print "<tr>\n";
    print $post->td({-colspan=>6,-align=>"center"},
		    "<big><big>Loudwater Channel List</big></big>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->th({-align=>"center"},"Name");
    print $post->th({-align=>"center"},"Title");
    print $post->th({-align=>"center"},"Description");
    print $post->th({-align=>"center"},"&nbsp;");
    print $post->th({-align=>"center"},"&nbsp;");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    while(my $row=$q->fetchrow_arrayref) {
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"left"},@$row[0]);
	if(@$row[1] eq "") {
	    print $post->td("&nbsp;");
	}
	else {
	    print $post->td({-align=>"left"},@$row[1]);
	}
	if(@$row[2] eq "") {
	    print $post->td("&nbsp;");
	}
	else {
	    print $post->td({-align=>"left"},@$row[2]);
	}
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_CHANNEL});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Edit});
	print "</td>\n";
	print "</form>\n";
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_DELETE_CHANNEL});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Delete});
	print "</td>\n";
	print "</form>\n";

	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_ADD_CHANNEL});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Add Channel"});
    print "</td>\n";
    print "</form>\n";

    print $post->td({-colspan=>3},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_MAIN_MENU});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub ServeAddChannel {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Add Channel");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Add Channel</big></big>");
    print "</tr>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_ADD_CHANNEL});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print "<tr>\n";
    print $post->td({-bgcolor=>BGCOLOR1,-align=>"right"},"<strong><a href=\"admin-doc.html#new_channel_name\" target=\"docs\">Channel Name:</a></strong>");
    print $post->td({-bgcolor=>BGCOLOR1,-align=>"left"},
		    $post->input({-type=>"text",-size=>10,-maxlength=>8,
				  -name=>CHANNEL_NAME}));
    print "</tr>\n";

    #
    # OK Button
    #
    print "<tr>\n";
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"OK"}));
    print "</form>\n";

    #
    # Cancel Button
    #
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_CHANNELS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Cancel"}));
    print "</form>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitAddChannel {
    my $channel_name=$post->param("CHANNEL_NAME");
    my $sql=sprintf "insert into CHANNELS set NAME=\"%s\"",
                     &EscapeString($channel_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeEditChannel {
    my $channel_name=$post->param("CHANNEL_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Channel Configuration");
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print "</head>\n";
    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    
    my $sql=sprintf "select CHANNELS.TITLE,CHANNELS.DESCRIPTION,\
                     CHANNELS.CATEGORY,CHANNELS.LINK,CHANNELS.COPYRIGHT,\
                     CHANNELS.WEBMASTER,CHANNELS.AUTHOR,CHANNELS.OWNER,\
                     CHANNELS.OWNER_EMAIL,CHANNELS.SUBTITLE,\
                     CHANNELS.CATEGORY_ITUNES,CHANNELS.KEYWORDS,\
                     CHANNELS.EXPLICIT,CHANNELS.LANGUAGE,\
                     CHANNELS.MAX_UPLOAD_SIZE,CHANNELS.THUMBNAIL_UPLOAD_URL,\
                     CHANNELS.THUMBNAIL_UPLOAD_USERNAME,\
                     CHANNELS.THUMBNAIL_UPLOAD_PASSWORD,\
                     CHANNELS.THUMBNAIL_DOWNLOAD_URL,CHANNELS.THUMBNAIL_ID,\
                     THUMBNAILS.FILENAME from THUMBNAILS right join CHANNELS \
                     on CHANNELS.THUMBNAIL_ID=THUMBNAILS.ID \
                     where (CHANNELS.NAME=\"%s\")",
		     &EscapeString($channel_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>3,-align=>"center"},
			"<big><big>Edit Channel Configuration</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_CHANNEL});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>$channel_name});

	#
	# Channel Name
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_name\" target=\"docs\">Channel Name:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},$channel_name);
	print "</tr>\n";

	#
	# Channel Title
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_title\" target=\"docs\">Title:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"TITLE",
				      -id=>"TITLE",
	       -value=>&GetLocalValue($post,"TITLE",@$row[0])}));
	print "</tr>\n";

	#
	# Channel Description
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_description\" target=\"docs\">Description:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"DESCRIPTION",
				      -id=>"DESCRIPTION",
	       -value=>&GetLocalValue($post,"DESCRIPTION",@$row[1])}));
	print "</tr>\n";

	#
	# Channel Category
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_category\" target=\"docs\">Category:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"CATEGORY",
				      -id=>"CATEGORY",
	       -value=>&GetLocalValue($post,"CATEGORY",@$row[2])}));
	print "</tr>\n";

	#
	# Channel Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_link\" target=\"docs\">Link:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"LINK",
				      -id=>"LINK",
	       -value=>&GetLocalValue($post,"LINK",@$row[3])}));
	print "</tr>\n";

	#
	# Channel Copyright
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_copyright\" target=\"docs\">Copyright:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"COPYRIGHT",
				      -name=>"COPYRIGHT",
	       -value=>&GetLocalValue($post,"COPYRIGHT",@$row[4])}));
	print "</tr>\n";

	#
	# Channel Webmaster
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_webmaster\" target=\"docs\">Webmaster:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"WEBMASTER",
				      -name=>"WEBMASTER",
	       -value=>&GetLocalValue($post,"WEBMASTER",@$row[5])}));
	print "</tr>\n";

	#
	# Channel Author
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_author\" target=\"docs\">Author:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"AUTHOR",
				      -name=>"AUTHOR",
	       -value=>&GetLocalValue($post,"AUTHOR",@$row[6])}));
	print "</tr>\n";

	#
	# Channel Owner
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_owner\" target=\"docs\">Owner:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"OWNER",
				      -name=>"OWNER",
	       -value=>&GetLocalValue($post,"OWNER",@$row[7])}));
	print "</tr>\n";

	#
	# Channel Owner Email
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_owner_email\" target=\"docs\">Owner_Email:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"OWNER_EMAIL",
				      -name=>"OWNER_EMAIL",
	       -value=>&GetLocalValue($post,"OWNER_EMAIL",@$row[8])}));
	print "</tr>\n";

	#
	# Channel Subtitle
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_subtitle\" target=\"docs\">Subtitle:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"SUBTITLE",
				      -name=>"SUBTITLE",
	       -value=>&GetLocalValue($post,"SUBTITLE",@$row[9])}));
	print "</tr>\n";

	#
	# Channel Itunes Category
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_category_itunes\" target=\"docs\">iTunes Category:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"CATEGORY_ITUNES",
				      -name=>"CATEGORY_ITUNES",
	       -value=>&GetLocalValue($post,"CATEGORY_ITUNES",@$row[10])}));
	print "</tr>\n";

	#
	# Channel Keywords
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_keywords\" target=\"docs\">Keywords:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -id=>"KEYWORDS",
				      -name=>"KEYWORDS",
	       -value=>&GetLocalValue($post,"KEYWORDS",@$row[11])}));
	print "</tr>\n";

	#
	# Explicit Tag
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_explicit\" target=\"docs\">Explicit Tag:</a></strong>");
	print "<td colspan=\"3\">\n";
	print "<select id=\"EXPLICIT\" name=\"EXPLICIT\">\n";
	if(&GetLocalValue($post,"EXPLICIT",@$row[12]) eq "Y") {
	    print $post->option({-value=>"Y",-selected},"Yes");
	    print $post->option({-value=>"N"},"No");
	    print $post->option({-value=>"C"},"Clean");
	}
	else {
	    if(&GetLocalValue($post,"EXPLICIT",@$row[12]) eq "C") {
		print $post->option({-value=>"Y"},"Yes");
		print $post->option({-value=>"N"},"No");
		print $post->option({-value=>"C",-selected},"Clean");
	    }
	    else {
		print $post->option({-value=>"Y"},"Yes");
		print $post->option({-value=>"N",-selected},"No");
		print $post->option({-value=>"C"},"Clean");
	    }
	}
	print "</select>\n";
	print "</td>\n";
	print "</tr>\n";

	#
	# Channel Language
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_language\" target=\"docs\">Language:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>4,-maxlength=>5,-type=>"text",
				      -id=>"LANGUAGE",
				      -name=>"LANGUAGE",
	       -value=>&GetLocalValue($post,"LANGUAGE",@$row[13])}));
	print "</tr>\n";

	#
	# Channel Max Upload Size
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#channel_max_upload_size\" target=\"docs\">Maximum Upload Size:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>4,-maxlength=>4,-type=>"text",
				      -id=>MAX_UPLOAD_SIZE,
				      -name=>MAX_UPLOAD_SIZE,
	    -value=>&GetLocalValue($post,"MAX_UPLOAD_SIZE",@$row[14])/1000000}).
				     " MB");
	print "</tr>\n";

	#
	# Thumbnail Upload URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#thumbnail_upload_url\" target=\"docs\">Thumbnail Upload URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"THUMBNAIL_UPLOAD_URL",
              -value=>&GetLocalValue($post,"THUMBNAIL_UPLOAD_URL",@$row[15])}));
	print "</tr>\n";

	#
	# Thumbnail Upload Username
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#thumbnail_upload_username\" target=\"docs\">Thumbnail Upload Username:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>20,-maxlength=>64,-type=>"text",
				      -name=>"THUMBNAIL_UPLOAD_USERNAME",
         -value=>&GetLocalValue($post,"THUMBNAIL_UPLOAD_USERNAME",@$row[16])}));
	print "</tr>\n";

	#
	# Thumbnail Upload Password
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#thumbnail_upload_password\" target=\"docs\">Thumbnail Upload Password:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>20,-maxlength=>64,-type=>"password",
				      -name=>"THUMBNAIL_UPLOAD_PASSWORD",
         -value=>&GetLocalValue($post,"THUMBNAIL_UPLOAD_PASSWORD",@$row[17])}));
	print "</tr>\n";

	#
	# Thumbnail Download URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#thumbnail_download_url\" target=\"docs\">Thumbnail Download URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"THUMBNAIL_DOWNLOAD_URL",
         -value=>&GetLocalValue($post,"THUMBNAIL_DOWNLOAD_URL",@$row[18])}));
	print "</tr>\n";

	#
	# Default Thumbnail
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#channel_default_thumbnail\" target=\"docs\">Default Thumbnail:</a></strong>");
	if(@$row[19]==0) {
	    print $post->td({-colspan=>2,-align=>"left"},
			    $post->input({-type=>"button",
					  -value=>"Choose Thumbnail",
		       -onclick=>sprintf "setDefaultThumbnail(%u,\'%s\',%u)",
			    $session_id,$channel_name,@$row[19]}));
	}
	else {
	    print $post->td({-colspan=>2,-align=>"left",
		       -onclick=>sprintf "setDefaultThumbnail(%u,\'%s\',%u)",
			    $session_id,$channel_name,@$row[19]},
			    $post->img({-border=>0,
					-src=>@$row[18]."/".@$row[20]}));
	}
	print "</tr>\n";

	#
	# Channel Taps
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#channel_taps\" target=\"docs\">Channel Taps:</a></strong>");
	print "<td colspan=\"2\" align=\"left\">\n";
	print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"1\">\n";
	print "<tr bgcolor=\"".BGCOLOR2."\">\n";
	print "<th>Id</th>\n";
	print "<th>Title</th>\n";
	print $post->th({-colspan=>2,-align=>"center"},
		$post->input({-type=>"button",-value=>"Add New Tap",
			      -onclick=>sprintf "addTap(%d,\'%s\')",
			      $session_id,$channel_name}));
	print "</tr>\n";

	$sql=sprintf "select ID,TITLE,DELETING from TAPS \
                      where CHANNEL_NAME=\"%s\"",
	              &EscapeString($channel_name);
	my $q1=$dbh->prepare($sql);
	$q1->execute();
	while(my $row1=$q1->fetchrow_arrayref) {
	    print "<tr bgcolor=\"#FFFFFF\">\n";
	    print $post->td({-align=>"right"},@$row1[0]);
	    if(@$row1[1] eq "") {
		print $post->td({-align=>"left"},"&nbsp;");
	    }
	    else {
		print $post->td({-align=>"left"},@$row1[1]);
	    }
	    if(@$row1[2] eq "Y") {
		print $post->td({-colspan=>"2",-align=>"center"},
		    $post->input({-type=>"button",-value=>"Show Delete Jobs",
				 -onclick=>"showDeleteJobs(".$session_id.",\'".
				 $channel_name."\',".@$row1[0].")"}));
	    }
	    else {
		print $post->td({-align=>"center"},
		     $post->input({-type=>"button",-value=>"Edit",
       		      -onclick=>sprintf "editTap(%d,%d)",$session_id,
					      @$row1[0]}));
		print $post->td({-align=>"cemter"},
		     $post->input({-type=>"button",-value=>"Delete",
       		      -onclick=>sprintf "deleteTap(%d,\'%s\',%d)",
			       	      $session_id,$channel_name,@$row1[0]}));
	    }
	    print "</tr>\n";
	}
	print "</table>\n";
	print "</td>\n";
	print "</tr>\n";

	#
	# OK Button
	#
	print "<tr>\n";
	print $post->td({-align=>"left"},
			$post->input({-type=>"submit",-value=>"OK"}));
	print "</form>\n";

	#
	# Manage Thumbnails Button
	#
	print "<td align=\"left\">\n";
	print $post->input({-type=>"button",-value=>"Manage Thumbnails",
		       -onclick=>sprintf "setDefaultThumbnail(%u,\'%s\',%u)",
			    $session_id,$channel_name,@$row[19]});
	print "</td>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_CHANNELS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";
    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitEditChannel {
    my $channel_name=$post->param("CHANNEL_NAME");
    my $sql=sprintf "update CHANNELS set \
                     TITLE=\"%s\",\
                     DESCRIPTION=\"%s\",\
                     CATEGORY=\"%s\",\
                     LINK=\"%s\",\
                     COPYRIGHT=\"%s\",\
                     WEBMASTER=\"%s\",\
                     AUTHOR=\"%s\",\
                     OWNER=\"%s\",\
                     OWNER_EMAIL=\"%s\",\
                     SUBTITLE=\"%s\",\
                     CATEGORY_ITUNES=\"%s\",\
                     KEYWORDS=\"%s\",\
                     EXPLICIT=\"%s\",\
                     LANGUAGE=\"%s\",\
                     MAX_UPLOAD_SIZE=%d,\
                     THUMBNAIL_UPLOAD_URL=\"%s\",\
                     THUMBNAIL_UPLOAD_USERNAME=\"%s\",\
                     THUMBNAIL_UPLOAD_PASSWORD=\"%s\",\
                     THUMBNAIL_DOWNLOAD_URL=\"%s\" \
                     where NAME=\"%s\"",
		     &EscapeString($post->param("TITLE")),
		     &EscapeString($post->param("DESCRIPTION")),
		     &EscapeString($post->param("CATEGORY")),
		     &EscapeString($post->param("LINK")),
		     &EscapeString($post->param("COPYRIGHT")),
		     &EscapeString($post->param("WEBMASTER")),
		     &EscapeString($post->param("AUTHOR")),
		     &EscapeString($post->param("OWNER")),
		     &EscapeString($post->param("OWNER_EMAIL")),
		     &EscapeString($post->param("SUBTITLE")),
		     &EscapeString($post->param("CATEGORY_ITUNES")),
		     &EscapeString($post->param("KEYWORDS")),
		     &EscapeString($post->param("EXPLICIT")),
		     &EscapeString($post->param("LANGUAGE")),
		     1000000*$post->param("MAX_UPLOAD_SIZE"),
		     &EscapeString($post->param("THUMBNAIL_UPLOAD_URL")),
		     &EscapeString($post->param("THUMBNAIL_UPLOAD_USERNAME")),
		     &EscapeString($post->param("THUMBNAIL_UPLOAD_PASSWORD")),
		     &EscapeString($post->param("THUMBNAIL_DOWNLOAD_URL")),
		     &EscapeString($channel_name);
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeDeleteChannel {
    my $channel_name=$post->param("CHANNEL_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Delete Channel");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Are you sure that you want to delete this channel?");
    print "</tr>\n";

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_DELETE_CHANNEL});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"Yes"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_CHANNELS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"No"}));
    print "</form>\n";

    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitDeleteChannel {
    my $channel_name=$post->param("CHANNEL_NAME");
    my $sql=sprintf "delete from CHANNELS where NAME=\"%s\"",
                     &EscapeString($channel_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeListContentChannels {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Channel List");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";

    #
    # Get authorized channels
    #
    my $where;
    my $sql=sprintf "select CHANNEL_NAME from CHANNEL_PERMS \
                     where USER_NAME=\"%s\"",$auth_user_name;
    my $q=$dbh->prepare($sql);
    $q->execute();
    while(my $row=$q->fetchrow_arrayref) {
	$where=$where.sprintf "(NAME=\"%s\")||",&EscapeString(@$row[0]);
    }
    $q->finish();
    substr($where,-2)=~s/\|\|//g;

    #
    # Display list
    #
    $sql=sprintf "select NAME,TITLE,DESCRIPTION from CHANNELS \
                  where %s order by NAME",$where;
    $q=$dbh->prepare($sql);
    $q->execute();

    print "<tr>\n";
    print $post->td({-colspan=>7,-align=>"center"},
		    "<big><big>Loudwater Channel List</big></big>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->th({-align=>"center"},"Name");
    print $post->th({-align=>"center"},"Title");
    print $post->th({-align=>"center"},"Description");
    print $post->th({-align=>"center"},"&nbsp;");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    while(my $row=$q->fetchrow_arrayref) {
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"left"},@$row[0]);
	if(@$row[1] eq "") {
	    print $post->td("&nbsp;");
	}
	else {
	    print $post->td({-align=>"left"},@$row[1]);
	}
	if(@$row[2] eq "") {
	    print $post->td("&nbsp;");
	}
	else {
	    print $post->td({-align=>"left"},@$row[2]);
	}




	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_CHANNEL_LINKS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"hidden",-name=>CHANNEL_TITLE,
			    -value=>@$row[1]});
	print $post->input({-type=>"submit",-value=>"Links"});
	print "</td>\n";
	print "</form>\n";




	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_POSTS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>"View"});
	print "</td>\n";
	print "</form>\n";

	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print $post->td({-colspan=>4},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_MAIN_MENU});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub ServeListChannelLinks {
    $channel_name=$post->param("CHANNEL_NAME");
    $channel_title=$post->param("CHANNEL_TITLE");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print $post->title("Loudwater Channel Data");
    print "</head>\n";

    print "<body>\n";
    print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"0\">\n";

    #
    # Page Title
    #
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Tap Links for \"".$channel_name.
		    "\"</big></big>");
    print "</tr>\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big>".$channel_title."</big>");
    print "</tr>\n";

    #
    # Links
    #
    print "<tr>\n";
    print $post->th({-align=>"center"},"TAP");
    print $post->th({-align=>"center"},"LINK");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    $sql=sprintf "select ID,TITLE,VALIDATION_URL from TAPS \
                  where CHANNEL_NAME=\"%s\"",
         $channel_name;
    my $q1=$dbh->prepare($sql);
    $q1->execute();
    while(my $row1=$q1->fetchrow_arrayref) {
	print "<tr bgcolor=\"".$bgcolor."\">\n";
	print $post->td(@$row1[1]);
	print $post->td(&GetLoudwaterUrl."feed.pl?tap=".@$row1[0]);

	if(defined(@$row1[2])) {
	    print "<td>\n";
	    print "<input type=\"button\" value=\"Validate\" onclick=\"validateTap('".
		@$row1[2].&GetLoudwaterUrl."feed.pl?tap=".@$row1[0]."')\">\n";
	    print "</td>\n";
	}
	else {
	    print $post->td("&nbsp;");
	}
	print "</tr>\n";
	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q1->finish();

    #
    # Close Button
    #
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_CONTENT_CHANNELS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
#    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
#			-value=>$channel_name});
    print $post->td({-colspan=>3,-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Close"}));
    print "</form>\n";
    print "</tr>\n";
    print "</table>\n";
    print "</body>\n";
}


sub ServeListPosts {
    my $channel_name=$post->param("CHANNEL_NAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Posts");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr><td id=\"bigframe\">\n";

    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";

    #
    # Verify channel authorization
    #
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    #
    # Get channel parameters
    #
    $allow_multipart_posts=0;
    $sql=sprintf "select ALLOW_MULTIPART_POSTS from CHANNELS where NAME=\"%s\"",
         &EscapeString($channel_name);
    $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	if(@$row[0] eq "Y") {
	    $allow_multipart_posts=1;
	}
    }
    $q->finish();

    #
    # Display posts
    #
    $sql=sprintf "select POSTS.ID,POSTS.ACTIVE,POSTS.TITLE,\
                  POSTS.PROCESSING,POSTS.DELETING,POSTS.ORIGIN_DATETIME,\
                  USERS.FULL_NAME from POSTS left join USERS \
                  on POSTS.ORIGIN_USER_NAME=USERS.NAME \
                  where POSTS.CHANNEL_NAME=\"%s\" \
                  order by POSTS.ORIGIN_DATETIME desc",$channel_name;
    $q=$dbh->prepare($sql);
    $q->execute();

    print "<tr>\n";
    print $post->td({-colspan=>6,-align=>"center"},
		    "<big><big>Loudwater Posts</big></big>");
    print "</tr>\n";


    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\" enctype=\"multipart/form-data\">\n";
    print "<td colspan=\"2\" align=\"left\">\n";
    if($allow_multipart_posts) {
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_ADD_POST});
    }
    else {
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_UPLOAD_ADD_POST});
	print $post->input({-type=>"hidden",-name=>SEGMENT_QUANTITY,
			    -value=>"1"});
    }
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Add New Post"});
    print "</td>\n";
    print "</form>\n";

    print $post->td({-colspan=>5},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_CONTENT_CHANNELS});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";



    print "<tr>\n";
    print $post->th({-align=>"center"},"&nbsp;");
    print $post->th({-align=>"center"},"Title");
    print $post->th({-align=>"center"},"Job Status");
    print $post->th({-align=>"center"},"Posted On");
    print $post->th({-align=>"center"},"Posted By");
    print $post->th({-align=>"center"},"&nbsp;");
    print $post->th({-align=>"center"},"&nbsp;");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    while(my $row=$q->fetchrow_arrayref) {
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;

	if(@$row[1] eq "Y") {
	    print $post->td({aling=>"center"},
			    "<img border=\"0\" src=\"greenball.png\">");
	}
	else {
	    print $post->td({aling=>"center"},
			    "<img border=\"0\" src=\"redball.png\">");
	}
	print $post->td({-align=>"left"},@$row[2]);
	if((@$row[4] eq "Y")||(@$row[3] eq "Y")) {
	    print "<form action=\"admin.pl\" method=\"post\">\n";
	    print "<td align=\"center\">\n";
	    print $post->input({-type=>"hidden",-name=>COMMAND,
				-value=>COMMAND_VIEW_JOBS});
	    print $post->input({-type=>"hidden",-name=>SESSION_ID,
				-value=>$session_id});
	    print $post->input({-type=>"hidden",-name=>POST_ID,
				-value=>@$row[0]});
	    print $post->input({-type=>"submit",-value=>"View Jobs"});
	    print "</td>\n";
	    print "</form>\n";
	}
	else {
	    print $post->td({-align=>"center"},"Complete");
	}
	if(@$row[5] eq "") {
	    print $post->td("&nbsp;");
	}
	else {
	    print $post->td({-align=>"left"},@$row[5]);
	}
	if(@$row[6] eq "") {
	    print $post->td("&nbsp;");
	}
	else {
	    print $post->td({-align=>"left"},@$row[6]);
	}
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	if(@$row[4] eq "Y") {
	    print "&nbsp;\n"
	}
	else {
	    print $post->input({-type=>"hidden",-name=>COMMAND,
				-value=>COMMAND_EDIT_POST});
	    print $post->input({-type=>"hidden",-name=>SESSION_ID,
				-value=>$session_id});
	    print $post->input({-type=>"hidden",-name=>POST_ID,
				-value=>@$row[0]});
	    print $post->input({-type=>"submit",-value=>"Edit"});
	}
	print "</td>\n";
	print "</form>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	if(@$row[4] eq "Y") {
	    print "&nbsp;\n"
	}
	else {
	    print $post->input({-type=>"hidden",-name=>COMMAND,
				-value=>COMMAND_LIST_UPLOADS});
	    print $post->input({-type=>"hidden",-name=>SESSION_ID,
				-value=>$session_id});
	    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
				-value=>$channel_name});
	    print $post->input({-type=>"hidden",-name=>POST_ID,
				-value=>@$row[0]});
	    print $post->input({-type=>"hidden",-name=>POST_TITLE,
				-value=>@$row[2]});
	    print $post->input({-type=>"submit",-value=>"Links"});
	}
	print "</td>\n";
	print "</form>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	if(@$row[4] eq "Y") {
	    print "&nbsp;\n"
	}
	else {
	    print $post->input({-type=>"hidden",-name=>COMMAND,
				-value=>COMMAND_DELETE_POST});
	    print $post->input({-type=>"hidden",-name=>SESSION_ID,
				-value=>$session_id});
	    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
				-value=>$channel_name});
	    print $post->input({-type=>"hidden",-name=>POST_ID,
				-value=>@$row[0]});
	    print $post->input({-type=>"submit",-value=>"Delete"});
	}
	print "</td>\n";
	print "</form>\n";

	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\" enctype=\"multipart/form-data\">\n";
    print "<td colspan=\"2\" align=\"left\">\n";
    if($allow_multipart_posts) {
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_ADD_POST});
    }
    else {
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_UPLOAD_ADD_POST});
	print $post->input({-type=>"hidden",-name=>SEGMENT_QUANTITY,
			    -value=>"1"});
    }
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Add New Post"});
    print "</td>\n";
    print "</form>\n";

    print $post->td({-colspan=>5},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_CONTENT_CHANNELS});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";

    print "</table>\n";

    print "</td></tr>\n";
    print "</body>\n";
}


sub ServeAddPost {
    my $channel_name=$post->param("CHANNEL_NAME");

    #
    # Verify channel authorization
    #
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    #
    # Render form
    #
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Add Post");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Loudwater Add Post</big></big>");
    print "</tr>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_UPLOAD_ADD_POST});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#segment_quantity\" target=\"docs\">Number of Segments:</a></strong>");
    print "<td align=\"left\">\n";
    print "<select name=\"SEGMENT_QUANTITY\">\n";
    for($i=1;$i<10;$i++) {
	print $post->option({-value=>$i},$i);
    }
    print "</select>\n";
    print "</td>\n";
    print "</tr>\n";

    print "<tr>\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"submit",-value=>"OK"});
    print "</td>\n";
    print "</form>\n";
    
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_POSTS});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Cancel"});
    print "</td>\n";
    print "</form>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
    print "</html>\n";
}


sub ServeUploadAddPost {
    my $channel_name=$post->param("CHANNEL_NAME");

    #
    # Verify channel authorization
    #
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }
    $segment_quantity=$post->param("SEGMENT_QUANTITY");

    #
    # Render form
    #
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print $post->title("Loudwater Upload Post");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr><td id=\"bigframe\">\n";

    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Loudwater Upload Post</big></big>");
    print "</tr>\n";

    print "<form action=\"admin.pl\" method=\"post\" enctype=\"multipart/form-data\" onsubmit=\"PostCast()\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_ADD_POST});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SEGMENT_QUANTITY,
			-value=>$segment_quantity});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});

    for($i=0;$i<$segment_quantity;$i++) {
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},
			sprintf "<strong>Segment %d:</strong>",$i+1);
	print "<td align=\"left\">\n";
	print $post->input({-id=>"mediafile".$i,
			    -type=>"file",-name=>"MEDIAFILE".$i});
	print "</td>\n";
	print "</tr>\n";
    }

    print "<tr>\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"submit",-value=>"Upload"});
    print "</td>\n";
    print "</form>\n";
    
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_POSTS});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Cancel"});
    print "</td>\n";
    print "</form>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</td></tr>\n";

    print "</table>\n";
    print "</body>\n";
    print "</html>\n";
}


sub CommitAddPost {
    my $channel_name=$post->param("CHANNEL_NAME");
    @current_time=localtime();

    #
    # Verify channel authorization
    #
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    #
    # Get the channel record
    #
    my $sql=sprintf "select MAX_UPLOAD_SIZE,TITLE,CATEGORY,LINK,\
                     COPYRIGHT,WEBMASTER,LANGUAGE,THUMBNAIL_ID from CHANNELS \
                     where NAME=\"%s\"",
		     &EscapeString($channel_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    my $row;
    if(!($row=$q->fetchrow_arrayref)) {
	$q->finish();
	CgiError("no such channel");
    }
    $CGI::POST_MAX=@$row[0];

    #
    # Validate uploaded files
    #
    $segment_quantity=$post->param("SEGMENT_QUANTITY");
    my @extensions;
    for($i=0;$i<$segment_quantity;$i++) {
	my $filename=$post->param("MEDIAFILE".$i);
	if($filename eq "") {
	    $q->finish();
	    CgiError(sprintf "File %s is too large!",$filename);
	}
	my @sects=split "\\.",$filename;
	$_=$sects[$sects-1];
	s{\.}{}g;
	$extensions[$i]=$_;
    }

    #
    # Generate post record
    #
    $sql=sprintf "insert into POSTS set \
                  CHANNEL_NAME=\"%s\",\
                  TITLE=\"%s\",\
                  DESCRIPTION=\"Posted on %s\",\
                  SHORT_DESCRIPTION=\"Posted on %s\",\
                  CATEGORY=\"%s\",\
                  LINK=\"%s\",\
                  COPYRIGHT=\"%s\",\
                  WEBMASTER=\"%s\",\
                  LANGUAGE=\"%s\",\
                  THUMBNAIL_ID=%u,\
                  ACTIVE=\"N\",\ 
                  PARTS=%d,\
                  AIR_DATE=now(),\
                  LAST_MODIFIED_DATETIME=now(),\
                  ORIGIN_DATETIME=now(),\
                  ORIGIN_HOSTNAME=\"%s\",\
                  ORIGIN_ADDRESS=\"%s\",\
                  ORIGIN_USER_NAME=\"%s\",\
                  ORIGIN_USER_AGENT=\"%s\",\
                  PROCESSING=\"Y\"",
		  &EscapeString($channel_name),
                  &EscapeString(@$row[1]),
		  &EscapeString(strftime("%D",@current_time)),
		  &EscapeString(strftime("%D",@current_time)),
		  &EscapeString(@$row[2]),
		  &EscapeString(@$row[3]),
		  &EscapeString(@$row[4]),
		  &EscapeString(@$row[5]),
		  &EscapeString(@$row[6]),
		  @$row[7],
		  $segment_quantity,
                  &EscapeString($ENV{'REMOTE_HOST'}),
		  $ENV{'REMOTE_ADDR'},
		  &EscapeString($auth_user_name),
		  &EscapeString($ENV{'HTTP_USER_AGENT'});
    $q->finish();
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
    $new_post_id=$dbh->{q{mysql_insertid}};

    #
    # Upload media files
    #
    my @job_ids;
    for($i=0;$i<$segment_quantity;$i++) {
	my $path=
	    QueueFilePath(FILE_TYPE_INGEST,$new_post_id,$i,$extensions[$i]);
	$job_ids[$i]=$dbh->{q{mysql_insertid}};
	my $handle=$post->upload("MEDIAFILE".$i);
	open(F,">",$path);
	binmode F;
	while(<$handle>) {
	    print F;
	}
	close F;
	$sql=sprintf "insert into JOBS set \
                      POST_ID=%d,\
                      PART=%d,
                      PATH=\"%s\",\
                      STATUS=%d",
		      $new_post_id,
		      $i,
		      $path,
		      JOB_STATE_INGEST_QUEUED;
	$q=$dbh->prepare($sql);
	$q->execute();
	$q->finish();
    }

    #
    # Update the job status
    #
    $sql=sprintf "update POSTS set PROCESSING=\"Y\" where ID=%d",$new_post_id;
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeEditPost {
    my $post_id=$new_post_id;
    if($post_id==0) {
	$post_id=$post->param("POST_ID");
    }
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print $post->title("Loudwater Post Data");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select POSTS.CHANNEL_NAME,POSTS.TITLE,POSTS.DESCRIPTION,\
                     POSTS.SHORT_DESCRIPTION,POSTS.CATEGORY,POSTS.LINK,\
                     POSTS.COPYRIGHT,POSTS.WEBMASTER,POSTS.AUTHOR,\
                     POSTS.KEYWORDS,POSTS.COMMENTS,POSTS.AIR_DATE,\
                     POSTS.AIR_HOUR,CHANNELS.THUMBNAIL_DOWNLOAD_URL,\
                     THUMBNAILS.FILENAME,POSTS.LANGUAGE,\
                     POSTS.PARTS,POSTS.LAST_MODIFIED_DATETIME,\
                     POSTS.ORIGIN_DATETIME,USERS.FULL_NAME,\
                     POSTS.ORIGIN_ADDRESS,POSTS.PROCESSING,POSTS.DELETING,\
                     POSTS.ACTIVE,POSTS.EXPLICIT,POSTS.THUMBNAIL_ID \
                     from POSTS left join USERS \
                     on POSTS.ORIGIN_USER_NAME=USERS.NAME left join CHANNELS \
                     on POSTS.CHANNEL_NAME=CHANNELS.NAME left join THUMBNAILS \
                     on POSTS.THUMBNAIL_ID=THUMBNAILS.ID where POSTS.ID=%d",
		     $post_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>2,-align=>"center"},
			"<big><big>Edit Post Data</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_POST});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"hidden",-name=>POST_ID,-value=>$post_id});

	#
	# Post Title
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_title\" target=\"docs\">Title:</a></strong>");
	print $post->td({-align=>"left"},
			$post->input({-id=>"TITLE",-size=>60,-maxlength=>255,
				      -type=>"text",
				      -name=>TITLE,
				      -value=>&GetLocalValue($post,"TITLE",
							     @$row[1])}));
	print "</tr>\n";

	#
	# Post Description
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#post_description\" target=\"docs\">Description:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->textarea({-id=>"DESCRIPTION",-cols=>60,-rows=>4,
					 -name=>DESCRIPTION,
					 -value=>&GetLocalValue($post,
								"DESCRIPTION",
								@$row[2])}));
	print "</tr>\n";

	#
	# Post Short Description
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_short_description\" target=\"docs\">Short Description:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"SHORT_DESCRIPTION",-size=>60,
				      -maxlength=>80,-type=>"text",
				      -name=>SHORT_DESCRIPTION,
				      -value=>&GetLocalValue($post,
							    "SHORT_DESCRIPTION",
							     @$row[3])}));
	print "</tr>\n";

	#
	# Post Category
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_category\" target=\"docs\">Category:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"CATEGORY",-size=>60,
				      -maxlength=>255,-type=>"text",
				      -name=>CATEGORY,
				      -value=>&GetLocalValue($post,"CATEGORY",
							     @$row[4])}));
	print "</tr>\n";

	#
	# Post Link
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_link\" target=\"docs\">Link:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"LINK",-size=>60,-maxlength=>255,
				      -type=>"text",
				      -name=>LINK,
				      -value=>&GetLocalValue($post,"LINK",
							     @$row[5])}));
	print "</tr>\n";

	#
	# Post Copyright
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_copyright\" target=\"docs\">Copyright:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"COPYRIGHT",-size=>60,
				      -maxlength=>255,-type=>"text",
				      -name=>COPYRIGHT,
				      -value=>&GetLocalValue($post,"COPYRIGHT",
							     @$row[6])}));
	print "</tr>\n";

	#
	# Post Webmaster
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_webmaster\" target=\"docs\">Webmaster:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"WEBMASTER",-size=>60,
				      -maxlength=>255,-type=>"text",
				      -name=>WEBMASTER,
				      -value=>&GetLocalValue($post,"WEBMASTER",
							     @$row[7])}));
	print "</tr>\n";

	#
	# Post Author
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_author\" target=\"docs\">Author:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"AUTHOR",-size=>60,
				      -maxlength=>255,-type=>"text",
				      -name=>AUTHOR,
				      -value=>&GetLocalValue($post,"AUTHOR",
							     @$row[8])}));
	print "</tr>\n";

	#
	# Post Keywords
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_keywords\" target=\"docs\">Keywords:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"KEYWORDS",-size=>60,
				      -maxlength=>255,-type=>"text",
				      -name=>KEYWORDS,
				      -value=>&GetLocalValue($post,"KEYWORDS",
							     @$row[9])}));
	print "</tr>\n";

	#
	# Post Comments
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#post_comments\" target=\"docs\">Comments:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->textarea({-id=>"COMMENTS",-cols=>60,-rows=>4,
				      -name=>COMMENTS,
				      -value=>&GetLocalValue($post,"COMMENTS",
							     @$row[10])}));
	print "</tr>\n";

	#
	# Air Date
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_air_date\" target=\"docs\">Air Date:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"AIR_DATE",-size=>10,
				      -maxlength=>10,-type=>"text",
				      -id=>AIR_DATE,
				      -name=>AIR_DATE,
				      -value=>&LocaleDatetime(&GetLocalValue($post,"AIR_DATE",
							     @$row[11]))}));
	print "</tr>\n";

	#
	# Air Hour
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_air_hour\" target=\"docs\">Air Hour:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"AIR_HOUR",-size=>3,
				      -maxlength=>1,-type=>"text",
				      -name=>AIR_HOUR,
				      -value=>&GetLocalValue($post,"AIR_HOUR",
							     @$row[12])}));
	print "</tr>\n";

	#
	# Post Thumbnail
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";

	print $post->td({-align=>"right",-valign=>"top"},
			"<strong><a href=\"admin-doc.html#post_thumbnail\" target=\"docs\">Thumbnail Image:</a></strong>");
	if(@$row[14] eq "") {
	    print $post->td({-colspan=>3,-align=>"left"},
			    $post->input({-type=>"button",-value=>"Choose Image",
			     -onclick=>sprintf "editThumbnail(%u,\"%s\",%u,%u)",
			     $session_id,@$row[0],$post_id,@$row[25]}));
	}
	else {
	    print $post->td({-colspan=>3,-align=>"left",
			     -onclick=>sprintf "editThumbnail(%u,\"%s\",%u,%u)",
			     $session_id,@$row[0],$post_id,@$row[25]},
			    $post->img({-border=>1,
					-src=>@$row[13]."/".@$row[14]}));
	}
	print "</tr>\n";

	#
	# Post Language
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_language\" target=\"docs\">Language:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			$post->input({-id=>"LANGUAGE",-size=>4,-maxlength=>5,
				      -type=>"text",
				      -name=>LANGUAGE,
				      -value=>&GetLocalValue($post,"LANGUAGE",
							     @$row[15])}));
	print "</tr>\n";

	#
	# Post Active
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_active\" target=\"docs\">Post Active:</a></strong>");
	print "<td colspan=\"3\">\n";
	print "<select id=\"POST_ACTIVE\" name=\"POST_ACTIVE\">\n";
        if(&GetLocalValue($post,"POST_ACTIVE",@$row[23]) eq "Y") {
	    print $post->option({-value=>"Y",-selected},"Yes");
	    print $post->option({-value=>"N"},"No");
	}
	else {
	    print $post->option({-value=>"Y"},"Yes");
	    print $post->option({-value=>"N",-selected},"No");
	}
	print "</select>\n";
	print "</td>\n";
	print "</tr>\n";

	#
	# Number of Parts
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_segments\" target=\"docs\">Segments:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},@$row[16]);
	print "</tr>\n";

	#
	# Last Modified Datetime
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_last_modified_datetime\" target=\"docs\">Last Modified:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			&LocaleDatetime(@$row[17]));
	print "</tr>\n";

	#
	# Origin Datetime
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_origin_datetime\" target=\"docs\">Posted On:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},
			&LocaleDatetime(@$row[18]));
	print "</tr>\n";

	#
	# Origin User
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_origin_user\" target=\"docs\">Posted By:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},@$row[19]);
	print "</tr>\n";

	#
	# Origin Address
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#post_origin_address\" target=\"docs\">Posted From:</a></strong>");
	print $post->td({-colspan=>3,-align=>"left"},@$row[20]);
	print "</tr>\n";


	#
	# OK Button
	#
	print "<tr>\n";
	print $post->td({-align=>"left"},
			$post->input({-type=>"button",-value=>"OK",
				      -onclick=>sprintf "validateEditPost(%u,\"%s\",%u,%u)",
			     $session_id,@$row[0],$post_id}));
	print "</form>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_POSTS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>@$row[0]});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";
    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitEditPost {
    $post_id=$post->param("POST_ID");
    my $post_active="N";
    if($post->param("POST_ACTIVE")) {
	$post_active="Y";
    }
    my $sql=sprintf "update POSTS set \
                     TITLE=\"%s\",\
                     DESCRIPTION=\"%s\",\
                     SHORT_DESCRIPTION=\"%s\",\
                     CATEGORY=\"%s\",\
                     LINK=\"%s\",\
                     COPYRIGHT=\"%s\",\
                     WEBMASTER=\"%s\",\
                     AUTHOR=\"%s\",\
                     KEYWORDS=\"%s\",\
                     AIR_DATE=\"%s\",\
                     AIR_HOUR=%d,\
                     COMMENTS=\"%s\",\
                     LANGUAGE=\"%s\",\
                     ACTIVE=\"%s\",\
                     LAST_MODIFIED_DATETIME=now() \
                     where ID=%d",
		     &EscapeString($post->param("TITLE")),
		     &EscapeString($post->param("DESCRIPTION")),
		     &EscapeString($post->param("SHORT_DESCRIPTION")),
		     &EscapeString($post->param("CATEGORY")),
		     &EscapeString($post->param("LINK")),
		     &EscapeString($post->param("COPYRIGHT")),
		     &EscapeString($post->param("WEBMASTER")),
		     &EscapeString($post->param("AUTHOR")),
		     &EscapeString($post->param("KEYWORDS")),
		     &SqlDatetime($post->param("AIR_DATE")),
		     $post->param("AIR_HOUR"),
		     &EscapeString($post->param("COMMENTS")),
		     &EscapeString($post->param("LANGUAGE")),
		     $post->param("POST_ACTIVE"),
		     $post_id;
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeDeletePost {
    my $channel_name=$post->param("CHANNEL_NAME");
    my $post_id=$post->param("POST_ID");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Delete Post");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Are you sure that you want to delete this post?");
    print "</tr>\n";

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_DELETE_POST});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>POST_ID,
			-value=>$post_id});
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"Yes"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_POSTS});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"No"}));
    print "</form>\n";

    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitDeletePost {
    #
    # Validate User
    #
    my $channel_name=$post->param("CHANNEL_NAME");
    my $post_id=$post->param("POST_ID");
    my $sql=sprintf "select POSTS.ID from POSTS left join CHANNEL_PERMS \
                     on POSTS.CHANNEL_NAME=CHANNEL_PERMS.CHANNEL_NAME \
                     where CHANNEL_PERMS.USER_NAME=\"%s\"",$auth_user_name;
    $q=$dbh->prepare($sql);
    $q->execute();
    if(!(my $row=$q->fetchrow_arrayref)) {
	$q->finish();
	CgiError("unauthorized operation");
    }
    $channel_id=@$row[0];
    $q->finish();

    &DeletePost($post_id);
}


sub ServeListUploads {
    $channel_name=$post->param("CHANNEL_NAME");
    $post_id=$post->param("POST_ID");
    $post_title=$post->param("POST_TITLE");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print $post->title("Loudwater Post Data");
    print "</head>\n";

    print "<body>\n";
    print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"0\">\n";

    #
    # Page Title
    #
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Direct Links for \"".$post_title."\"</big></big>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "When posting the link, append the name of the player.");
    print "</tr>\n";

    #
    # Links
    #
    print "<tr>\n";
    print $post->th({-align=>"center"},"TAP");
    print $post->th({-align=>"center"},"LINK");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    $sql=sprintf "select TAPS.TITLE,UPLOADS.ID from TAPS left join UPLOADS \
                      on TAPS.ID=UPLOADS.TAP_ID \
                      where UPLOADS.POST_ID=%d",$post_id;
    my $q1=$dbh->prepare($sql);
    $q1->execute();
    while(my $row1=$q1->fetchrow_arrayref) {
	print "<tr bgcolor=\"".$bgcolor."\">\n";
	print $post->td(@$row1[0]);
	print $post->
	    td(&GetLoudwaterUrl."player.pl?upload=".@$row1[1]."&name=");
	print "</tr>\n";
	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q1->finish();

    #
    # Close Button
    #
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_POSTS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->td({-colspan=>2,-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Close"}));
    print "</form>\n";
    print "</tr>\n";
    print "</table>\n";
    print "</body>\n";
}


sub ServeViewJobs {
    my $channel_name=$post->param("CHANNEL_NAME");
    my $post_id=$post->param("POST_ID");
    my $tap_id=$post->param("TAP_ID");
    my $where_sql;
    my $close_command=COMMAND_LIST_POSTS;

    #
    # Verify channel authorization
    #
    if($post_id ne "") {
	if(!PostAuthorized($post_id)) {
	    CgiError("Channel not authorized");
	}
	$sql=sprintf "select CHANNEL_NAME from POSTS where ID=%d",$post_id;
	$q=$dbh->prepare($sql);
	$q->execute();
	if(my $row=$q->fetchrow_arrayref) {
	    $channel_name=@$row[0];
	}
	else {
	    CgiError("Invalid post id");
	}
	$q->finish();
	$where_sql=sprintf "POST_ID=%d",$post_id;
    }
    else {
	if($channel_name ne "") {
	    if(!&ChannelAuthorized($channel_name)) {
		CgiError("Channel not authorized");
	    }
	    if($tap_id eq "") {
		CgiError("Invalid tap id");
	    }
	    $where_sql=sprintf "TAP_ID=%d",$tap_id;
	    $close_command=COMMAND_EDIT_CHANNEL;
	}
	else {
	    CgiError("Channel not authorized");
	}
    }

    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Jobs");
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr><td id=\"bigframe\">\n";

    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";

    #
    # Display jobs
    #
    $sql=sprintf "select JOBS.ID,JOBS.POST_ID,JOBS.TAP_ID,JOBS.STATUS,\
                  JOBS.ERROR_TEXT,JOBS.HOSTNAME,JOBS.PART,POSTS.PARTS \
                  from JOBS left join POSTS \
                  on JOBS.POST_ID=POSTS.ID \
                  where %s order by ID",$where_sql;
    $q=$dbh->prepare($sql);
    $q->execute();
    print "<tr>\n";
    print $post->td({-colspan=>6,-align=>"center"},
		    "<big><big>Loudwater Jobs</big></big>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->th({-align=>"center"},"Job ID");
    print $post->th({-align=>"center"},"Post ID");
    print $post->th({-align=>"center"},"Tap ID");
    print $post->th({-align=>"center"},"Job Status");
    print $post->th({-align=>"center"},"Running On");
#    print $post->th({-align=>"center"},"Filename");
    print $post->th({-align=>"center"},"Part");
    print $post->th({-align=>"center"},"&nbsp;");
    print $post->th({-align=>"center"},"&nbsp;");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    while(my $row=$q->fetchrow_arrayref) {
	print "<tr bgcolor=\"".$bgcolor."\">\n";
	print $post->td({-align=>"center"},@$row[0]);
	if(@$row[1] eq "") {
	    print $post->td({-align=>"center"},"n/a");
	}
	else {
	    print $post->td({-align=>"center"},@$row[1]);
	}
	if(@$row[2] eq "") {
	    print $post->td({-align=>"center"},"n/a");
	}
	else {
	    print $post->td({-align=>"center"},@$row[2]);
	}
	print $post->td({-align=>"center"},"<font color=\"".
			&JobStatusColor(@$row[3])."\">".
			&JobStatusString(@$row[3],@$row[4])."</font>");
	if(@$row[5] eq "") {
	    print $post->td({-align=>"center"},"n/a");
	}
	else {
	    print $post->td({-align=>"center"},@$row[5]);
	}
	if(@$row[6] eq "") {
	    print $post->td({-align=>"center"},"n/a");
	}
	else {
	    print $post->td({-align=>"center"},1+@$row[6]." of ".@$row[7]);
	}
	if((@$row[3]==JOB_STATE_ENCODER_ERROR)||
	   (@$row[3]==JOB_STATE_MISSING_ENCODER_ERROR)||
	   (@$row[3]==JOB_STATE_DISTRIBUTION_ERROR)) {
	    print $post->td($post->input({-type=>"button",-value=>"Restart",
					  -onclick=>"restartJob(".$session_id.
					      ",".$post_id.",".@$row[0].")"}));
	}
	else {
	    print $post->td({-align=>"center"},"&nbsp;");
	}
	if((@$row[3]==JOB_STATE_ENCODER_ERROR)||
	   (@$row[3]==JOB_STATE_MISSING_ENCODER_ERROR)||
	   (@$row[3]==JOB_STATE_DISTRIBUTION_ERROR)||
	   (@$row[3]==JOB_STATE_INTERNAL_ERROR)||
	   (@$row[3]==JOB_STATE_UNKNOWN_FILETYPE_ERROR)) {
	    print $post->td($post->input({-type=>"button",-value=>"Delete",
					  -onclick=>"deleteJob(".$session_id.
					      ",".$post_id.",".@$row[0].")"}));
	}
	else {
	    print $post->td({-align=>"center"},"&nbsp;");
	}
	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td colspan=\"8\" align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>$close_command});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";
    print "</tr>\n";

    print "</table>\n";
}


sub RestartJob {
    my $post_id=$post->param("POST_ID");
    my $job_id=$post->param("JOB_ID");

    #
    # Verify channel authorization
    #
    if(!PostAuthorized($post_id)) {
	CgiError("Channel not authorized");
    }
    if($job_id eq "") {
	CgiError("missing JOB_ID");
    }

    my $sql=sprintf "select STATUS from JOBS where ID=%u",$job_id;
    my $q=$dbh->prepare($sql);
    my $row;
    $q->execute();
    if(!($row=$q->fetchrow_arrayref)) {
	$q->finish();
	CgiError("no such job");
    }
    if((@$row[0]==JOB_STATE_ENCODER_ERROR)||
       (@$row[0]==JOB_STATE_MISSING_ENCODER_ERROR)) {
	$sql=sprintf "update JOBS set STATUS=%d where ID=%u",
	     JOB_STATE_ENCODE_QUEUED,$job_id;
	my $q1=$dbh->prepare($sql);
	$q1->execute();
	$q1->finish();
    }
    if(@$row[0]==JOB_STATE_DISTRIBUTION_ERROR) {
	$sql=sprintf "update JOBS set STATUS=%d where ID=%u",
	     JOB_STATE_DISTRIBUTION_QUEUED,$job_id;
	my $q1=$dbh->prepare($sql);
	$q1->execute();
	$q1->finish();
    }
    $q->finish();
}


sub DeleteJob {
    my $post_id=$post->param("POST_ID");
    my $job_id=$post->param("JOB_ID");

    #
    # Verify channel authorization
    #
    if(!PostAuthorized($post_id)) {
	CgiError("Channel not authorized");
    }
    if($job_id eq "") {
	CgiError("missing JOB_ID");
    }
    my $sql=sprintf "select PATH from JOBS where ID=%u",$job_id;
    my $q=$dbh->prepare($sql);
    my $row;
    $q->execute();
    if(!($row=$q->fetchrow_arrayref)) {
	$q->finish();
	CgiError("no such job");
    }
    unlink @$row[0];
    $q->finish();

    $sql=sprintf "delete from JOBS where ID=%u",$job_id;
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    &UpdatePostStatus($post_id);
}


sub ServeListServers {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Server List");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql="select HOSTNAME,IP_ADDRESS,TOTAL_THREADS,\
             INGEST_THREADS,ENCODE_THREADS,DISTRIBUTION_THREADS,\
             MAINTENANCE_THREADS from SERVERS order by HOSTNAME";
    my $q=$dbh->prepare($sql);
    $q->execute();

    print "<tr>\n";
    print $post->td({-colspan=>9,-align=>"center"},
		    "<big><big>Loudwater Server List</big></big>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->th({-align=>"center"},"Hostname");
    print $post->th({-align=>"center"},"IP Address");
    print $post->th({-align=>"center"},"Total<br>Threads");
    print $post->th({-align=>"center"},"Ingest<br>Threads");
    print $post->th({-align=>"center"},"Encode<br>Threads");
    print $post->th({-align=>"center"},"Distribution<br>Threads");
    print $post->th({-align=>"center"},"Maintenance<br>Threads");
    print $post->th({-align=>"center"},"&nbsp;");
    print $post->th({-align=>"center"},"&nbsp;");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    while(my $row=$q->fetchrow_arrayref) {
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"left"},@$row[0]);
	print $post->td({-align=>"center"},@$row[1]);
	print $post->td({-align=>"center"},@$row[2]);
	print $post->td({-align=>"center"},@$row[3]);
	print $post->td({-align=>"center"},@$row[4]);
	print $post->td({-align=>"center"},@$row[5]);
	print $post->td({-align=>"center"},@$row[6]);
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_SERVER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>SERVER_HOSTNAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Edit});
	print "</td>\n";
	print "</form>\n";
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_DELETE_SERVER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>SERVER_HOSTNAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Delete});
	print "</td>\n";
	print "</form>\n";
	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_ADD_SERVER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Add Server"});
    print "</td>\n";
    print "</form>\n";

    print $post->td({-colspan=>7},"&nbsp;");

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_MAIN_MENU});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";


    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";

    exit 0;
}


sub ServeAddServer {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Add Server");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Add Server</big></big>");
    print "</tr>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_ADD_SERVER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print "<tr>\n";
    print $post->td({-bgcolor=>BGCOLOR1,-align=>"right"},"<strong>Server Hostname:</strong>");
    print $post->td({-bgcolor=>BGCOLOR1,-align=>"left"},
		    $post->input({-type=>"text",-size=>40,-maxlength=>32,
				  -name=>SERVER_HOSTNAME}));
    print "</tr>\n";

    #
    # OK Button
    #
    print "<tr>\n";
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"OK"}));
    print "</form>\n";

    #
    # Cancel Button
    #
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_SERVERS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Cancel"}));
    print "</form>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitAddServer {
    my $server_hostname=$post->param("SERVER_HOSTNAME");
    my $sql=sprintf "insert into SERVERS set HOSTNAME=\"%s\"",
                     &EscapeString($server_hostname);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeEditServer {
    my $server_hostname=$post->param("SERVER_HOSTNAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Server");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select IP_ADDRESS,TOTAL_THREADS,INGEST_THREADS,\
                     ENCODE_THREADS,DISTRIBUTION_THREADS,\
                     MAINTENANCE_THREADS from SERVERS \
                     where HOSTNAME=\"%s\"",&EscapeString($server_hostname);
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>2,-align=>"center"},
			"<big><big>Edit Server Data</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_SERVER});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>SERVER_HOSTNAME,
			    -value=>$server_hostname});

	#
	# Hostname
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#server_hostname\" target=\"docs\">Hostname:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},$server_hostname);
	print "</tr>\n";

	#
	# IP Address
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#server_ip_address\" target=\"docs\">IP Address:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>20,-maxlength=>16,-type=>"text",
				      -name=>"IP_ADDRESS",-value=>@$row[0]}));
	print "</tr>\n";

	#
	# Total Threads
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#server_total_threads\" target=\"docs\">Total Threads:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>2,-maxlength=>2,-type=>"text",
				      -name=>"TOTAL_THREADS",
				      -value=>@$row[1]}));
	print "</tr>\n";

	#
	# Ingest Threads
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#server_ingest_threads\" target=\"docs\">Ingest Threads:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>2,-maxlength=>2,-type=>"text",
				      -name=>"INGEST_THREADS",
				      -value=>@$row[2]}));
	print "</tr>\n";

	#
	# Encode Threads
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#server_encode_threads\" target=\"docs\">Encode Threads:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>2,-maxlength=>2,-type=>"text",
				      -name=>"ENCODE_THREADS",
				      -value=>@$row[3]}));
	print "</tr>\n";

	#
	# Distribution Threads
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#server_distribution_threads\" target=\"docs\">Distribution Threads:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>2,-maxlength=>2,-type=>"text",
				      -name=>"DISTRIBUTION_THREADS",
				      -value=>@$row[4]}));
	print "</tr>\n";

	#
	# Maintenance Threads
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#server_maintenance_threads\" target=\"docs\">Maintenance Threads:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>2,-maxlength=>2,-type=>"text",
				      -name=>"MAINTENANCE_THREADS",
				      -value=>@$row[5]}));
	print "</tr>\n";

	#
	# OK Button
	#
	print "<tr>\n";
	print $post->td({-align=>"left"},
			$post->input({-type=>"submit",-value=>"OK"}));
	print "</form>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_LIST_SERVERS});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";
    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitEditServer {
    $server_hostname=$post->param("SERVER_HOSTNAME");
    my $sql=sprintf "update SERVERS set \
                     IP_ADDRESS=\"%s\",\
                     TOTAL_THREADS=%d,\
                     INGEST_THREADS=%d,\
                     ENCODE_THREADS=%d,\
                     DISTRIBUTION_THREADS=%d,\
                     MAINTENANCE_THREADS=%d \
                     where HOSTNAME=\"%s\"",
		     &EscapeString($post->param("IP_ADDRESS")),
		     &EscapeString($post->param("TOTAL_THREADS")),
		     &EscapeString($post->param("INGEST_THREADS")),
		     &EscapeString($post->param("ENCODE_THREADS")),
		     &EscapeString($post->param("DISTRIBUTION_THREADS")),
		     &EscapeString($post->param("MAINTENANCE_THREADS")),
		     &EscapeString($server_hostname);
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeDeleteServer {
    my $server_hostname=$post->param("SERVER_HOSTNAME");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Delete Server");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Are you sure that you want to delete this server?");
    print "</tr>\n";

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_DELETE_SERVER});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>SERVER_HOSTNAME,
			-value=>$server_hostname});
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"Yes"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_SERVERS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"No"}));
    print "</form>\n";

    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitDeleteServer {
    my $server_hostname=$post->param("SERVER_HOSTNAME");
    my $sql=sprintf "delete from SERVERS where HOSTNAME=\"%s\"",
                     &EscapeString($server_hostname);
    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeAddTap {
    #
    # Verify channel authorization
    #
    my $channel_name=$post->param("CHANNEL_NAME");
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Add Tap");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Add New Tap</big></big>");
    print "</tr>\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Select the type of tap to create:");
    print "</tr>\n";

    #
    # Blank entry
    #
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td("[blank fields]");
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_ADD_TAP});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>EXAMPLE_ID,-value=>0});
    print $post->input({-type=>"hidden",-name=>"TITLE",
			-value=>$post->param("TITLE")});
    print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
			-value=>$post->param("DESCRIPTION")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY",
			-value=>$post->param("CATEGORY")});
    print $post->input({-type=>"hidden",-name=>"LINK",
			-value=>$post->param("LINK")});
    print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
			-value=>$post->param("COPYRIGHT")});
    print $post->input({-type=>"hidden",-name=>"WEBMASTER",
			-value=>$post->param("WEBMASTER")});
    print $post->input({-type=>"hidden",-name=>"AUTHOR",
			-value=>$post->param("AUTHOR")});
    print $post->input({-type=>"hidden",-name=>"OWNER",
			-value=>$post->param("OWNER")});
    print $post->input({-type=>"hidden",-name=>"OWNER_EMAIL",
			-value=>$post->param("OWNER_EMAIL")});
    print $post->input({-type=>"hidden",-name=>"SUBTITLE",
			-value=>$post->param("SUBTITLE")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY_ITUNES",
			-value=>$post->param("CATEGORY_ITUNES")});
    print $post->input({-type=>"hidden",-name=>"KEYWORDS",
			-value=>$post->param("KEYWORDS")});
    print $post->input({-type=>"hidden",-name=>"EXPLICIT",
			-value=>$post->param("EXPLICIT")});
    print $post->input({-type=>"hidden",-name=>"LANGUAGE",
			-value=>$post->param("LANGUAGE")});
    print $post->input({-type=>"hidden",-name=>"MAX_UPLOAD_SIZE",
			-value=>$post->param("MAX_UPLOAD_SIZE")});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Select"}));
    print "</form>\n";
    print "</tr>\n";

    #
    # Predefined entries
    #
    my $bgcolor=BGCOLOR2;
    $sql="select ID,NAME from EXAMPLE_XML order by NAME";
    my $q=$dbh->prepare($sql);
    $q->execute();
    while(my $row=$q->fetchrow_arrayref) {
	print "<tr bgcolor=\"".$bgcolor."\">\n";
	print $post->td(@$row[1]);
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_ADD_TAP});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>$channel_name});
	print $post->input({-type=>"hidden",-name=>EXAMPLE_ID,
			    -value=>@$row[0]});
	print $post->input({-type=>"hidden",-name=>"TITLE",
			    -value=>$post->param("TITLE")});
	print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
			    -value=>$post->param("DESCRIPTION")});
	print $post->input({-type=>"hidden",-name=>"CATEGORY",
			    -value=>$post->param("CATEGORY")});
	print $post->input({-type=>"hidden",-name=>"LINK",
			    -value=>$post->param("LINK")});
	print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
			    -value=>$post->param("COPYRIGHT")});
	print $post->input({-type=>"hidden",-name=>"WEBMASTER",
			    -value=>$post->param("WEBMASTER")});
	print $post->input({-type=>"hidden",-name=>"AUTHOR",
			    -value=>$post->param("AUTHOR")});
	print $post->input({-type=>"hidden",-name=>"OWNER",
			    -value=>$post->param("OWNER")});
	print $post->input({-type=>"hidden",-name=>"OWNER_EMAIL",
			    -value=>$post->param("OWNER_EMAIL")});
	print $post->input({-type=>"hidden",-name=>"SUBTITLE",
			    -value=>$post->param("SUBTITLE")});
	print $post->input({-type=>"hidden",-name=>"CATEGORY_ITUNES",
			    -value=>$post->param("CATEGORY_ITUNES")});
	print $post->input({-type=>"hidden",-name=>"KEYWORDS",
			    -value=>$post->param("KEYWORDS")});
	print $post->input({-type=>"hidden",-name=>"EXPLICIT",
			    -value=>$post->param("EXPLICIT")});
	print $post->input({-type=>"hidden",-name=>"LANGUAGE",
			    -value=>$post->param("LANGUAGE")});
	print $post->input({-type=>"hidden",-name=>"MAX_UPLOAD_SIZE",
			    -value=>$post->param("MAX_UPLOAD_SIZE")});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Select"}));
	print "</form>\n";
	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_EDIT_CHANNEL});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>"TITLE",
			-value=>$post->param("TITLE")});
    print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
			-value=>$post->param("DESCRIPTION")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY",
			-value=>$post->param("CATEGORY")});
    print $post->input({-type=>"hidden",-name=>"LINK",
			-value=>$post->param("LINK")});
    print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
			-value=>$post->param("COPYRIGHT")});
    print $post->input({-type=>"hidden",-name=>"WEBMASTER",
			-value=>$post->param("WEBMASTER")});
    print $post->input({-type=>"hidden",-name=>"AUTHOR",
			-value=>$post->param("AUTHOR")});
    print $post->input({-type=>"hidden",-name=>"OWNER",
			-value=>$post->param("OWNER")});
    print $post->input({-type=>"hidden",-name=>"OWNER_EMAIL",
			-value=>$post->param("OWNER_EMAIL")});
    print $post->input({-type=>"hidden",-name=>"SUBTITLE",
			-value=>$post->param("SUBTITLE")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY_ITUNES",
			-value=>$post->param("CATEGORY_ITUNES")});
    print $post->input({-type=>"hidden",-name=>"KEYWORDS",
			-value=>$post->param("KEYWORDS")});
    print $post->input({-type=>"hidden",-name=>"EXPLICIT",
			-value=>$post->param("EXPLICIT")});
    print $post->input({-type=>"hidden",-name=>"LANGUAGE",
			-value=>$post->param("LANGUAGE")});
    print $post->input({-type=>"hidden",-name=>"MAX_UPLOAD_SIZE",
			-value=>$post->param("MAX_UPLOAD_SIZE")});
    print $post->td({-colspan=>2,-align=>"right"},
		    $post->input({-type=>"submit",-value=>"Cancel"}));
    print "</form>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitAddTap {
    #
    # Verify channel authorization
    #
    my $channel_name=$post->param("CHANNEL_NAME");
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    #
    # Get exemplar XML
    #
    my $header_xml="";
    my $channel_xml="";
    my $item_xml="";
    my $footer_xml="";
    my $example_id=$post->param("EXAMPLE_ID");
    my $sql=sprintf "select HEADER_XML,CHANNEL_XML,ITEM_XML,FOOTER_XML \
                     from EXAMPLE_XML where ID=%u",$example_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	$header_xml=@$row[0];
	$channel_xml=@$row[1];
	$item_xml=@$row[2];
	$footer_xml=@$row[3];
    }
    $q->finish();

    #
    # Create tap record
    #
    $sql=sprintf 
	"insert into TAPS set TITLE=\"[new tap]\",CHANNEL_NAME=\"%s\",\
         HEADER_XML=\"%s\",\
         CHANNEL_XML=\"%s\",\
         ITEM_XML=\"%s\",\
         FOOTER_XML=\"%s\",\
         ORIGIN_DATETIME=now(),LAST_BUILD_DATETIME=now()",
	 &EscapeString($channel_name),
	 &EscapeString($header_xml),
	 &EscapeString($channel_xml),
	 &EscapeString($item_xml),
	 &EscapeString($footer_xml);
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
    $new_tap_id=$dbh->{q{mysql_insertid}};
}


sub ServeEditTap {
    my $tap_id=$new_tap_id;
    if($tap_id==0) {
	$tap_id=$post->param("TAP_ID");
    }
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Tap");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql=sprintf "select CHANNEL_NAME,TITLE,ORIGIN_DATETIME,\
                     LAST_BUILD_DATETIME,VISIBILITY_WINDOW,UPLOAD_URL,\
                     UPLOAD_USERNAME,UPLOAD_PASSWORD,DOWNLOAD_URL,\
                     DOWNLOAD_MIMETYPE,DOWNLOAD_PREAMBLE,PING_URL,\
                     VALIDATION_URL,IS_TRANSPARENT,\
                     AUDIO_ENCODER,AUDIO_EXTENSION,AUDIO_MIMETYPE,\
                     VIDEO_ENCODER,VIDEO_EXTENSION,VIDEO_MIMETYPE,\
                     AUDIO_SAMPLERATE,AUDIO_CHANNELS,\
                     HEADER_XML,CHANNEL_XML,ITEM_XML,FOOTER_XML \
                     from TAPS where ID=%d",$tap_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>2,-align=>"center"},
			"<big><big>Edit Loudwater Tap</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_TAP});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"hidden",-name=>TAP_ID,
			    -value=>$tap_id});

	#
	# Channel Name
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_channel_name\" target=\"docs\">Channel:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},@$row[0]);
	print "</tr>\n";

	#
	# Tap Title
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_title\" target=\"docs\">Title:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>64,-type=>"text",
				      -name=>"TAP_TITLE",-value=>@$row[1]}));
	print "</tr>\n";

	#
	# Origin Datetime
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_origin_datetime\" target=\"docs\">Created On:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},@$row[2]);
	print "</tr>\n";

	#
	# Last Build Datetime
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_last_build_datetime\" target=\"docs\">Last Modified On:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},@$row[3]);
	print "</tr>\n";

	#
	# Visibility Window
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_visibility_window\" target=\"docs\">Posts Visible For:</a></strong>");
	print $post->td({-align=>"left"},
			$post->input({-size=>3,-maxlength=>3,-type=>"text",
				      -name=>"VISIBILITY_WINDOW",-value=>@$row[4]})." days (0 = Unlimited)");
	print "</tr>\n";

	#
	# Upload URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_upload_url\" target=\"docs\">Upload URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"UPLOAD_URL",-value=>@$row[5]}));
	print "</tr>\n";

	#
	# Upload Username
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_upload_username\" target=\"docs\">Upload Username:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>20,-maxlength=>64,-type=>"text",
				      -name=>"UPLOAD_USERNAME",
				      -value=>@$row[6]}));
	print "</tr>\n";

	#
	# Upload Password
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_upload_password\" target=\"docs\">Upload Password:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>20,-maxlength=>64,-type=>"password",
				      -name=>"UPLOAD_PASSWORD",
				      -value=>@$row[7]}));
	print "</tr>\n";

	#
	# Download URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_download_url\" target=\"docs\">Download URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"DOWNLOAD_URL",-value=>@$row[8]}));
	print "</tr>\n";

	#
	# Download MIME Type
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_download_mimetype\" target=\"docs\">Download MIME Type:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"DOWNLOAD_MIMETYPE",
				      -value=>@$row[9]}));
	print "</tr>\n";

	#
	# Download Preamble
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_download_preamble\" target=\"docs\">Download Preamble:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"DOWNLOAD_PREAMBLE",
				      -value=>@$row[10]}));
	print "</tr>\n";

	#
	# Ping URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_ping_url\" target=\"docs\">Ping URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"PING_URL",-value=>@$row[11]}));
	print "</tr>\n";

	#
	# Validation URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_validation_url\" target=\"docs\">Validation URL:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"VALIDATION_URL",-value=>@$row[12]}));
	print "</tr>\n";

	#
	# Transparency Mode
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#transparency_mode\" target=\"docs\">Transparency Mode:</a></strong>");
	print "<td colspan=\"3\">\n";
	print "<select id=\"IS_TRANSPARENT\" name=\"IS_TRANSPARENT\">\n";
	if(&GetLocalValue($post,"IS_TRANSPARENT",@$row[13]) eq "Y") {
	    print $post->option({-value=>"Y",-selected},"Yes");
	    print $post->option({-value=>"N"},"No");
	}
	else {
	    print $post->option({-value=>"Y"},"Yes");
	    print $post->option({-value=>"N",-selected},"No");
	}
	print "</select>\n";
	print "</td>\n";
	print "</tr>\n";

	#
	# Audio Encoder
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_audio_encoder\" target=\"docs\">Audio Encoder Command:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"AUDIO_ENCODER",
				      -value=>@$row[14]}));
	print "</tr>\n";

	#
	# Audio Extension
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_audio_extension\" target=\"docs\">Audio Extension:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>5,-maxlength=>8,-type=>"text",
				      -name=>"AUDIO_EXTENSION",
				      -value=>@$row[15]}));
	print "</tr>\n";

	#
	# Audio Mimetype
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_audio_mimetype\" target=\"docs\">Audio Mimetype:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"AUDIO_MIMETYPE",
				      -value=>@$row[16]}));
	print "</tr>\n";

	#
	# Video Encoder
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_video_encoder\" target=\"docs\">Video Encoder Command:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"VIDEO_ENCODER",
				      -value=>@$row[17]}));
	print "</tr>\n";

	#
	# Video Extension
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_video_extension\" target=\"docs\">Video Extension:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>5,-maxlength=>8,-type=>"text",
				      -name=>"VIDEO_EXTENSION",
				      -value=>@$row[18]}));
	print "</tr>\n";

	#
	# Video Mimetype
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_video_mimetype\" target=\"docs\">Video Mimetype:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-size=>60,-maxlength=>255,-type=>"text",
				      -name=>"VIDEO_MIMETYPE",
				      -value=>@$row[19]}));
	print "</tr>\n";

	#
	# Audio Samplerate
	#
#	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
#	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_audio_samplerate\" target=\"docs\">Force Audio Sample Rate To:</a></strong>");
#	print $post->td({-colspan=>2,-align=>"left"},
#			$post->input({-size=>6,-maxlength=>6,-type=>"text",
#				      -name=>"AUDIO_SAMPLERATE",
#				      -value=>@$row[19]}));
#	print "</tr>\n";

	#
	# Audio Channels
	#
#	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
#	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#tap_audio_channels\" target=\"docs\">Force Audio Channels To:</a></strong>");
#	print $post->td({-colspan=>2,-align=>"left"},
#			$post->input({-size=>6,-maxlength=>6,-type=>"text",
#				      -name=>"AUDIO_CHANNELS",
#				      -value=>@$row[20]}));
#	print "</tr>\n";

	#
	# Header XML
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#tap_header_xml\" target=\"docs\">Header Template:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->textarea({-cols=>"60",-rows=>"4",
				      -name=>"HEADER_XML",
				      -value=>@$row[22]}));
	print "</tr>\n";

	#
	# Channel XML
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#tap_channel_xml\" target=\"docs\">Channel Template:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->textarea({-cols=>"60",-rows=>"4",
				      -name=>"CHANNEL_XML",
				      -value=>@$row[23]}));
	print "</tr>\n";

	#
	# Item XML
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#tap_item_xml\" target=\"docs\">Item Template:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->textarea({-cols=>"60",-rows=>"4",
				      -name=>"ITEM_XML",
				      -value=>@$row[24]}));
	print "</tr>\n";

	#
	# Footer XML
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right",-valign=>"top"},"<strong><a href=\"admin-doc.html#tap_footer_xml\" target=\"docs\">Footer Template:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->textarea({-cols=>"60",-rows=>"4",
				      -name=>"FOOTER_XML",
				      -value=>@$row[25]}));
	print "</tr>\n";

	#
	# OK Button
	#
	print "<tr>\n";
	print $post->input({-type=>"hidden",-name=>"TITLE",
			    -value=>$post->param("TITLE")});
	print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
			    -value=>$post->param("DESCRIPTION")});
	print $post->input({-type=>"hidden",-name=>"CATEGORY",
			    -value=>$post->param("CATEGORY")});
	print $post->input({-type=>"hidden",-name=>"LINK",
			    -value=>$post->param("LINK")});
	print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
			    -value=>$post->param("COPYRIGHT")});
	print $post->input({-type=>"hidden",-name=>"WEBMASTER",
			    -value=>$post->param("WEBMASTER")});
	print $post->input({-type=>"hidden",-name=>"AUTHOR",
			    -value=>$post->param("AUTHOR")});
	print $post->input({-type=>"hidden",-name=>"OWNER",
			    -value=>$post->param("OWNER")});
	print $post->input({-type=>"hidden",-name=>"OWNER_EMAIL",
			    -value=>$post->param("OWNER_EMAIL")});
	print $post->input({-type=>"hidden",-name=>"SUBTITLE",
			    -value=>$post->param("SUBTITLE")});
	print $post->input({-type=>"hidden",-name=>"CATEGORY_ITUNES",
			    -value=>$post->param("CATEGORY_ITUNES")});
	print $post->input({-type=>"hidden",-name=>"KEYWORDS",
			    -value=>$post->param("KEYWORDS")});
	print $post->input({-type=>"hidden",-name=>"EXPLICIT",
			    -value=>$post->param("EXPLICIT")});
	print $post->input({-type=>"hidden",-name=>"LANGUAGE",
			    -value=>$post->param("LANGUAGE")});
	print $post->input({-type=>"hidden",-name=>"MAX_UPLOAD_SIZE",
			    -value=>$post->param("MAX_UPLOAD_SIZE")});
	print $post->td({-align=>"left"},
			$post->input({-type=>"submit",-value=>"OK"}));
	print "</form>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_CHANNEL});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>@$row[0]});
	print $post->input({-type=>"hidden",-name=>"TITLE",
			    -value=>$post->param("TITLE")});
	print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
			    -value=>$post->param("DESCRIPTION")});
	print $post->input({-type=>"hidden",-name=>"CATEGORY",
			    -value=>$post->param("CATEGORY")});
	print $post->input({-type=>"hidden",-name=>"LINK",
			    -value=>$post->param("LINK")});
	print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
			    -value=>$post->param("COPYRIGHT")});
	print $post->input({-type=>"hidden",-name=>"WEBMASTER",
			    -value=>$post->param("WEBMASTER")});
	print $post->input({-type=>"hidden",-name=>"LANGUAGE",
			    -value=>$post->param("LANGUAGE")});
	print $post->input({-type=>"hidden",-name=>"AUTHOR",
			    -value=>$post->param("AUTHOR")});
	print $post->input({-type=>"hidden",-name=>"OWNER",
			    -value=>$post->param("OWNER")});
	print $post->input({-type=>"hidden",-name=>"OWNER_EMAIL",
			    -value=>$post->param("OWNER_EMAIL")});
	print $post->input({-type=>"hidden",-name=>"SUBTITLE",
			    -value=>$post->param("SUBTITLE")});
	print $post->input({-type=>"hidden",-name=>"CATEGORY_ITUNES",
			    -value=>$post->param("CATEGORY_ITUNES")});
	print $post->input({-type=>"hidden",-name=>"KEYWORDS",
			    -value=>$post->param("KEYWORDS")});
	print $post->input({-type=>"hidden",-name=>"EXPLICIT",
			    -value=>$post->param("EXPLICIT")});
	print $post->input({-type=>"hidden",-name=>"MAX_UPLOAD_SIZE",
			    -value=>$post->param("MAX_UPLOAD_SIZE")});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";
    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub CommitEditTap {
    $tap_id=$post->param("TAP_ID");
    my $sql=sprintf "update TAPS set \
                     TITLE=\"%s\",\
                     VISIBILITY_WINDOW=%d,\
                     HEADER_XML=\"%s\",\
                     CHANNEL_XML=\"%s\",\
                     ITEM_XML=\"%s\",\
                     FOOTER_XML=\"%s\",\
                     UPLOAD_URL=\"%s\",\
                     UPLOAD_USERNAME=\"%s\",\
                     UPLOAD_PASSWORD=\"%s\",\
                     DOWNLOAD_URL=\"%s\",\
                     DOWNLOAD_MIMETYPE=\"%s\",\
                     DOWNLOAD_PREAMBLE=\"%s\",\
                     PING_URL=\"%s\",\
                     VALIDATION_URL=\"%s\",\
                     LAST_BUILD_DATETIME=now(),\
                     IS_TRANSPARENT=\"%s\",\
                     AUDIO_ENCODER=\"%s\",\
                     AUDIO_EXTENSION=\"%s\",\
                     AUDIO_MIMETYPE=\"%s\",\
                     VIDEO_ENCODER=\"%s\",\
                     VIDEO_EXTENSION=\"%s\",\
                     VIDEO_MIMETYPE=\"%s\" \
                     where ID=%d",
		     &EscapeString($post->param("TAP_TITLE")),
		     $post->param("VISIBILITY_WINDOW"),
		     &EscapeString($post->param("HEADER_XML")),
		     &EscapeString($post->param("CHANNEL_XML")),
		     &EscapeString($post->param("ITEM_XML")),
		     &EscapeString($post->param("FOOTER_XML")),
		     &EscapeString($post->param("UPLOAD_URL")),
		     &EscapeString($post->param("UPLOAD_USERNAME")),
		     &EscapeString($post->param("UPLOAD_PASSWORD")),
		     &EscapeString($post->param("DOWNLOAD_URL")),
		     &EscapeString($post->param("DOWNLOAD_MIMETYPE")),
		     &EscapeString($post->param("DOWNLOAD_PREAMBLE")),
		     &EscapeString($post->param("PING_URL")),
		     &EscapeString($post->param("VALIDATION_URL")),
		     &EscapeString($post->param("IS_TRANSPARENT")),
		     &EscapeString($post->param("AUDIO_ENCODER")),
		     &EscapeString($post->param("AUDIO_EXTENSION")),
		     &EscapeString($post->param("AUDIO_MIMETYPE")),
		     &EscapeString($post->param("VIDEO_ENCODER")),
		     &EscapeString($post->param("VIDEO_EXTENSION")),
		     &EscapeString($post->param("VIDEO_MIMETYPE")),
		     $tap_id;
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeDeleteTap {
    my $channel_name=$post->param("CHANNEL_NAME");
    my $tap_id=$post->param("TAP_ID");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Delete Tap");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Are you sure that you want to delete this tap?");
    print "</tr>\n";

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_DELETE_TAP});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>TAP_ID,
			-value=>$tap_id});
    print $post->input({-type=>"hidden",-name=>"TITLE",
			-value=>$post->param("TITLE")});
    print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
			-value=>$post->param("DESCRIPTION")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY",
			-value=>$post->param("CATEGORY")});
    print $post->input({-type=>"hidden",-name=>"LINK",
			-value=>$post->param("LINK")});
    print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
			-value=>$post->param("COPYRIGHT")});
    print $post->input({-type=>"hidden",-name=>"WEBMASTER",
			-value=>$post->param("WEBMASTER")});
    print $post->input({-type=>"hidden",-name=>"AUTHOR",
			-value=>$post->param("AUTHOR")});
    print $post->input({-type=>"hidden",-name=>"OWNER",
			-value=>$post->param("OWNER")});
    print $post->input({-type=>"hidden",-name=>"OWNER_EMAIL",
			-value=>$post->param("OWNER_EMAIL")});
    print $post->input({-type=>"hidden",-name=>"SUBTITLE",
			-value=>$post->param("SUBTITLE")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY_ITUNES",
			-value=>$post->param("CATEGORY_ITUNES")});
    print $post->input({-type=>"hidden",-name=>"KEYWORDS",
			-value=>$post->param("KEYWORDS")});
    print $post->input({-type=>"hidden",-name=>"EXPLICIT",
			-value=>$post->param("EXPLICIT")});
    print $post->input({-type=>"hidden",-name=>"LANGUAGE",
			-value=>$post->param("LANGUAGE")});
    print $post->input({-type=>"hidden",-name=>"MAX_UPLOAD_SIZE",
			-value=>$post->param("MAX_UPLOAD_SIZE")});
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"Yes"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_EDIT_CHANNEL});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>"TITLE",
			-value=>$post->param("TITLE")});
    print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
			-value=>$post->param("DESCRIPTION")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY",
			-value=>$post->param("CATEGORY")});
    print $post->input({-type=>"hidden",-name=>"LINK",
			-value=>$post->param("LINK")});
    print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
			-value=>$post->param("COPYRIGHT")});
    print $post->input({-type=>"hidden",-name=>"WEBMASTER",
			-value=>$post->param("WEBMASTER")});
    print $post->input({-type=>"hidden",-name=>"AUTHOR",
			-value=>$post->param("AUTHOR")});
    print $post->input({-type=>"hidden",-name=>"OWNER",
			-value=>$post->param("OWNER")});
    print $post->input({-type=>"hidden",-name=>"OWNER_EMAIL",
			-value=>$post->param("OWNER_EMAIL")});
    print $post->input({-type=>"hidden",-name=>"SUBTITLE",
			-value=>$post->param("SUBTITLE")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY_ITUNES",
			-value=>$post->param("CATEGORY_ITUNES")});
    print $post->input({-type=>"hidden",-name=>"KEYWORDS",
			-value=>$post->param("KEYWORDS")});
    print $post->input({-type=>"hidden",-name=>"EXPLICIT",
			-value=>$post->param("EXPLICIT")});
    print $post->input({-type=>"hidden",-name=>"LANGUAGE",
			-value=>$post->param("LANGUAGE")});
    print $post->input({-type=>"hidden",-name=>"MAX_UPLOAD_SIZE",
			-value=>$post->param("MAX_UPLOAD_SIZE")});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"No"}));
    print "</form>\n";

    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitDeleteTap {
    my $post_count=0;
    my $channel_name=$post->param("CHANNEL_NAME");
    my $tap_id=$post->param("TAP_ID");

    my $sql=sprintf "select POST_ID,URL from UPLOADS where TAP_ID=%d",$tap_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    while(my $row=$q->fetchrow_arrayref) {
	$sql=sprintf "insert into JOBS set POST_ID=%u,TAP_ID=%u,PATH=\"%s\",\
                      STATUS=%d",
	     @$row[0],$tap_id,@$row[1],JOB_STATE_TAP_DELETION_QUEUED;
	my $q1=$dbh->prepare($sql);
	$q1->execute();
	$q1->finish();
	$post_count++;
    }
    $q->finish();

    if($post_count==0) {  # Delete right now
	$sql=sprintf "delete from TAPS where ID=%d",$tap_id;
	$q=$dbh->prepare($sql);
	$q->execute();
	$q->finish();
    }
    else {  # Otherwise mark it for later deletion
	$sql=sprintf "update TAPS set DELETING=\"Y\" where ID=%d",$tap_id;
	$q=$dbh->prepare($sql);
	$q->execute();
	$q->finish();
    }
}


sub ServeAddThumbnail {
    my $channel_name=$post->param("CHANNEL_NAME");

    #
    # Verify channel authorization
    #
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    #
    # Render form
    #
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->script({-type=>"text/javascript",-src=>"admin.js"},"");
    print $post->script({-type=>"text/javascript",-src=>"utils.js"},"");
    print $post->title("Loudwater Add Thumbnail");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr><td id=\"bigframe\">\n";

    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Loudwater Add Thumbnail</big></big>");
    print "</tr>\n";

    print "<form action=\"admin.pl\" method=\"post\" enctype=\"multipart/form-data\" onsubmit=\"PostCast()\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_ADD_THUMBNAIL});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});

    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-align=>"right"},
		    sprintf "<strong>Thumbnail Image:</strong>",$i+1);
    print "<td align=\"left\">\n";
    print $post->input({-id=>"mediafile",-type=>"file",-name=>"MEDIAFILE"});
    print "</td>\n";
    print "</tr>\n";

    print "<tr>\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"submit",-value=>"Upload"});
    print "</td>\n";
    print "</form>\n";
    
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"right\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_THUMBNAILS});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Cancel"});
    print "</td>\n";
    print "</form>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</td></tr>\n";

    print "</table>\n";
    print "</body>\n";
    print "</html>\n";
}


sub CommitAddThumbnail {
    my $channel_name=$post->param("CHANNEL_NAME");

    #
    # Verify channel authorization
    #
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    #
    # Get the channel record
    #
    my $sql=sprintf "select MAX_UPLOAD_SIZE,THUMBNAIL_UPLOAD_URL,\
                     THUMBNAIL_UPLOAD_USERNAME,THUMBNAIL_UPLOAD_PASSWORD,\
                     THUMBNAIL_DOWNLOAD_URL from CHANNELS where NAME=\"%s\"",
		     &EscapeString($channel_name);
    my $q=$dbh->prepare($sql);
    $q->execute();
    my $row;
    if(!($row=$q->fetchrow_arrayref)) {
	$q->finish();
	CgiError("no such channel");
    }
    $CGI::POST_MAX=@$row[0];

    #
    # Validate uploaded files
    #
    my $filename=$post->param("MEDIAFILE");
    if($filename eq "") {
	$q->finish();
	CgiError(sprintf "File %s is too large!",$filename);
    }
    my($name,$path,$extension)=fileparse($filename,'\..*');
    $_=$extension;
    s{\.}{}g;
    $extension=$_;

    #
    # Generate thumbnail record
    #
    $sql=sprintf "insert into THUMBNAILS set \
                  CHANNEL_NAME=\"%s\"",$channel_name;
    my $q1=$dbh->prepare($sql);
    $q1->execute();
    $q1->finish();
    my $thumbnail_id=$dbh->{q{mysql_insertid}};
    my $upload_url=sprintf "%s/tn%06u.%s",@$row[1],$thumbnail_id,$extension;
    my $download_url=sprintf "%s/tn%06u.%s",@$row[4],$thumbnail_id,$extension;

    #
    # Send image to destination
    #
    my $curl=new WWW::Curl::Easy;
    $curl->setopt(CURLOPT_READDATA,$post->upload("MEDIAFILE"));
    $curl->setopt(CURLOPT_URL,$upload_url);
    $curl->setopt(CURLOPT_UPLOAD,1);
    $curl->setopt(CURLOPT_FTP_FILEMETHOD,CURLFTPMETHOD_MULTICWD);
    $curl->setopt(CURLOPT_USERPWD,sprintf "%s:%s",@$row[2],@$row[3]);
    my $curl_err=$curl->perform;
    if($curl_err!=0) {
	$sql=sprintf "delete from THUMBNAILS where ID=%u",$thumbnail_id;
	$q1=$dbh->prepare($sql);
	$q1->execute();
	$q1->finish();
	CgiError(sprintf "Thumbnail transfer error: %s",
		 $curl->strerror($curl_err));
    }

    #
    # Update thumbnail record
    #
    $sql=sprintf "update THUMBNAILS set FILENAME=\"tn%06u.%s\" where ID=%u",
                  $thumbnail_id,$extension,$thumbnail_id;
    $q1=$dbh->prepare($sql);
    $q1->execute();
    $q1->finish();
}


sub ServeListThumbnails {
    my $column=1;
    my $channel_name=$post->param("CHANNEL_NAME");
    my $post_id=$post->param("POST_ID");
    my $thumbnail_id=$post->param("THUMBNAIL_ID");
    my $manage=$_[0];

    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Thumbnails");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr><td id=\"bigframe\">\n";

    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";

    #
    # Verify channel authorization
    #
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    #
    # Display thumbnails
    #
    $sql=sprintf "select THUMBNAILS.ID,CHANNELS.THUMBNAIL_DOWNLOAD_URL,\
                  THUMBNAILS.FILENAME from THUMBNAILS left join CHANNELS \
                  on CHANNELS.NAME=THUMBNAILS.CHANNEL_NAME \
                  where CHANNELS.NAME=\"%s\"",
                  $channel_name;
    $q=$dbh->prepare($sql);
    $q->execute();

    print "<tr>\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "<big><big>Loudwater Thumbnails</big></big>");
    print "</tr>\n";

    print "<tr><td colspan=\"2\">\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"1\">\n";
    while(my $row=$q->fetchrow_arrayref) {
	if($column) {
	    print "<tr>\n";
	}
	print "<td align=\"center\"><table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
	print "<tr>\n";
	if($thumbnail_id==@$row[0]) {
	    print $post->td({-colspan=>2,-align=>"center",-valign=>"bottom"},
			    $post->img({-border=>6,
					-src=>@$row[1]."/".@$row[2]}));
	}
	else {
	    print $post->td({-colspan=>2,-align=>"center",-valign=>"bottom"},
			    $post->img({-border=>1,
					-src=>@$row[1]."/".@$row[2]}));
	}
	print "<tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td align=\"left\">\n";
	if($thumbnail_id==@$row[0]) {
	    print "<td align=\"center\">\n";
	    print $post->input({-type=>"hidden",-name=>SESSION_ID,
				-value=>$session_id});
	    if($manage) {
		print $post->input({-type=>"hidden",-name=>COMMAND,
				    -value=>COMMAND_SET_DEFAULT_THUMBNAIL});
		print $post->input({-type=>"hidden",-name=>"EXPLICIT",
				    -value=>$post->param("EXPLICIT")});
	    }
	    else {
		print $post->input({-type=>"hidden",-name=>"SHORT_DESCRIPTION",
				    -value=>$post->param("SHORT_DESCRIPTION")});
		print $post->input({-type=>"hidden",-name=>"POST_ACTIVE",
				    -value=>$post->param("POST_ACTIVE")});
	    }
	    print $post->input({-type=>"hidden",-name=>COMMAND,
				-value=>COMMAND_COMMIT_SELECT_THUMBNAIL});
	    print $post->input({-type=>"hidden",-name=>POST_ID,
				-value=>$post_id});
	    print $post->input({-type=>"hidden",-name=>"TITLE",
				-value=>$post->param("TITLE")});
	    print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
				-value=>$post->param("DESCRIPTION")});
	    print $post->input({-type=>"hidden",-name=>"CATEGORY",
				-value=>$post->param("CATEGORY")});
	    print $post->input({-type=>"hidden",-name=>"LINK",
				-value=>$post->param("LINK")});
	    print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
				-value=>$post->param("COPYRIGHT")});
	    print $post->input({-type=>"hidden",-name=>"WEBMASTER",
				-value=>$post->param("WEBMASTER")});
	    print $post->input({-type=>"hidden",-name=>"AUTHOR",
				-value=>$post->param("AUTHOR")});
	    print $post->input({-type=>"hidden",-name=>"KEYWORDS",
				-value=>$post->param("KEYWORDS")});
	    print $post->input({-type=>"hidden",-name=>"COMMENTS",
				-value=>$post->param("COMMENTS")});
	    print $post->input({-type=>"hidden",-name=>"LANGUAGE",
				-value=>$post->param("LANGUAGE")});
	    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
				-value=>$channel_name});
	    print $post->input({-type=>"hidden",-name=>THUMBNAIL_ID,
				-value=>0});
	    if($manage) {
		print $post->input({-type=>"submit",-value=>"Clear Default"});
	    }
	    else {
		print $post->input({-type=>"submit",-value=>"Unselect"});
	    }
	    printf "</td>\n";
	}
	else {
	    print $post->input({-type=>"hidden",-name=>SESSION_ID,
				-value=>$session_id});
	    if($manage) {
		print $post->input({-type=>"hidden",-name=>COMMAND,
				    -value=>COMMAND_SET_DEFAULT_THUMBNAIL});
		print $post->input({-type=>"hidden",-name=>"EXPLICIT",
				    -value=>$post->param("EXPLICIT")});
	    }
	    else {
		print $post->input({-type=>"hidden",-name=>COMMAND,
				    -value=>COMMAND_COMMIT_SELECT_THUMBNAIL});
		print $post->input({-type=>"hidden",-name=>POST_ID,
				    -value=>$post_id});
		print $post->input({-type=>"hidden",-name=>"SHORT_DESCRIPTION",
				    -value=>$post->param("SHORT_DESCRIPTION")});
		print $post->input({-type=>"hidden",-name=>"POST_ACTIVE",
				    -value=>$post->param("POST_ACTIVE")});
	    }
	    print $post->input({-type=>"hidden",-name=>"TITLE",
				-value=>$post->param("TITLE")});
	    print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
				-value=>$post->param("DESCRIPTION")});
	    print $post->input({-type=>"hidden",-name=>"CATEGORY",
				-value=>$post->param("CATEGORY")});
	    print $post->input({-type=>"hidden",-name=>"LINK",
				-value=>$post->param("LINK")});
	    print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
				-value=>$post->param("COPYRIGHT")});
	    print $post->input({-type=>"hidden",-name=>"WEBMASTER",
				-value=>$post->param("WEBMASTER")});
	    print $post->input({-type=>"hidden",-name=>"AUTHOR",
				-value=>$post->param("AUTHOR")});
	    print $post->input({-type=>"hidden",-name=>"KEYWORDS",
				-value=>$post->param("KEYWORDS")});
	    print $post->input({-type=>"hidden",-name=>"AIR_DATE",
				-value=>&LocaleDatetime($post->
							param("AIR_DATE"))});
	    print $post->input({-type=>"hidden",-name=>"AIR_HOUR",
				-value=>$post->param("AIR_HOUR")});
	    print $post->input({-type=>"hidden",-name=>"COMMENTS",
				-value=>$post->param("COMMENTS")});
	    print $post->input({-type=>"hidden",-name=>"LANGUAGE",
				-value=>$post->param("LANGUAGE")});
	    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
				-value=>$channel_name});
	    print $post->input({-type=>"hidden",-name=>THUMBNAIL_ID,
				-value=>@$row[0]});
	    if($manage) {
		print $post->input({-type=>"submit",-value=>"Make Default"});
	    }
	    else {
		print $post->input({-type=>"submit",-value=>"Select"});
	    }
	}
	print "</td>\n";
	print "</form>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td align=\"right\">\n";
	if($thumbnail_id==@$row[0]) {
	    print "&nbsp;";
	}
	else {
	    print $post->input({-type=>"hidden",-name=>SESSION_ID,
				-value=>$session_id});
	    if($manage) {
		print $post->input({-type=>"hidden",-name=>COMMAND,
				    -value=>COMMAND_DELETE_THUMBNAIL});
	    }
	    else {
		print $post->input({-type=>"hidden",-name=>COMMAND,
				    -value=>COMMAND_COMMIT_SELECT_THUMBNAIL});
		print $post->input({-type=>"hidden",-name=>POST_ID,
				    -value=>$post_id});
	    }
	    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
				-value=>$channel_name});
	    print $post->input({-type=>"hidden",-name=>THUMBNAIL_ID,
				-value=>@$row[0]});
	    if($manage) {
		print $post->input({-type=>"submit",-value=>"Delete Image"});
	    }
	    else {
		print "&nbsp;";
	    }
	}
	print "</td>\n";
	print "</form>\n";

	print "</tr>\n";
	print "</tr></td></table>\n";
	if(!$column) {
	    print "</tr>\n";
	}
	$column=!$column;
    }
    if(!$column) {
	print "</tr>\n";
    }

    print "</td></tr></table>\n";

    print "<tr>\n";
    if($manage) {
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td align=\"left\" align=\"right\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_ADD_THUMBNAIL});
	print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			    -value=>$channel_name});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"submit",-value=>"Add Image"});
	print "</td>\n";
	print "</form>\n";
    }
    else {
	print $post->td("&nbsp;");
    }

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"right\" align=\"right\">\n";
    if($manage) {
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_CHANNEL});
	print $post->input({-type=>"hidden",-name=>"EXPLICIT",
			    -value=>$post->param("EXPLICIT")});
    }
    else {
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_POST});
	print $post->input({-type=>"hidden",-name=>POST_ID,
			    -value=>$post_id});
	print $post->input({-type=>"hidden",-name=>"SHORT_DESCRIPTION",
			    -value=>$post->param("SHORT_DESCRIPTION")});
	print $post->input({-type=>"hidden",-name=>"POST_ACTIVE",
			    -value=>$post->param("POST_ACTIVE")});
    }
    print $post->input({-type=>"hidden",-name=>"TITLE",
			-value=>$post->param("TITLE")});
    print $post->input({-type=>"hidden",-name=>"DESCRIPTION",
			-value=>$post->param("DESCRIPTION")});
    print $post->input({-type=>"hidden",-name=>"CATEGORY",
			-value=>$post->param("CATEGORY")});
    print $post->input({-type=>"hidden",-name=>"LINK",
			-value=>$post->param("LINK")});
    print $post->input({-type=>"hidden",-name=>"COPYRIGHT",
			-value=>$post->param("COPYRIGHT")});
    print $post->input({-type=>"hidden",-name=>"WEBMASTER",
			-value=>$post->param("WEBMASTER")});
    print $post->input({-type=>"hidden",-name=>"AUTHOR",
			-value=>$post->param("AUTHOR")});
    print $post->input({-type=>"hidden",-name=>"KEYWORDS",
			-value=>$post->param("KEYWORDS")});
    print $post->input({-type=>"hidden",-name=>"AIR_DATE",
			-value=>&LocaleDatetime($post->param("AIR_DATE"))});
    print $post->input({-type=>"hidden",-name=>"AIR_HOUR",
			-value=>$post->param("AIR_HOUR")});
    print $post->input({-type=>"hidden",-name=>"COMMENTS",
			-value=>$post->param("COMMENTS")});
    print $post->input({-type=>"hidden",-name=>"LANGUAGE",
			-value=>$post->param("LANGUAGE")});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";
    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub ServeDeleteThumbnail {
    my $channel_name=$post->param("CHANNEL_NAME");
    my $thumbnail_id=$post->param("THUMBNAIL_ID");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Delete Thumbnail");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Are you sure that you want to delete this image?");
    print "</tr>\n";

    my $sql=sprintf "select CHANNELS.THUMBNAIL_DOWNLOAD_URL,THUMBNAILS.FILENAME\
                     from THUMBNAILS left join CHANNELS \
                     on THUMBNAILS.CHANNEL_NAME=CHANNELS.NAME \
                     where THUMBNAILS.ID=%u",$thumbnail_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	print "<tr>\n";
	print $post->td({-colspan=>2,-align=>"center"},
			$post->img({-border=>1,-src=>@$row[0]."/".@$row[1]}));
	print "</tr>\n";
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_DELETE_THUMBNAIL});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->input({-type=>"hidden",-name=>THUMBNAIL_ID,
			-value=>$thumbnail_id});
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"Yes"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_THUMBNAILS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>CHANNEL_NAME,
			-value=>$channel_name});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"No"}));
    print "</form>\n";

    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub CommitDeleteThumbnail {
    my $channel_name=$post->param("CHANNEL_NAME");
    my $thumbnail_id=$post->param("THUMBNAIL_ID");

    #
    # Verify channel authorization
    #
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }

    #
    # Check for usage
    #
    my $sql=sprintf "select ID from POSTS where THUMBNAIL_ID=%u",$thumbnail_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    my $row;
    if(!$q->fetchrow_arrayref) {
	&DeleteThumbnail($thumbnail_id);
	&ServeListThumbnails;
	exit 0;
    }
    $q->finish();
}


sub DeleteThumbnail {
    my $thumbnail_id=$_[0];
    my $sql=sprintf "select CHANNELS.THUMBNAIL_UPLOAD_URL,THUMBNAILS.FILENAME,\
                     CHANNELS.THUMBNAIL_UPLOAD_USERNAME,\
                     CHANNELS.THUMBNAIL_UPLOAD_PASSWORD \
                     from CHANNELS left join THUMBNAILS \
                     on CHANNELS.NAME=THUMBNAILS.CHANNEL_NAME \
                     where THUMBNAILS.ID=%u",$thumbnail_id;
    my $q=$dbh->prepare($sql);
    $q->execute();
    my $row;
    if(!($row=$q->fetchrow_arrayref)) {
	$q->finish();
	return;
    }

    #
    # Delete image
    #
    my @parts=split "/",@$row[0];
    my $path;
    for($i=3;$i<($#parts+1);$i++) {
	$path=$path.$parts[$i];
    }
    my $curl=sprintf 
	"curl -Q \"cwd %s\" -Q \"dele %s\" -u \"%s:%s\" %s %s",
	$path,@$row[1],@$row[2],@$row[3],@$row[0];
    system $curl;

    #
    # Delete record
    #
    $sql=sprintf "delete from THUMBNAILS where ID=%u",$thumbnail_id;
    $q->finish();
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}

sub CommitDefaultThumbnail {
    $channel_name=$post->param("CHANNEL_NAME");
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }
    my $sql=sprintf "update CHANNELS set \
                     THUMBNAIL_ID=%d \
                     where NAME=\"%s\"",
		     $post->param("THUMBNAIL_ID"),
		     &EscapeString($channel_name);
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub CommitSelectThumbnails {
    $channel_name=$post->param("CHANNEL_NAME");
    $post_id=$post->param("POST_ID");
    $thumbnail_id=$post->param("THUMBNAIL_ID");
    if(!ChannelAuthorized($channel_name)) {
	print "Content-type: text/html\n\n";
	print "Channel not authorized\n";
	exit 0;
    }
    my $sql=sprintf "update POSTS set \
                     THUMBNAIL_ID=%d \
                     where ID=%u",$thumbnail_id,$post_id;
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeListFeedsets {
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Live Web Feeds");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql="select ID,SET_NAME,NAME,".
	"SUN,MON,TUE,WED,THU,FRI,SAT,START_TIME,END_TIME,".
	"MOUNT_POINT,TYPE from FEEDSETS order by SET_NAME,NAME";
    my $q=$dbh->prepare($sql);
    $q->execute();
    print "<tr>\n";
    print $post->td({-colspan=>14,-align=>"center"},
		    "<big><big>Loudwater Live Web Feeds</big></big>");
    print "</tr>\n";

    print "<tr>\n";
    print $post->th({-align=>"center"},"Feed Set");
    print $post->th({-align=>"center"},"Name");
    print $post->th({-align=>"center"},"Sun");
    print $post->th({-align=>"center"},"Mon");
    print $post->th({-align=>"center"},"Tue");
    print $post->th({-align=>"center"},"Wed");
    print $post->th({-align=>"center"},"Thu");
    print $post->th({-align=>"center"},"Fri");
    print $post->th({-align=>"center"},"Sat");
    print $post->th({-align=>"center"},"Start");
    print $post->th({-align=>"center"},"End");
    print $post->th({-align=>"center"},"Mount Point");
    print $post->th({-align=>"center"},"&nbsp;");
    print $post->th({-align=>"center"},"&nbsp;");
    print "</tr>\n";
    my $bgcolor=BGCOLOR1;
    while(my $row=$q->fetchrow_arrayref) {
	printf "<tr bgcolor=\"%s\">\n",$bgcolor;
	print $post->td({-align=>"left"},@$row[1]);  # SET_NAME
	print $post->td({-align=>"left"},@$row[2]);  # NAME
	print $post->td({-align=>"center"},@$row[3]);  # SUN
	print $post->td({-align=>"center"},@$row[4]);  # MON
	print $post->td({-align=>"center"},@$row[5]);  # TUE
	print $post->td({-align=>"center"},@$row[6]);  # WED
	print $post->td({-align=>"center"},@$row[7]);  # THU
	print $post->td({-align=>"center"},@$row[8]);  # FRI
	print $post->td({-align=>"center"},@$row[9]);  # SAT
	print $post->td({-align=>"left"},@$row[10]); # START_TIME
	print $post->td({-align=>"left"},@$row[11]); # END_TIME
	print $post->td({-align=>"left"},@$row[12]); # MOUNT_POINT

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_EDIT_FEED});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>FEEDSET_ID,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Edit});
	print "</td>\n";
	print "</form>\n";
	print "<form action=\"admin.pl\" method=\"post\">\n";
	print "<td>\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_DELETE_FEED});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>FEEDSET_ID,
			    -value=>@$row[0]});
	print $post->input({-type=>"submit",-value=>Delete});
	print "</td>\n";
	print "</form>\n";
	print "</tr>\n";

	if($bgcolor eq BGCOLOR1) {
	    $bgcolor=BGCOLOR2;
	}
	else {
	    $bgcolor=BGCOLOR1;
	}
    }
    $q->finish();

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_ADD_FEED});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Add Feed"});
    print "</td>\n";
    print "</form>\n";

    print $post->td({-colspan=>12},"&nbsp;");
	
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print "<td align=\"left\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_MAIN_MENU});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"submit",-value=>"Close"});
    print "</td>\n";
    print "</form>\n";
    print "</tr>\n";
	
    print "</table>\n";
    print "</body>\n";

    exit 0;
}


sub AddFeed {
    my $sql="insert into FEEDSETS set ".
	"SET_NAME=\"[set]\",".
	"NAME=\"[new feed]\",".
	"MOUNT_POINT=\"\",".
	"TYPE=\"icecast2\",".
	"START_TIME=\"00:00:00\",".
	"END_TIME=\"23:59:59\"";
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();

    $new_feedset_id=$dbh->{q{mysql_insertid}};
}


sub ServeEditFeed {
    my $feedset_id=$new_feedset_id;
    if($feedset_id==0) {
	$feedset_id=$post->param("FEEDSET_ID");
    }
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Edit Live Feed");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    my $sql="select SET_NAME,SUN,MON,TUE,WED,THU,FRI,SAT,".
	"START_TIME,END_TIME,NAME,MOUNT_POINT,TYPE,LOGO_LINK from FEEDSETS ".
	sprintf("where ID=%d",$feedset_id);

    my $q=$dbh->prepare($sql);
    $q->execute();
    if(my $row=$q->fetchrow_arrayref) {
	#
	# Page Title
	#
	print "<tr>\n";
	print $post->td({-colspan=>3,-align=>"center"},
			"<big><big>Edit Live Feed</big></big>");
	print "</tr>\n";

	print "<form action=\"admin.pl\" method=\"post\">\n";
	print $post->input({-type=>"hidden",-name=>COMMAND,
			    -value=>COMMAND_COMMIT_EDIT_FEED});
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->input({-type=>"hidden",-name=>FEEDSET_ID,
			    -value=>$feedset_id});

	#
	# Feed Set Name
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#set_name\" target=\"docs\">Set Name:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>8,-maxlength=>8,
				      -name=>SET_NAME,-value=>@$row[0]}));
	print "</tr>\n";

	#
	# Mount Point Name
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#mount_point_name\" target=\"docs\">Mount Point Name:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>60,-maxlength=>64,
				      -name=>NAME,-value=>@$row[10]}));
	print "</tr>\n";

	#
	# Mount Point
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#mount_point\" target=\"docs\">Mount Point:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>60,-maxlength=>255,
				      -name=>MOUNT_POINT,-value=>@$row[11]}));
	print "</tr>\n";

	#
	# Logo Link URL
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#logo_link\" target=\"docs\">Logo Link:</a></strong>");
	print $post->td({-colspan=>2,-align=>"left"},
			$post->input({-type=>"text",-size=>60,-maxlength=>255,
				      -name=>LOGO_LINK,-value=>@$row[13]}));
	print "</tr>\n";

	#
	# Start Time
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#start_time\" target=\"docs\">Start Time:</a></strong>");
	print "<td colspan=\"2\" align=\"left\">";
	&ServeTimeControl("START_TIME",@$row[8]);
	print "</td>\n";
	print "</tr>\n";

	#
	# End Time
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-align=>"right"},"<strong><a href=\"admin-doc.html#end_time\" target=\"docs\">End Time:</a></strong>");
	print "<td colspan=\"2\" align=\"left\">";
	&ServeTimeControl("END_TIME",@$row[9]);
	print "</td>\n";
	print "</tr>\n";

	#
	# Days of the Week
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print $post->td({-colspan=>3,-align=>"center"},
			"<strong><a href=\"admin-doc.html#run_on\" target=\"docs\">Run On</a></strong>");
	print "</tr>\n";

	#
	# Monday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print "<td align=\"right\">";
	&ServeCheckControl("MON",@$row[2]);
	print "</td>\n";
	print $post->td({-colspan=>2,-align=>"left"},"Monday");
	print "</tr>\n";

	#
	# Tuesday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print "<td align=\"right\">";
	&ServeCheckControl("TUE",@$row[3]);
	print "</td>\n";
	print $post->td({-colspan=>2,-align=>"left"},"Tuesday");
	print "</tr>\n";

	#
	# Wednesday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print "<td align=\"right\">";
	&ServeCheckControl("WED",@$row[4]);
	print "</td>\n";
	print $post->td({-colspan=>2,-align=>"left"},"Wednesday");
	print "</tr>\n";

	#
	# Thursday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print "<td align=\"right\">";
	&ServeCheckControl("THU",@$row[5]);
	print "</td>\n";
	print $post->td({-colspan=>2,-align=>"left"},"Thursday");
	print "</tr>\n";

	#
	# Friday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";	
	print "<td align=\"right\">";
	&ServeCheckControl("FRI",@$row[6]);
	print "</td>\n";
	print $post->td({-colspan=>2,-align=>"left"},"Friday");
	print "</tr>\n";

	#
	# Saturday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print "<td align=\"right\">";
	&ServeCheckControl("SAT",@$row[7]);
	print "</td>\n";
	print $post->td({-colspan=>2,-align=>"left"},"Saturday");
	print "</tr>\n";

	#
	# Sunday
	#
	print "<tr bgcolor=\"".BGCOLOR1."\">\n";
	print "<td align=\"right\">";
	&ServeCheckControl("SUN",@$row[8]);
	print "</td>\n";
	print $post->td({-colspan=>2,-align=>"left"},"Sunday");
	print "</tr>\n";

	#
	# OK Button
	#
	print "<tr>\n";
	print $post->td({-align=>"left"},
			$post->input({-type=>"submit",-value=>"OK"}));
	print "</form>\n";

	#
	# Cancel Button
	#
	print "<form action=\"admin.pl\" method=\"post\">\n";
	if($new_feedset_id eq 0) {
	    print $post->input({-type=>"hidden",-name=>COMMAND,
				-value=>COMMAND_LIST_FEEDSETS});
	}
	else {
	    print $post->input({-type=>"hidden",-name=>COMMAND,
				-value=>COMMAND_COMMIT_DELETE_FEED});
	    print $post->input({-type=>"hidden",-name=>FEEDSET_ID,
				-value=>$new_feedset_id});
	}
	print $post->input({-type=>"hidden",-name=>SESSION_ID,
			    -value=>$session_id});
	print $post->td({-align=>"right"},
			$post->input({-type=>"submit",-value=>"Cancel"}));
	print "</form>\n";
	print "</tr>\n";
    }
    $q->finish();
    print "</table>\n";
    print "</body>\n";
}


sub ServeCommitFeed {
    $feedset_id=$post->param("FEEDSET_ID");
    my $sql="update FEEDSETS set ".
	"SET_NAME=\"".&EscapeString($post->param("SET_NAME"))."\",".
	"NAME=\"".&EscapeString($post->param("NAME"))."\",".
	"MOUNT_POINT=\"".&EscapeString($post->param("MOUNT_POINT"))."\",".
	"LOGO_LINK=\"".&EscapeString($post->param("LOGO_LINK"))."\",".
	"TYPE=\"icecast2\",".
	"START_TIME=\"".&ReadTimeControl("START_TIME")."\",".
	"END_TIME=\"".&ReadTimeControl("END_TIME")."\",".
	"SUN=\"".&ReadCheckControl("SUN")."\",".
	"MON=\"".&ReadCheckControl("MON")."\",".
	"TUE=\"".&ReadCheckControl("TUE")."\",".
	"WED=\"".&ReadCheckControl("WED")."\",".
	"THU=\"".&ReadCheckControl("THU")."\",".
	"FRI=\"".&ReadCheckControl("FRI")."\",".
	"SAT=\"".&ReadCheckControl("SAT")."\" ".
	sprintf("where ID=%d",$post->param("FEEDSET_ID"));
    $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub ServeDeleteFeed {
    my $feedset_id=$post->param("FEEDSET_ID");
    print $post->header(-type=>'text/html');
    print "<head>\n";
    print $post->title("Loudwater Delete Feed");
    print "</head>\n";

    print "<body>\n";
    print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"0\">\n";
    print "<tr bgcolor=\"".BGCOLOR1."\">\n";
    print $post->td({-colspan=>2,-align=>"center"},
		    "Are you sure that you want to delete this feed?");
    print "</tr>\n";

    print "<tr>\n";
    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_COMMIT_DELETE_FEED});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->input({-type=>"hidden",-name=>FEEDSET_ID,
			-value=>$feedset_id});
    print $post->td({-align=>"left"},
		    $post->input({-type=>"submit",-value=>"Yes"}));
    print "</form>\n";

    print "<form action=\"admin.pl\" method=\"post\">\n";
    print $post->input({-type=>"hidden",-name=>COMMAND,
			-value=>COMMAND_LIST_FEEDSETS});
    print $post->input({-type=>"hidden",-name=>SESSION_ID,
			-value=>$session_id});
    print $post->td({-align=>"right"},
		    $post->input({-type=>"submit",-value=>"No"}));
    print "</form>\n";

    print "</tr>\n";

    print "</table>\n";
    print "</body>\n";
}


sub ServeCommitDeleteFeed {
    my $feedset_id=$post->param("FEEDSET_ID");
    my $sql=sprintf "delete from FEEDSETS where ID=%d",$feedset_id;

    my $q=$dbh->prepare($sql);
    $q->execute();
    $q->finish();
}


sub GetLoudwaterUrl {
    $_=$ENV{'SCRIPT_NAME'};
    s{admin.pl}{}g;
    @ii=split /\//,$ENV{'SERVER_PROTOCOL'};
    return lc($ii[0])."://".$ENV{'SERVER_NAME'}.$_;
}

#
# Open the database
#
$dbh=DBI->connect("dbi:mysql:$loudwater_db_dbname:$loudwater_db_hostname",
		  $loudwater_db_username,$loudwater_db_password);
if(!$dbh) {
    print $post->header(-type=>'text/html');
    print "unable to open database\n";
    exit 0;
}

#
# Process the form
#
$post=new CGI;

#    my @names=$post->param();
#    my $count=0;
#    print "Content-type: text/html\n\n";
#    while(defined @names[$count]) {
#	printf "header: %s<br>\n",@names[$count++];
#    }
#    exit 0;

$command=$post->param("COMMAND");

$authenticated=&Authenticate;
if(!$authenticated) {
    if(!&LogIn) {
	&ServeLogin;
	exit 0;
    }
}


#print "Content-type: text/html\n\n";
#printf "COMMAND: %d\n",$command;
#exit 0;


if($command eq COMMAND_MAIN_MENU) {
    &ServeMainMenu;
    exit 0;
}
if($command eq COMMAND_LIST_USERS) {
    &ServeListUsers;
    exit 0;
}
if($command eq COMMAND_ADD_USER) {
    &ServeAddUser;
    exit 0;
}
if($command eq COMMAND_COMMIT_ADD_USER) {
    &CommitAddUser;
    &ServeEditUser;
    exit 0;
}
if($command eq COMMAND_EDIT_USER) {
    &ServeEditUser;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_USER) {
    &CommitEditUser;
    &ServeListUsers;
    exit 0;
}
if($command eq COMMAND_DELETE_USER) {
    &ServeDeleteUser;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_USER) {
    &CommitDeleteUser;
    &ServeListUsers;
    exit 0;
}
if($command eq COMMAND_CHANGE_USER_PASSWORD) {
    &ServeChangeUserPassword;
    exit 0;
}
if($command eq COMMAND_COMMIT_CHANGE_USER_PASSWORD) {
    if(&CommitChangeUserPassword) {
	&ServeEditUser;
    }
    else {
	&ServeUserPasswordInvalid;
    }
    exit 0;
}
if($command eq COMMAND_LIST_PLAYERS) {
    &ServeListPlayers;
    exit 0;
}
if($command eq COMMAND_ADD_PLAYER) {
    &ServeAddPlayer;
    exit 0;
}
if($command eq COMMAND_COMMIT_ADD_PLAYER) {
    &CommitAddPlayer;
    &ServeEditPlayer;
    exit 0;
}
if($command eq COMMAND_EDIT_PLAYER) {
    &ServeEditPlayer;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_PLAYER) {
    &CommitEditPlayer;
    &ServeListPlayers;
    exit 0;
}
if($command eq COMMAND_DELETE_PLAYER) {
    &ServeDeletePlayer;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_PLAYER) {
    &CommitDeletePlayer;
    &ServeListPlayers;
    exit 0;
}
if($command eq COMMAND_LIST_LIVESEGMENTS) {
    &ServeListLivesegments;
    exit 0;
}
if($command eq COMMAND_COMMIT_ADD_LIVESEGMENT) {
    &CommitAddLivesegment;
    &ServeEditLivesegment;
    exit 0;
}
if($command eq COMMAND_EDIT_LIVESEGMENT) {
    &ServeEditLivesegment;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_LIVESEGMENT) {
    &CommitEditLivesegment;
    &ServeEditPlayer;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_LIVESEGMENT) {
    &CommitDeleteLivesegment;
    &ServeEditPlayer;
    exit 0;
}
if($command eq COMMAND_LIST_BUTTONS) {
    &ServeListButtons;
    exit 0;
}
if($command eq COMMAND_EDIT_BUTTON) {
    &ServeEditButton;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_BUTTON) {
    &CommitEditButton;
    &ServeListButtons;
    exit 0;
}
if($command eq COMMAND_LIST_CHANNELS) {
    &ServeListChannels;
    exit 0;
}
if($command eq COMMAND_ADD_CHANNEL) {
    &ServeAddChannel;
    exit 0;
}
if($command eq COMMAND_COMMIT_ADD_CHANNEL) {
    &CommitAddChannel;
    &ServeEditChannel;
    exit 0;
}
if($command eq COMMAND_EDIT_CHANNEL) {
    &ServeEditChannel;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_CHANNEL) {
    &CommitEditChannel;
    &ServeListChannels;
    exit 0;
}
if($command eq COMMAND_DELETE_CHANNEL) {
    &ServeDeleteChannel;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_CHANNEL) {
    &CommitDeleteChannel;
    &ServeListChannels;
    exit 0;
}
if($command eq COMMAND_EDIT_CHANNEL_PERMS) {
    &ServeEditChannelPerms;
    exit 0;
}
if($command eq COMMAND_COMMIT_CHANNEL_PERMS) {
    &CommitChannelPerms;
    &ServeEditUser;
    exit 0;
}
if($command eq COMMAND_LIST_CONTENT_CHANNELS) {
    &ServeListContentChannels;
    exit 0;
}
if($command eq COMMAND_LIST_CHANNEL_LINKS) {
    &ServeListChannelLinks;
    exit 0;
}
if($command eq COMMAND_LIST_POSTS) {
    &ServeListPosts;
    exit 0;
}
if($command eq COMMAND_ADD_POST) {
    &ServeAddPost;
    exit 0;
}
if($command eq COMMAND_UPLOAD_ADD_POST) {
    &ServeUploadAddPost;
    exit 0;
}
if($command eq COMMAND_COMMIT_ADD_POST) {
    &CommitAddPost;
    &ServeEditPost;
    exit 0;
}
if($command eq COMMAND_EDIT_POST) {
    &ServeEditPost;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_POST) {
    &CommitEditPost;
    &ServeListPosts;
    exit 0;
}
if($command eq COMMAND_DELETE_POST) {
    &ServeDeletePost;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_POST) {
    &CommitDeletePost;
    &ServeListPosts;
    exit 0;
}
if($command eq COMMAND_VIEW_JOBS) {
    &ServeViewJobs;
    exit 0;
}

if($command eq COMMAND_RESTART_JOB) {
    &RestartJob;
    &ServeViewJobs;
    exit 0;
}
if($command eq COMMAND_DELETE_JOB) {
    &DeleteJob;
    &ServeViewJobs;
    exit 0;
}
if($command eq COMMAND_LIST_SERVERS) {
    &ServeListServers;
    exit 0;
}
if($command eq COMMAND_ADD_SERVER) {
    &ServeAddServer;
    exit 0;
}
if($command eq COMMAND_UPLOAD_ADD_SERVER) {
    &ServeUploadAddServer;
    exit 0;
}
if($command eq COMMAND_COMMIT_ADD_SERVER) {
    &CommitAddServer;
    &ServeEditServer;
    exit 0;
}
if($command eq COMMAND_EDIT_SERVER) {
    &ServeEditServer;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_SERVER) {
    &CommitEditServer;
    &ServeListServers;
    exit 0;
}
if($command eq COMMAND_DELETE_SERVER) {
    &ServeDeleteServer;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_SERVER) {
    &CommitDeleteServer;
    &ServeListServers;
    exit 0;
}
if($command eq COMMAND_ADD_TAP) {
    &ServeAddTap;
    exit 0;
}
if($command eq COMMAND_COMMIT_ADD_TAP) {
    &CommitAddTap;
    &ServeEditTap;
    exit 0;
}
if($command eq COMMAND_EDIT_TAP) {
    &ServeEditTap;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_TAP) {
    &CommitEditTap;
    &ServeEditChannel;
    exit 0;
}
if($command eq COMMAND_DELETE_TAP) {
    &ServeDeleteTap;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_TAP) {
    &CommitDeleteTap;
    &ServeEditChannel;
    exit 0;
}
if($command eq COMMAND_LIST_THUMBNAILS) {
    &ServeListThumbnails(MANAGE_THUMBNAILS);
    exit 0;
}
if($command eq COMMAND_ADD_THUMBNAIL) {
    &ServeAddThumbnail;
    exit 0;
}
if($command eq COMMAND_COMMIT_ADD_THUMBNAIL) {
    &CommitAddThumbnail;
    &ServeListThumbnails(MANAGE_THUMBNAILS);
    exit 0;
}
if($command eq COMMAND_DELETE_THUMBNAIL) {
    &ServeDeleteThumbnail;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_THUMBNAIL) {
    &CommitDeleteThumbnail;
    &ServeListThumbnails(MANAGE_THUMBNAILS);
    exit 0;
}
if($command eq COMMAND_SET_DEFAULT_THUMBNAIL) {
    &CommitDefaultThumbnail;
    &ServeEditChannel;
    exit 0;
}
if($command eq COMMAND_SELECT_THUMBNAIL) {
    &ServeListThumbnails(SELECT_THUMBNAILS);
    exit 0;
}
if($command eq COMMAND_COMMIT_SELECT_THUMBNAIL) {
    &CommitSelectThumbnails;
    &ServeEditPost;
    exit 0;
}
if($command eq COMMAND_LIST_UPLOADS) {
    &ServeListUploads;
    exit 0;
}
if($command eq COMMAND_LIST_FEEDSETS) {
    &ServeListFeedsets;
    exit 0;
}
if($command eq COMMAND_ADD_FEED) {
    &AddFeed;
    &ServeEditFeed;
    exit 0;
}
if($command eq COMMAND_EDIT_FEED) {
    &ServeEditFeed;
    exit 0;
}
if($command eq COMMAND_COMMIT_EDIT_FEED) {
    &ServeCommitFeed;
    &ServeListFeedsets;
    exit 0;
}
if($command eq COMMAND_DELETE_FEED) {
    &ServeDeleteFeed;
    exit 0;
}
if($command eq COMMAND_COMMIT_DELETE_FEED) {
    &ServeCommitDeleteFeed;
    &ServeListFeedsets;
}
if($command eq COMMAND_LOGOUT) {
    &LogOut;
}
&ServeLogin;
