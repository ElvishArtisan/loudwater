// runspot.js
//
// Client-side routines routines for the Ando RunSpot web service.
//
// (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//   $Id: runspot.js,v 1.4 2012/01/16 13:31:34 pcvs Exp $
//

//
// AdFormat Values (Bitwise-OR'd)
//
ANDO_FORMAT_MP3=1;
ANDO_FORMAT_WMV=2;
ANDO_FORMAT_FLV=4;

//
// SpotLevel Values
//
ANDO_DEFAULT_INSTREAM=0;
ANDO_PRE_ROLL=1;
ANDO_POST_ROLL=2;
ANDO_BOTH=3;

//
// CategoryID Values (Bitwise-OR'd)
//
ANDO_CID_BUMPER=64;
ANDO_CID_DRY_LINERS=16384;
ANDO_CID_JINGLE=1024;
ANDO_CID_LINER=512;
ANDO_CID_MUSIC_BED=8;
ANDO_CID_NOTICE=4096;
ANDO_CID_PAID_CPM=1;
ANDO_CID_PAID_PI=2;
ANDO_CID_PROMO=128;
ANDO_CID_SHORT_SHOWS=32768;
ANDO_CID_SONG=16;
ANDO_CID_STATION_ID=256;
ANDO_CID_STINGER=2048;
ANDO_CID_SWEEPER=32;
ANDO_CID_TARGET_SPOT=8192;
ANDO_CID_PSA=4;

//
// Class Definitions
//
function AndoAd(tit,lang,date,gen,editor,rank,
		id,top_ban_url,side_ban_url,ban_href,ad_high,ad_med,ad_low) {
  this.title=tit;
  this.language=lang;
  this.pubDate=date;
  this.generator=gen;
  this.managingEditor=editor;
  this.dma=rank;
  this.adid=id;
  this.topBannerURL=top_ban_url;
  this.sideBannerURL=side_ban_url;
  this.bannerHREF=ban_href;
  this.adURL_high=ad_high;
  this.adURL_med=ad_med;
  this.adURL_low=ad_low;
}

function RunSpot(sid,ad_format,minduration,maxduration,spotlevel,category_id) {
    //
    // Generate Form
    //
    var form='';
    form+='SID='+sid;
    form+='&AD_FORMAT='+ad_format;
    form+='&MINDURATION='+minduration;
    form+='&MAXDURATION='+maxduration;
    form+='&SPOTLEVEL='+spotlevel;
    form+='&CATEGORY_ID='+category_id;

    //
    // Send It
    //
    var http=GetXMLHttpRequest();
    if(http===null) {
	return null;
    }
    http.open("POST","runspot.pl",false);
    http.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
    http.send(form);

    //
    // Process the response
    //
    if(http.status==200) {
	var top_banner="";
	var side_banner="";
	if(GetXMLText2('bannerURL',http.responseXML)!=null) {
	    var banners=GetXMLText2('bannerURL',http.responseXML).split("|");
	    top_banner=banners[0];
	    side_banner=banners[1];
	}
	return new AndoAd(GetXMLText2('title',http.responseXML),
			  GetXMLText2('language',http.responseXML),
			  GetXMLText2('pubDate',http.responseXML),
			  GetXMLText2('generator',http.responseXML),
			  GetXMLText2('managingEditor',http.responseXML),
			  GetXMLText2('dma',http.responseXML),
			  GetXMLText2('adid',http.responseXML),
			  top_banner,
			  side_banner,
			  GetXMLText2('BannerHREF',http.responseXML),
			  GetXMLText2('adURL_high',http.responseXML),
			  GetXMLText2('adURL_med',http.responseXML),
			  GetXMLText2('adURL_low',http.responseXML));
    }
    return null;
}
