// admin.js
//
// Client-side routines for the Loudwater administrative interface.
//
// (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//   $Id: admin.js,v 1.12 2009/12/28 17:34:20 pcvs Exp $
//

//
// CGI Operations
//
// FIXME: These must be kept in sync with the values in 'htdocs/admin.pl'.
//
COMMAND_LOGOUT=0;
COMMAND_MAIN_MENU=1;
COMMAND_LIST_USERS=2;
COMMAND_ADD_USER=3;
COMMAND_COMMIT_ADD_USER=4;
COMMAND_EDIT_USER=5;
COMMAND_COMMIT_EDIT_USER=6;
COMMAND_DELETE_USER=7;
COMMAND_COMMIT_DELETE_USER=8;
COMMAND_CHANGE_USER_PASSWORD=9;
COMMAND_COMMIT_CHANGE_USER_PASSWORD=10;
COMMAND_LIST_PLAYERS=11;
COMMAND_ADD_PLAYER=12;
COMMAND_COMMIT_ADD_PLAYER=13;
COMMAND_EDIT_PLAYER=14;
COMMAND_COMMIT_EDIT_PLAYER=15;
COMMAND_DELETE_PLAYER=16;
COMMAND_COMMIT_DELETE_PLAYER=17;
COMMAND_LIST_LIVESEGMENTS=18;
COMMAND_COMMIT_ADD_LIVESEGMENT=19;
COMMAND_EDIT_LIVESEGMENT=20;
COMMAND_COMMIT_EDIT_LIVESEGMENT=21;
COMMAND_COMMIT_DELETE_LIVESEGMENT=22;
COMMAND_LIST_BUTTONS=23;
COMMAND_EDIT_BUTTON=24;
COMMAND_COMMIT_EDIT_BUTTON=25;
COMMAND_LIST_CHANNELS=26;
COMMAND_ADD_CHANNEL=27;
COMMAND_COMMIT_ADD_CHANNEL=28;
COMMAND_EDIT_CHANNEL=29;
COMMAND_COMMIT_EDIT_CHANNEL=30;
COMMAND_DELETE_CHANNEL=31;
COMMAND_COMMIT_DELETE_CHANNEL=32;
COMMAND_EDIT_CHANNEL_PERMS=33;
COMMAND_COMMIT_CHANNEL_PERMS=34;
COMMAND_LIST_CONTENT_CHANNELS=35;
COMMAND_LIST_CHANNEL_LINKS=36;
COMMAND_LIST_POSTS=37;
COMMAND_ADD_POST=38;
COMMAND_UPLOAD_ADD_POST=39;
COMMAND_COMMIT_ADD_POST=40;
COMMAND_EDIT_POST=41;
COMMAND_COMMIT_EDIT_POST=42;
COMMAND_DELETE_POST=43;
COMMAND_COMMIT_DELETE_POST=44;
COMMAND_LIST_SERVERS=45;
COMMAND_ADD_SERVER=46;
COMMAND_UPLOAD_ADD_SERVER=47;
COMMAND_COMMIT_ADD_SERVER=48;
COMMAND_EDIT_SERVER=49;
COMMAND_COMMIT_EDIT_SERVER=50;
COMMAND_DELETE_SERVER=51;
COMMAND_COMMIT_DELETE_SERVER=52;
COMMAND_ADD_TAP=53;
COMMAND_COMMIT_ADD_TAP=54;
COMMAND_EDIT_TAP=55;
COMMAND_COMMIT_EDIT_TAP=56;
COMMAND_DELETE_TAP=57;
COMMAND_COMMIT_DELETE_TAP=58;
COMMAND_VIEW_JOBS=59;
COMMAND_RESTART_JOB=60;
COMMAND_DELETE_JOB=61;
COMMAND_LIST_THUMBNAILS=62;
COMMAND_ADD_THUMBNAIL=63;
COMMAND_COMMIT_ADD_THUMBNAIL=64;
COMMAND_DELETE_THUMBNAIL=65;
COMMAND_COMMIT_DELETE_THUMBNAIL=66;
COMMAND_COMMIT_SET_DEFAULT_THUMBNAIL=67;
COMMAND_SELECT_THUMBNAIL=68;
COMMAND_COMMIT_SELECT_THUMBNAIL=69;
COMMAND_LIST_UPLOADS=70;
COMMAND_LIST_FEEDSETS=71;
COMMAND_ADD_FEED=72;
COMMAND_EDIT_FEED=73;
COMMAND_COMMIT_EDIT_FEED=74;
COMMAND_DELETE_FEED=75;
COMMAND_COMMIT_DELETE_FEED=76;

