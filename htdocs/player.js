//
// Loudwater Audio Player
// 
//  (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
var player=null;
var stop_playout_handle=null;
var current_button=0;
var current_social_link="";
var social_link_loading=false;

//
// Player States
//
var StateInit=0;
var StateIdle=1;
var StateSplash=2;
var StateGateway=3;
var StateLive=4;
var StateOnDemand=5;
var StateDirectPlay=6;

//
// Button Modes
//
// FIXME: These must be kept in sync with the values in 'htdocs/player.pl'.
//
var ButtonModeOnDemand=0;
var ButtonModeLivefeed=1;

var play_state=StateInit;
var date_offset=0;
var start_hours=new Array(7);
var gateway_top_banner="";
var gateway_side_banner="";
var gateway_link_url="";

for(var i=0;i<7;i++) {
  start_hours[i]=new Array;
}
%START_HOURS_0%
%START_HOURS_1%
%START_HOURS_2%
%START_HOURS_3%
%START_HOURS_4%
%START_HOURS_5%
%START_HOURS_6%

var start_lengths=new Array(7);
for(var i=0;i<7;i++) {
  start_lengths[i]=new Array;
}
%START_LENGTHS_0%
%START_LENGTHS_1%
%START_LENGTHS_2%
%START_LENGTHS_3%
%START_LENGTHS_4%
%START_LENGTHS_5%
%START_LENGTHS_6%

var live_links=new Array(7);
for(var i=0;i<7;i++) {
  live_links[i]=new Array;
}
%LIVE_LINKS_0%
%LIVE_LINKS_1%
%LIVE_LINKS_2%
%LIVE_LINKS_3%
%LIVE_LINKS_4%
%LIVE_LINKS_5%
%LIVE_LINKS_6%

var live_logos=new Array(7);
for(var i=0;i<7;i++) {
  live_logos[i]=new Array;
}
%LIVE_LOGOS_0%
%LIVE_LOGOS_1%
%LIVE_LOGOS_2%
%LIVE_LOGOS_3%
%LIVE_LOGOS_4%
%LIVE_LOGOS_5%
%LIVE_LOGOS_6%

var live_sids=new Array;
for(var i=0;i<7;i++) {
  live_sids[i]=new Array;
}
%LIVE_SIDS_0%
%LIVE_SIDS_1%
%LIVE_SIDS_2%
%LIVE_SIDS_3%
%LIVE_SIDS_4%
%LIVE_SIDS_5%
%LIVE_SIDS_6%

var ondemand_button_links=new Array;
%ONDEMAND_BUTTON_LINKS%

var channel_sids=new Array;
%CHANNEL_SIDS%

var button_modes=new Array;
%BUTTON_MODES%

var button_images=new Array;
%BUTTON_IMAGES%

var active_button_images=new Array;
%ACTIVE_BUTTON_IMAGES%

var synched_banners=false;
%SYNCHED_BANNERS%

var player_style=new String('%STYLE%');
var player_playlist_position=new String('over');
/*
if(player_style.length!=0) {
    player_playlist_position='right';
}
*/  

//
// Class Definitions
//
  function LiveSegment(start_hour,run_length,live_link,live_logo,remaining,
		       sid) {
  this.startHour=start_hour;
  this.runLength=run_length;
  this.liveLink=live_link;
  this.liveLogo=live_logo;
  this.timeRemaining=remaining;
  this.stationId=sid;
}


//
// Player Callbacks
//
function playerLoaded(obj) {
  player=obj.ref;
}

function playerReady(obj) { 
  addListeners();
}

function addListeners() {
  if(player) { 
    player.addModelListener("STATE", "stateListener");
    player.addControllerListener("PLAYLIST","playlistListener");
    player.addControllerListener("ITEM","itemListener");
  } 
  else {
    setTimeout("addListeners()",100);
  }
}

function stateListener(obj) {
  if(obj.newstate=="COMPLETED") {
    switch(play_state) {
    case StateInit:
    case StateIdle:
    case StateLive:
      break;

    case StateOnDemand:
      PlayButton(current_button);
      break;

    case StateSplash:
      play_state=StateGateway;
      LoudwaterPlayer(GetGatewayLink(%SID%),true,true,true);
      break;

    case StateGateway:
      if('%URL_LINK%'=='') {
	if('%YOUTUBE_LINK%'=='') {
	  StartLiveFeed();
	}
	else {
	  YouTubePlayer('%YOUTUBE_LINK%',true);
	}
      }
      else {
	play_state=StateDirectPlay;
	LoudwaterPlayer('%URL_LINK%',true,true,false);
      }
      break;

    case StateDirectPlay:
	StartLiveFeed();
	break;
    }
  }
  if(obj.newstate=="PAUSED") {
    if(play_state==StateOnDemand) {
      PlayButton(current_button);
    }
  }
}