//
// Edit User Callbacks
//
function changeUserPassword(session_id,user_name) {
    //
    // Validate arguments
    //
    if((session_id==null)||(user_name==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_CHANGE_USER_PASSWORD;
    form+='&SESSION_ID='+session_id;
    form+='&USER_NAME='+UrlEncode(user_name);
    form+='&FULL_NAME='+UrlEncode(Id("FULL_NAME").value);
    form+='&EMAIL_ADDRESS='+UrlEncode(Id("EMAIL_ADDRESS").value);
    form+='&PHONE_NUMBER='+UrlEncode(Id("PHONE_NUMBER").value);

    if(Id("MANAGE_USERS_PRIV").checked) {
	form+='&MANAGE_USERS_PRIV=1';
    }
    else {
	form+='&MANAGE_USERS_PRIV=0';
    }
    if(Id("MANAGE_PLAYERS_PRIV").checked) {
	form+='&MANAGE_PLAYERS_PRIV=1';
    }
    else {
	form+='&MANAGE_PLAYERS_PRIV=0';
    }
    if(Id("MANAGE_CHANNELS_PRIV").checked) {
	form+='&MANAGE_CHANNELS_PRIV=1';
    }
    else {
	form+='&MANAGE_CHANNELS_PRIV=0';
    }
    if(Id("MANAGE_SERVERS_PRIV").checked) {
	form+='&MANAGE_SERVERS_PRIV=1';
    }
    else {
	form+='&MANAGE_SERVERS_PRIV=0';
    }

    PostForm(form,"admin.pl");
}


function authorizeChannels(session_id,user_name) {
    //
    // Validate arguments
    //
    if((session_id==null)||(user_name==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_EDIT_CHANNEL_PERMS;
    form+='&SESSION_ID='+session_id;
    form+='&USER_NAME='+UrlEncode(user_name);
    form+='&FULL_NAME='+UrlEncode(Id("FULL_NAME").value);
    form+='&EMAIL_ADDRESS='+UrlEncode(Id("EMAIL_ADDRESS").value);
    form+='&PHONE_NUMBER='+UrlEncode(Id("PHONE_NUMBER").value);

    if(Id("MANAGE_USERS_PRIV").checked) {
	form+='&MANAGE_USERS_PRIV=1';
    }
    else {
	form+='&MANAGE_USERS_PRIV=0';
    }
    if(Id("MANAGE_PLAYERS_PRIV").checked) {
	form+='&MANAGE_PLAYERS_PRIV=1';
    }
    else {
	form+='&MANAGE_PLAYERS_PRIV=0';
    }
    if(Id("MANAGE_CHANNELS_PRIV").checked) {
	form+='&MANAGE_CHANNELS_PRIV=1';
    }
    else {
	form+='&MANAGE_CHANNELS_PRIV=0';
    }
    if(Id("MANAGE_SERVERS_PRIV").checked) {
	form+='&MANAGE_SERVERS_PRIV=1';
    }
    else {
	form+='&MANAGE_SERVERS_PRIV=0';
    }
    PostForm(form,"admin.pl");
}


//
// Edit Player Callbacks
//
function addLiveSegment(session_id,player_name) {
    //
    // Validate arguments
    //
    if((session_id==null)||(player_name==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_COMMIT_ADD_LIVESEGMENT;
    form+='&SESSION_ID='+session_id;
    form+='&PLAYER_NAME='+UrlEncode(player_name);
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&SPLASH_LINK='+UrlEncode(Id("SPLASH_LINK").value);
    form+='&AUDIO_LOGO_LINK='+UrlEncode(Id("AUDIO_LOGO_LINK").value);
    form+='&VIDEO_LOGO_LINK='+UrlEncode(Id("VIDEO_LOGO_LINK").value);
    form+='&OPTIONAL_LINK_CODE='+UrlEncode(Id("OPTIONAL_LINK_CODE").value);
    form+='&DEFAULT_LINK='+UrlEncode(Id("DEFAULT_LINK").value);
    form+='&SID='+UrlEncode(Id("SID").value);
    form+='&GATEWAY_QUALITY='+UrlEncode(Id("GATEWAY_QUALITY").value);
    form+='&USE_SYNCHED_BANNERS='+UrlEncode(Id("USE_SYNCHED_BANNERS").value);
    form+='&BUTTON_SECTION_IMAGE='+UrlEncode(Id("BUTTON_SECTION_IMAGE").value);
    form+='&BUTTON_COLUMNS='+UrlEncode(Id("BUTTON_COLUMNS").value);
    form+='&BUTTON_ROWS='+UrlEncode(Id("BUTTON_ROWS").value);
    form+='&HEAD_CODE='+UrlEncode(Id("HEAD_CODE").value);
    form+='&TOP_BANNER_CODE='+UrlEncode(Id("TOP_BANNER_CODE").value);
    form+='&SIDE_BANNER_CODE='+UrlEncode(Id("SIDE_BANNER_CODE").value);
    PostForm(form,"admin.pl");
}

function editLiveSegment(session_id,player_name,segment_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(player_name==null)||(segment_id==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_EDIT_LIVESEGMENT;
    form+='&SESSION_ID='+session_id;
    form+='&PLAYER_NAME='+UrlEncode(player_name);
    form+='&SEGMENT_ID='+segment_id;
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&SPLASH_LINK='+UrlEncode(Id("SPLASH_LINK").value);
    form+='&AUDIO_LOGO_LINK='+UrlEncode(Id("AUDIO_LOGO_LINK").value);
    form+='&VIDEO_LOGO_LINK='+UrlEncode(Id("VIDEO_LOGO_LINK").value);
    form+='&OPTIONAL_LINK_CODE='+UrlEncode(Id("OPTIONAL_LINK_CODE").value);
    form+='&DEFAULT_LINK='+UrlEncode(Id("DEFAULT_LINK").value);
    form+='&SID='+UrlEncode(Id("SID").value);
    form+='&GATEWAY_QUALITY='+UrlEncode(Id("GATEWAY_QUALITY").value);
    form+='&USE_SYNCHED_BANNERS='+UrlEncode(Id("USE_SYNCHED_BANNERS").value);
    form+='&BUTTON_SECTION_IMAGE='+UrlEncode(Id("BUTTON_SECTION_IMAGE").value);
    form+='&BUTTON_COLUMNS='+UrlEncode(Id("BUTTON_COLUMNS").value);
    form+='&BUTTON_ROWS='+UrlEncode(Id("BUTTON_ROWS").value);
    form+='&HEAD_CODE='+UrlEncode(Id("HEAD_CODE").value);
    form+='&TOP_BANNER_CODE='+UrlEncode(Id("TOP_BANNER_CODE").value);
    form+='&SIDE_BANNER_CODE='+UrlEncode(Id("SIDE_BANNER_CODE").value);

    PostForm(form,"admin.pl");
}

function editButtons(session_id,player_name) {
    //
    // Validate arguments
    //
    if((session_id==null)||(player_name==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_LIST_BUTTONS;
    form+='&SESSION_ID='+session_id;
    form+='&PLAYER_NAME='+UrlEncode(player_name);
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&SPLASH_LINK='+UrlEncode(Id("SPLASH_LINK").value);
    form+='&AUDIO_LOGO_LINK='+UrlEncode(Id("AUDIO_LOGO_LINK").value);
    form+='&VIDEO_LOGO_LINK='+UrlEncode(Id("VIDEO_LOGO_LINK").value);
    form+='&OPTIONAL_LINK_CODE='+UrlEncode(Id("OPTIONAL_LINK_CODE").value);
    form+='&DEFAULT_LINK='+UrlEncode(Id("DEFAULT_LINK").value);
    form+='&SID='+UrlEncode(Id("SID").value);
    form+='&GATEWAY_QUALITY='+UrlEncode(Id("GATEWAY_QUALITY").value);
    form+='&USE_SYNCHED_BANNERS='+UrlEncode(Id("USE_SYNCHED_BANNERS").value);
    form+='&BUTTON_SECTION_IMAGE='+UrlEncode(Id("BUTTON_SECTION_IMAGE").value);
    form+='&BUTTON_COLUMNS='+UrlEncode(Id("BUTTON_COLUMNS").value);
    form+='&BUTTON_ROWS='+UrlEncode(Id("BUTTON_ROWS").value);
    form+='&HEAD_CODE='+UrlEncode(Id("HEAD_CODE").value);
    form+='&TOP_BANNER_CODE='+UrlEncode(Id("TOP_BANNER_CODE").value);
    form+='&SIDE_BANNER_CODE='+UrlEncode(Id("SIDE_BANNER_CODE").value);

    PostForm(form,"admin.pl");
}

function deleteLiveSegment(session_id,player_name,segment_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(player_name==null)||(segment_id==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_COMMIT_DELETE_LIVESEGMENT;
    form+='&SESSION_ID='+session_id;
    form+='&PLAYER_NAME='+UrlEncode(player_name);
    form+='&SEGMENT_ID='+segment_id;
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&SPLASH_LINK='+UrlEncode(Id("SPLASH_LINK").value);
    form+='&AUDIO_LOGO_LINK='+UrlEncode(Id("AUDIO_LOGO_LINK").value);
    form+='&VIDEO_LOGO_LINK='+UrlEncode(Id("VIDEO_LOGO_LINK").value);
    form+='&OPTIONAL_LINK_CODE='+UrlEncode(Id("OPTIONAL_LINK_CODE").value);
    form+='&DEFAULT_LINK='+UrlEncode(Id("DEFAULT_LINK").value);
    form+='&SID='+UrlEncode(Id("SID").value);
    form+='&GATEWAY_QUALITY='+UrlEncode(Id("GATEWAY_QUALITY").value);
    form+='&USE_SYNCHED_BANNERS='+UrlEncode(Id("USE_SYNCHED_BANNERS").value);
    form+='&BUTTON_SECTION_IMAGE='+UrlEncode(Id("BUTTON_SECTION_IMAGE").value);
    form+='&BUTTON_COLUMNS='+UrlEncode(Id("BUTTON_COLUMNS").value);
    form+='&BUTTON_ROWS='+UrlEncode(Id("BUTTON_ROWS").value);
    form+='&HEAD_CODE='+UrlEncode(Id("HEAD_CODE").value);
    form+='&TOP_BANNER_CODE='+UrlEncode(Id("TOP_BANNER_CODE").value);
    form+='&SIDE_BANNER_CODE='+UrlEncode(Id("SIDE_BANNER_CODE").value);
    PostForm(form,"admin.pl");
}

function restartJob(session_id,post_id,job_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(post_id==null)||(job_id==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_RESTART_JOB;
    form+='&SESSION_ID='+session_id;
    form+='&POST_ID='+post_id;
    form+='&JOB_ID='+job_id;
    PostForm(form,"admin.pl");
}

function deleteJob(session_id,post_id,job_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(post_id==null)||(job_id==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_DELETE_JOB;
    form+='&SESSION_ID='+session_id;
    form+='&POST_ID='+post_id;
    form+='&JOB_ID='+job_id;
    PostForm(form,"admin.pl");
}

function showDeleteJobs(session_id,channel_name,tap_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(channel_name==null)||(tap_id==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_VIEW_JOBS;
    form+='&SESSION_ID='+session_id;
    form+='&CHANNEL_NAME='+UrlEncode(channel_name);
    form+='&TAP_ID='+tap_id;
    PostForm(form,"admin.pl");
}

//
// Edit Chennel Callbacks
//
function setDefaultThumbnail(session_id,channel_name,thumbnail_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(channel_name==null)||(thumbnail_id==null)) {
	alert('null');
	return;
    }

    //
    // Post form
    //
    var form='';
    form+='COMMAND='+COMMAND_LIST_THUMBNAILS;
    form+='&SESSION_ID='+session_id;
    form+='&CHANNEL_NAME='+UrlEncode(channel_name);
    form+='&THUMBNAIL_ID='+thumbnail_id;
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&DESCRIPTION='+UrlEncode(Id("DESCRIPTION").value);
    form+='&CATEGORY='+UrlEncode(Id("CATEGORY").value);
    form+='&LINK='+UrlEncode(Id("LINK").value);
    form+='&COPYRIGHT='+UrlEncode(Id("COPYRIGHT").value);
    form+='&WEBMASTER='+UrlEncode(Id("WEBMASTER").value);
    form+='&AUTHOR='+UrlEncode(Id("AUTHOR").value);
    form+='&OWNER='+UrlEncode(Id("OWNER").value);
    form+='&OWNER_EMAIL='+UrlEncode(Id("OWNER_EMAIL").value);
    form+='&SUBTITLE='+UrlEncode(Id("SUBTITLE").value);
    form+='&CATEGORY_ITUNES='+UrlEncode(Id("CATEGORY_ITUNES").value);
    form+='&KEYWORDS='+UrlEncode(Id("KEYWORDS").value);
    form+='&LANGUAGE='+UrlEncode(Id("LANGUAGE").value);
    form+='&EXPLICIT='+UrlEncode(Id("EXPLICIT").value);
    PostForm(form,"admin.pl");
}


//
// Edit Post Callbacks
//
function validateEditPost(session_id,channel_name,post_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(channel_name==null)||(post_id==null)) {
	alert('null');
	return;
    }

    if(!DateValid(Id("AIR_DATE").value)) {
	alert('The Air Date is invalid.');
	return;
    }

    //
    // Post Form
    //
    var form='';
    form+='COMMAND='+COMMAND_COMMIT_EDIT_POST;
    form+='&SESSION_ID='+session_id;
    form+='&CHANNEL_NAME='+UrlEncode(channel_name);
    form+='&POST_ID='+post_id;
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&DESCRIPTION='+UrlEncode(Id("DESCRIPTION").value);
    form+='&SHORT_DESCRIPTION='+UrlEncode(Id("SHORT_DESCRIPTION").value);
    form+='&CATEGORY='+UrlEncode(Id("CATEGORY").value);
    form+='&LINK='+UrlEncode(Id("LINK").value);
    form+='&COPYRIGHT='+UrlEncode(Id("COPYRIGHT").value);
    form+='&WEBMASTER='+UrlEncode(Id("WEBMASTER").value);
    form+='&AUTHOR='+UrlEncode(Id("AUTHOR").value);
    form+='&KEYWORDS='+UrlEncode(Id("KEYWORDS").value);
    form+='&COMMENTS='+UrlEncode(Id("COMMENTS").value);
    form+='&AIR_DATE='+UrlEncode(Id("AIR_DATE").value);
    form+='&AIR_HOUR='+UrlEncode(Id("AIR_HOUR").value);
    form+='&LANGUAGE='+UrlEncode(Id("LANGUAGE").value);
    form+='&POST_ACTIVE='+UrlEncode(Id("POST_ACTIVE").value);
    PostForm(form,"admin.pl");
}

function editThumbnail(session_id,channel_name,post_id,thumbnail_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(channel_name==null)||(post_id==null)||
       (thumbnail_id==null)) {
	alert('null');
	return;
    }

    //
    // Post form
    //
    var form='';
    form+='COMMAND='+COMMAND_SELECT_THUMBNAIL;
    form+='&SESSION_ID='+session_id;
    form+='&CHANNEL_NAME='+UrlEncode(channel_name);
    form+='&POST_ID='+post_id;
    form+='&THUMBNAIL_ID='+thumbnail_id;
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&DESCRIPTION='+UrlEncode(Id("DESCRIPTION").value);
    form+='&SHORT_DESCRIPTION='+UrlEncode(Id("SHORT_DESCRIPTION").value);
    form+='&CATEGORY='+UrlEncode(Id("CATEGORY").value);
    form+='&LINK='+UrlEncode(Id("LINK").value);
    form+='&COPYRIGHT='+UrlEncode(Id("COPYRIGHT").value);
    form+='&WEBMASTER='+UrlEncode(Id("WEBMASTER").value);
    form+='&AUTHOR='+UrlEncode(Id("AUTHOR").value);
    form+='&KEYWORDS='+UrlEncode(Id("KEYWORDS").value);
    form+='&AIR_DATE='+UrlEncode(Id("AIR_DATE").value);
    form+='&AIR_HOUR='+UrlEncode(Id("AIR_HOUR").value);
    form+='&COMMENTS='+UrlEncode(Id("COMMENTS").value);
    form+='&LANGUAGE='+UrlEncode(Id("LANGUAGE").value);
    form+='&POST_ACTIVE='+UrlEncode(Id("POST_ACTIVE").value);
    PostForm(form,"admin.pl");
}


//
// Edit Channel Callbacks
//
function addTap(session_id,channel_name) {
    //
    // Validate arguments
    //
    if((session_id==null)||(channel_name==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_ADD_TAP;
    form+='&SESSION_ID='+session_id;
    form+='&CHANNEL_NAME='+UrlEncode(channel_name);
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&DESCRIPTION='+UrlEncode(Id("DESCRIPTION").value);
    form+='&CATEGORY='+UrlEncode(Id("CATEGORY").value);
    form+='&LINK='+UrlEncode(Id("LINK").value);
    form+='&COPYRIGHT='+UrlEncode(Id("COPYRIGHT").value);
    form+='&WEBMASTER='+UrlEncode(Id("WEBMASTER").value);
    form+='&AUTHOR='+UrlEncode(Id("AUTHOR").value);
    form+='&OWNER='+UrlEncode(Id("OWNER").value);
    form+='&OWNER_EMAIL='+UrlEncode(Id("OWNER_EMAIL").value);
    form+='&SUBTITLE='+UrlEncode(Id("SUBTITLE").value);
    form+='&CATEGORY_ITUNES='+UrlEncode(Id("CATEGORY_ITUNES").value);
    form+='&KEYWORDS='+UrlEncode(Id("KEYWORDS").value);
    //    form+='&EXPLICIT='+Id("EXPLICIT").value;
    form+='&LANGUAGE='+UrlEncode(Id("LANGUAGE").value);
    form+='&EXPLICIT='+UrlEncode(Id("EXPLICIT").value);
    form+='&MAX_UPLOAD_SIZE='+UrlEncode(Id("MAX_UPLOAD_SIZE").value);
    PostForm(form,"admin.pl");
}

function editTap(session_id,tap_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(tap_id==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_EDIT_TAP;
    form+='&SESSION_ID='+session_id;
    form+='&TAP_ID='+tap_id;
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&DESCRIPTION='+UrlEncode(Id("DESCRIPTION").value);
    form+='&CATEGORY='+UrlEncode(Id("CATEGORY").value);
    form+='&LINK='+UrlEncode(Id("LINK").value);
    form+='&COPYRIGHT='+UrlEncode(Id("COPYRIGHT").value);
    form+='&WEBMASTER='+UrlEncode(Id("WEBMASTER").value);
    form+='&AUTHOR='+UrlEncode(Id("AUTHOR").value);
    form+='&OWNER='+UrlEncode(Id("OWNER").value);
    form+='&OWNER_EMAIL='+UrlEncode(Id("OWNER_EMAIL").value);
    form+='&SUBTITLE='+UrlEncode(Id("SUBTITLE").value);
    form+='&CATEGORY_ITUNES='+UrlEncode(Id("CATEGORY_ITUNES").value);
    form+='&KEYWORDS='+UrlEncode(Id("KEYWORDS").value);
    //    form+='&EXPLICIT='+Id("EXPLICIT").value;
    form+='&LANGUAGE='+UrlEncode(Id("LANGUAGE").value);
    form+='&EXPLICIT='+UrlEncode(Id("EXPLICIT").value);
    form+='&MAX_UPLOAD_SIZE='+UrlEncode(Id("MAX_UPLOAD_SIZE").value);
    PostForm(form,"admin.pl");
}

function deleteTap(session_id,channel_name,tap_id) {
    //
    // Validate arguments
    //
    if((session_id==null)||(channel_name==null)||(tap_id==null)) {
	alert('null');
	return;
    }

    //
    // Post the form
    //
    var form='';
    form+='COMMAND='+COMMAND_DELETE_TAP;
    form+='&SESSION_ID='+session_id;
    form+='&CHANNEL_NAME='+UrlEncode(channel_name);
    form+='&TAP_ID='+tap_id;
    form+='&TITLE='+UrlEncode(Id("TITLE").value);
    form+='&DESCRIPTION='+UrlEncode(Id("DESCRIPTION").value);
    form+='&CATEGORY='+UrlEncode(Id("CATEGORY").value);
    form+='&LINK='+UrlEncode(Id("LINK").value);
    form+='&COPYRIGHT='+UrlEncode(Id("COPYRIGHT").value);
    form+='&WEBMASTER='+UrlEncode(Id("WEBMASTER").value);
    form+='&AUTHOR='+UrlEncode(Id("AUTHOR").value);
    form+='&OWNER='+UrlEncode(Id("OWNER").value);
    form+='&OWNER_EMAIL='+UrlEncode(Id("OWNER_EMAIL").value);
    form+='&SUBTITLE='+UrlEncode(Id("SUBTITLE").value);
    form+='&CATEGORY_ITUNES='+UrlEncode(Id("CATEGORY_ITUNES").value);
    form+='&KEYWORDS='+UrlEncode(Id("KEYWORDS").value);
    //    form+='&EXPLICIT='+Id("EXPLICITY").value;
    form+='&LANGUAGE='+UrlEncode(Id("LANGUAGE").value);
    form+='&EXPLICIT='+UrlEncode(Id("EXPLICIT").value);
    form+='&MAX_UPLOAD_SIZE='+UrlEncode(Id("MAX_UPLOAD_SIZE").value);
    PostForm(form,"admin.pl");
}


function validateTap(url)
{
    window.open(url,"Validation");
}


//
// Edit Channel Permissions Callbacks
//
function editChannelPermsMoveFrom() {
    var from_list=Id('CHANNEL_NAMES');
    var to_list=Id('AUTHORIZED_CHANNEL_NAMES');
    for(var i=from_list.length-1;i>=0;i--) {
	if(from_list.options[i].selected) {
	    AddOption(to_list,from_list.options[i]);
	}
    }
}

function editChannelPermsMoveTo() {
    var from_list=Id('CHANNEL_NAMES');
    var to_list=Id('AUTHORIZED_CHANNEL_NAMES');
    for(var i=to_list.length-1;i>=0;i--) {
	if(to_list.options[i].selected) {
	    AddOption(from_list,to_list.options[i]);
	}
    }
}

function editChannelPermsMoveAllFrom() {
    var from_list=Id('CHANNEL_NAMES');
    var to_list=Id('AUTHORIZED_CHANNEL_NAMES');
    for(var i=from_list.length-1;i>=0;i--) {
	AddOption(to_list,from_list.options[i]);
    }
}

function editChannelPermsMoveAllTo() {
    var from_list=Id('CHANNEL_NAMES');
    var to_list=Id('AUTHORIZED_CHANNEL_NAMES');
    for(var i=to_list.length-1;i>=0;i--) {
	AddOption(from_list,to_list.options[i]);
    }
}

function submitChannelPerms() {
    //
    // Get arguments
    //
    var command=Id("COMMAND");
    var session_id=Id("SESSION_ID");
    var user_name=Id("USER_NAME");
    var to_list=Id('AUTHORIZED_CHANNEL_NAMES');
    if((command==null)||(session_id==null)||(user_name==null)||
       (to_list==null)) {
	alert('null');
	return;
    }

    //
    // Write the form
    //
    var form='';
    form+='COMMAND='+command.value;
    form+='&SESSION_ID='+session_id.value;
    form+='&USER_NAME='+UrlEncode(user_name.value);
    for(var i=to_list.length-1;i>=0;i--) {
	form+='&'+to_list.options[i].value+'=0';
    }
    form+='&FULL_NAME='+UrlEncode(Id("FULL_NAME").value);
    form+='&EMAIL_ADDRESS='+UrlEncode(Id("EMAIL_ADDRESS").value);
    form+='&PHONE_NUMBER='+UrlEncode(Id("PHONE_NUMBER").value);

    if(Id("MANAGE_USERS_PRIV").value==1) {
	form+='&MANAGE_USERS_PRIV=1';
    }
    else {
	form+='&MANAGE_USERS_PRIV=0';
    }
    if(Id("MANAGE_PLAYERS_PRIV").value==1) {
	form+='&MANAGE_PLAYERS_PRIV=1';
    }
    else {
	form+='&MANAGE_PLAYERS_PRIV=0';
    }
    if(Id("MANAGE_CHANNELS_PRIV").value==1) {
	form+='&MANAGE_CHANNELS_PRIV=1';
    }
    else {
	form+='&MANAGE_CHANNELS_PRIV=0';
    }
    if(Id("MANAGE_SERVERS_PRIV").value==1) {
	form+='&MANAGE_SERVERS_PRIV=1';
    }
    else {
	form+='&MANAGE_SERVERS_PRIV=0';
    }
    PostForm(form,"admin.pl");
}

//
// Upload progress bar dialog methods
//
function StartProgressbar()
{
  var html='<table cellpadding=\"10\" cellspacing=\"0\" border=\"0\" width=\"600\" height=\"400\">\n'+
      '<tr height=\"200\" bgcolor=\"#e0e0e0\">'+
      '<td align=\"center\" valign=\"bottom\">\n'+
      '<big><big>File uploading, please stand by...</big></big></td></tr>\n'+
      '<tr bgcolor=\"#e0e0e0\"><td align=\"center\" valign=\"top\">\n'+
      '<img src=\"progressbar.gif\" border=\"1\"></td></tr>\n'+
      '</table>\n';

  document.getElementById("bigframe").innerHTML=html;
}

function PostCast()
{
  window.setTimeout('StartProgressbar()',10);
}