function itemListener(obj)
{
    current_social_link=GetFullLink(obj.index);
    var html='<iframe align="center" src="//www.facebook.com/plugins/like.php?href=';
    html+=current_social_link;
    html+='&amp;send=false&amp;layout=standard&amp;width=450&amp;show_faces=false&amp;action=like&amp;colorscheme=light&amp;font=arial&amp;height=35" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:450px; height:35px;" allowTransparency="true"></iframe>';

    current_social_link=GetDirectLink(obj.index);
    if('%SOCIAL_DISPLAY_LINK%'=='Y') {
	Id('social_display_link').innerHTML='<font color="#888888">'+
	    current_social_link+'</font>';
    }
    Id('social_facebook').innerHTML=html;
    //alert(Id('social_facebook').innerHTML);
}

function playlistListener(obj)
{
  if(social_link_loading) {
    for(var i=0;i<obj.playlist.length;i++) {
      if(obj.playlist[i].file=='%URL_LINK%') {
	  player.sendEvent('item',i);
	  social_link_loading=false;
	  return;
      }
    }
    alert('The linked content is no longer here.');
    social_link_loading=false;
  }
}

/*
function metaListener(obj) {
    for(j in obj) {
	if((j!='client')&&(j!='id')&&(j!='version')) {
	    var e=document.getElementById("status");
	    if(e!=null) {
		if(obj[j]!='NetStream.Buffer.Flush') {
		    e.innerHTML=e.innerHTML+'<tr><td>'+j+': '+obj[j]+'</td></tr>';
		}
	    }
	}
    }
}
*/

function stopPlayout() {
  var seg=GetActiveSegment();
  if(seg==null) {
    play_state=StateOnDemand;
    LoudwaterPlayer('%DEFAULT_LINK%',false,true,false);
  }
  else {
    setTimeout('stopPlayout()', seg.timeRemaining);
  }
}

//
// Player Entry Points
//
function StartPlayer() {
  var gateway_link="";

  //
  // Initialize the date offset
  //
  var now=new Date();
  date_offset=%CURRENT_TIME%-now.getTime();

  InitSocialMedia();

  if('%SPLASH_LINK%'.length==0) {
    if(%SID%!=0) {
      gateway_link=GetGatewayLink(%SID%);
    }
    if(gateway_link.length==0) {
      if('%URL_LINK%'=='') {
	StartLiveFeed();
      }
      else {
	play_state=StateOnDemand;
	if('%YOUTUBE_LINK%'.length==0) {
	    if(%URL_BUTTON%<0) {
		LoudwaterPlayer('%URL_LINK%',true,true,false);
	    }
	    else {
		//alert('button: '+'%URL_BUTTON%');		
		social_link_loading=true;
		PlayButton(%URL_BUTTON%);
	    }
	}
	else {
	  YouTubePlayer('%YOUTUBE_LINK%',true);
	}
      }
    }
    else {
      play_state=StateGateway;
      LoudwaterPlayer(gateway_link,true,true,true);
    }
  }
  else {
    play_state=StateSplash;
    LoudwaterPlayer('%SPLASH_LINK%',true,true,false);
  }
}

function PlayButton(num) {
  if((play_state==StateSplash)||(play_state==StateGateway)) {
     return;
  }
  if(button_modes[num]==ButtonModeLivefeed) {
    StartLiveFeed();
    return;
  }
  SetActiveButton(num);
  current_button=num;
  SetAndoId(channel_sids[num]);
  LoudwaterPlayer(ondemand_button_links[num],false,true,false);
}

function StartLiveFeed() {
  var seg=GetActiveSegment();
  if(seg!=null) {
    play_state=StateLive;
    LoudwaterPlayer(seg.liveLink,true,false,false);
    SetAndoId(seg.stationId);
    setTimeout('stopPlayout()', seg.timeRemaining);
  }
  else {
    play_state=StateOnDemand;
    LoudwaterPlayer('%DEFAULT_LINK%',false,true,false);
    SetAndoId(channel_sids[0]);
  }    
  SetActiveButton(0);
}

//
// Utility Methods
//
function SetActiveButton(num)
{
  for(var i=0;i<button_images.length;i++) {
    if(i==num) {
      SetButtonImage(i,active_button_images[i]);
    }
    else {
      SetButtonImage(i,button_images[i]);
    }
  }

  //
  // Clear Social Link
  //
  current_social_link="";
    if('%SOCIAL_DISPLAY_LINK%'=='Y') {
	Id('social_display_link').innerHTML='&nbsp;';
    }
}

function SetButtonImage(num,url)
{
    Id('button'+num).innerHTML='<img onclick="PlayButton('+num+');" src="'+url+'" border="0"></a>';
}

function SetAndoId(sid) {
  var e=document.getElementById('pinger');
  if(e!=null) {
    e.src='http://30.wcmcs.net/m/fc.aspx?sid='+sid;
  }
}

function GetPlayerLink()
{
  var style="";
  if('%STYLE%'.length>0) {
    style='style='+'%STYLE%';
  }
  return 'http://'+'%SERVER_NAME%'+'/loudwater/player.pl?name='+'%NAME%'+'&'+
      style;
}


function GetDirectLink(pnum)
{
  plist=player.getPlaylist();
  var brandid='%BRANDID%';
  if(brandid.length==0) {
    brandid=-1;
  }
  var link=GetMediaLink('%SERVER_NAME%','%NAME%',plist[pnum].file,
			current_button,'%STYLE%',brandid);
  return link;
}

function GetFullLink(pnum)
{
    var stylestr='';
    var brandidstr='';

    if('%STYLE%'.length!=0) {
	stylestr='&style='+'%STYLE%';
    }
    var brandid='%BRANDID%';
    if(brandid.length!=0) {
	brandidstr='&brandid='+brandid;
    }
    plist=player.getPlaylist();
    return encodeURIComponent('http://'+'%SERVER_NAME%'+'/loudwater/player.pl'+
			      '?name='+'%NAME%'+
			      '&url='+plist[pnum].file+
			      '&button='+current_button+
			      stylestr+
			      brandidstr);
}

function GetActiveSegment()
{
  var now=new Date();
  var start_time=new Date();
  var end_time=new Date();
  var dow;

  now=GetCurrentTime();
  dow=now.getUTCDay();
  start_time=GetCurrentTime();
  end_time=GetCurrentTime();
  start_time.setUTCMinutes(0);
  start_time.setUTCSeconds(0,0);
  for(var i=0;i<start_hours[dow].length;i++) {
    start_time.setUTCHours(start_hours[dow][i]);
    end_time.setTime(start_time.getTime()+1000*start_lengths[dow][i]);
    if((now>=start_time)&&(now<end_time)) {
      var seg=new LiveSegment(start_hours[dow][i],start_lengths[dow][i],
			      live_links[dow][i],live_logos[dow][i],
			      end_time.valueOf()-now.valueOf(),
			      live_sids[dow][i]);
      return seg;
    }
  }
  return null;
}

function GetLogoLink(link) {
  if(play_state==StateSplash) {
    return "";
  }
  var seg=GetActiveSegment();
  if(seg!=null) {
    if(seg.liveLink==link) {
      return seg.liveLogo;
    }
  }
  strs=link.split('.');
  ext=strs[strs.length-1].toLowerCase();
  if((ext=='mp3')||(ext=='')) {
    return '%AUDIO_LOGO_LINK%';
  }
  return '%VIDEO_LOGO_LINK%';
}

function GetCurrentTime() {
  var now=new Date();
  now.setTime(now.getTime()+date_offset);
  return now;
}

function YouTubePlayer(filename, start) {
  if(player!=null) {
    swfobject.removeSWF(player);
    player=null;
  }
  var params={
    allowfullscreen: 'false'
  }
  var attributes={
    file: filename,
    width: '%PLAYER_WIDTH%',
    height: '%PLAYER_HEIGHT%',
    displayheight: '%PLAYER_DISPLAYHEIGHT%',
    overstretch: 'fit',
    shuffle: 'false',
    thumbsindisplay: 'true'
  }
  var flashvars={
    frontcolor: '%PLAYLIST_FGCOLOR%',
    backcolor: '%PLAYLIST_BGCOLOR%',
    lightcolor: '%PLAYLIST_HGCOLOR%',
    screencolor: '%BGCOLOR%'
  }
  url=filename+'?rel=0&color2=000000';
  if(start) {
    url+="&autoplay=1";
  }
  swfobject.embedSWF(url,'player_window',%PLAYER_WIDTH%,%PLAYER_HEIGHT%,
		     '10','expressInstall.swf',flashvars,params,
		     attributes,playerLoaded);
}

function LoudwaterPlayer(filename,start,playlist,gateway) {
  var logo=new String;
  var banner="";
  var controlbar="bottom";
  var screencolor="#FFFFFF";

  if(gateway&&synched_banners) {
    if(gateway_top_banner!=null) {
      if(gateway_top_banner.length>0) {
	banner='<img border="0" src="'+gateway_top_banner+'">';
	if(gateway_link_url!=null) {
	  if(gateway_link_url.length>0) {
	    banner='<a href="'+gateway_link_url+'" target="ad">'+banner+
		'</a>';
	  }
	}
	if(player_style.length==0) {
	  Id("TOP_BANNER").innerHTML=banner;
	}
      }
    }
    if(gateway_side_banner!=null) {
      if(gateway_side_banner.length>0) {
	banner='<img border="0" src="'+gateway_side_banner+'">';
	if(gateway_link_url!=null) {
	  if(gateway_link_url.length>0) {
	      banner='<a href="'+gateway_link_url+'" target="ad">'+banner+
		  '</a>';
	  }
	}
	Id("SIDE_BANNER").innerHTML=banner;
      }
    }
  }
  else {
    if(synched_banners) {
      if(player_style.length==0) {
	Id("TOP_BANNER").innerHTML='%TOP_BANNER%';
	Id("SIDE_BANNER").innerHTML='%SIDE_BANNER%';
      }
    }
    logo=GetLogoLink(filename);
  }
  if((play_state==StateSplash)||(play_state==StateGateway)) {
    controlbar="none";
    screencolor="#000000";
  }
  if(player!=null) {
    swfobject.removeSWF(player);
    player=null;
  }
  var params={
    allowfullscreen: 'false'
  }
  var attributes={
    file: filename,
    width: '%PLAYER_WIDTH%',
    height: '%PLAYER_HEIGHT%',
    displayheight: '%PLAYER_DISPLAYHEIGHT%',
    overstretch: 'fit',
    shuffle: 'false',
    thumbsindisplay: 'true'
  }
  var flashvars;
  if(playlist) {
    flashvars={
      file: filename,
      playlist: '%PLAYLIST_POSITION%',
      playlistsize: '%PLAYLIST_SIZE%',
      logo: logo,
      displayclick: 'none',
      screencolor: screencolor,
      icons: 'false',
      skin: 'modieus.swf',
      id: 'PlayerID',
      controlbar: controlbar,
      frontcolor: '%PLAYLIST_FGCOLOR%',
      backcolor: '%PLAYLIST_BGCOLOR%',
      lightcolor: '%PLAYLIST_HGCOLOR%',
      screencolor: '%PLAYLIST_SGCOLOR%',
      autostart: start
    }
  }
  else {
    flashvars={
      file: filename,
      playlist: 'none',
      playlistsize: '75',
      logo: logo,
      displayclick: 'none',
      screencolor: screencolor,
      icons: 'false',
      skin: 'modieus.swf',
      id: 'PlayerID',
      controlbar: controlbar,
      frontcolor: '%PLAYLIST_FGCOLOR%',
      backcolor: '%PLAYLIST_BGCOLOR%',
      lightcolor: '%PLAYLIST_HGCOLOR%',
      screencolor: '%PLAYLIST_SGCOLOR%',
      autostart: start
    }
  }
  swfobject.embedSWF('player.swf?%RANDOM%','player_window',%PLAYER_WIDTH%,
		     %PLAYER_HEIGHT%,'10','expressInstall.swf',
		     flashvars,params,attributes,playerLoaded);
}

function GetType(x) {
    if(x==null) {
	return "null";
    }
    var t=typeof x;
    if(t!="object") {
	return t;
    }
    var c=Object.prototype.toString.apply(x);
    c=c.substring(8,c.length-1);
    if(c!="object") {
	return c;
    }
    if(x.constructor==Object) {
	return c;
    }
    if(x.constructor && x.constructor.classname && 
       typeof x.constructor.classname=="string") {
	return x.constructor.classname;
    }
    return "<unknown type>";
}


function GetGatewayLink(sid) {
  if('%GATEWAY_LINK%'.length!=0) {
      return '%GATEWAY_LINK%';
  }
  var spot=RunSpot(sid,ANDO_FORMAT_MP3|ANDO_FORMAT_FLV,0,300,ANDO_PRE_ROLL,
		   ANDO_CID_PAID_CPM|ANDO_CID_PAID_PI|ANDO_CID_PSA);
  if(spot==null) {
      return "";
  }
  gateway_top_banner=spot.topBannerURL; 
  gateway_side_banner=spot.sideBannerURL;
  gateway_link_url=spot.bannerHREF;
  return spot.adURL_med;
}

//
// Social Media Routines
//
function InitSocialMedia()
{
  //
  // Facebook
  //
    /*
  if(Id('social_facebook')!=null) {
      Id('social_facebook').innerHTML='&nbsp;';
  }
    */
}

function SocialTest()
{
  alert('current_social_link: '+current_social_link);
}
