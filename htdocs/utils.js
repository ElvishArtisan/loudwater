// utils.js
//
// Client-side utility routines routines for Loudwater.
//
// (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
//
//   $Id: utils.js,v 1.5 2012/01/16 13:31:34 pcvs Exp $
//

function GetMediaLink(server,name,url,button,style,brandid) {
    var form='NAME='+name;
    form+='&URL='+url;
    form+='&BUTTON='+button;
    form+='&STYLE='+style;
    form+='&BRANDID='+brandid;

    //
    // Send It
    //
    var http=GetXMLHttpRequest();
    if(http===null) {
	return null;
    }
    http.open("POST",'http://'+server+'/loudwater/makemap.pl',false);
    http.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
    http.send(form);

    //
    // Process the response
    //
    if(http.status==200) {
	var link="";
	if(GetXMLText('remap',0,http.responseXML)!=null) {
	    link=GetXMLText('link',0,http.responseXML);
	}
    }
    else {
	alert('makemap returned status '+http.status);
    }
    return link;
}

function GetPage(url) {
    var http=GetXMLHttpRequest();
    if(http==null) {
	return;
    }
    http.open("GET",url,false);
    http.send(null);

    //
    // Process the response
    //
    if(http.status==200) {
	document.open();
	document.write(http.responseText);
       	document.close();
    }
}

function PostForm(form,url)
{
    var http=GetXMLHttpRequest();
    if(http==null) {
	return;
    }

    //
    // Send the form
    //
    http.open("POST",url,false);
    http.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
    http.send(form);

    //
    // Process the response
    //
    if(http.status==200) {
	document.open();
	document.write(http.responseText);
	document.close();
    }
}

function GetXMLText2(tag,obj) {
    if(obj.getElementsByTagName(tag).length>0) {
	if(obj.getElementsByTagName(tag)[0].childNodes.length>0) {
	    return obj.getElementsByTagName(tag)[0].childNodes[0].data;
	}
    }
    return null;
}

function Id(id) {
    return document.getElementById(id);
}

function AddOption(list,option) {
    for(var i=0;i<list.length;i++) {
	if(option.value.localeCompare(list.options[i].value)<0) {
	    list.add(option,list.options[i]);
	    return;
	}
    }
    list.add(option,null);
}

var http_factory=null;
var http_factories=[
    function() {
	return new XMLHttpRequest();
    },
    function() {
	return new ActiveXObject("Microsoft.XMLHTTP");
    },
    function() {
	return new ActiveXObject("MSXML2.XMLHTTP.3.0");
    },
    function() {
	return new ActiveXObject("MSXML2.XMLHTTP");
    }
];

function GetXMLHttpRequest() {
    /*
    if(http_factory!=null) {
	return http_factory;
    }
    */
    for(var i=0;i<http_factories.length;i++) {
	try {
	    var factory=http_factories[i];
	    var request=factory();
	    if(request!=null) {
		http_factory=factory;
		return request;
	    }
	}
	catch(e) {
	    continue;
	}
    }
    return null;
}

function UrlEncode(str) {
    var ret=new String;

    for(i=0;i<str.length;i++) {
	switch(str.charAt(i)) {
	case '$':
	case '&':
	case '+':
	case ',':
	case '/':
	case ':':
	case ';':
	case '=':
	case '?':
	case '@':
	case ' ':
	case '"':
	case '<':
	case '>':
	case '#':
	case '%':
	case '{':
	case '}':
	case '|':
	case '\\':
	case '^':
	case '~':
	case '[':
	case ']':
	case '`':
	    ret+=EncodeChar(str.charCodeAt(i));
	    break;

	default:
	    if((str.charCodeAt(i)<0x20)||(str.charCodeAt(i)>=0x7F)) {
		ret+=EncodeChar(str.charCodeAt(i));
	    }
	    else {
		ret+=str.charAt(i);
	    }
	    break;
	}
    }
    return ret;
}

function EncodeChar(c) {
    var ret=new String;
    ret="%";
    if(c<16) {
	ret+="0";
    }
    ret+=c.toString(16);
    return ret;
}

function DateValid(dt) {
    var parts=dt.split("/");
    if(parts.length!=3) {
	return false;
    }
    if((parts[0]<1)||(parts[0]>12)) {
	return false;
    }
    if((parts[0]==1)||(parts[0]==3)||(parts[0]==5)||(parts[0]==7)||(parts[0]==8)||(parts[0]==10)||(parts[0]==12)) {
	if((parts[0]<1)||(parts[0]>31)) {
	    return false;
	}
    }
    if((parts[0]==4)||(parts[0]==6)||(parts[0]==9)||(parts[0]==11)) {
	if((parts[0]<1)||(parts[0]>30)) {
	    return false;
	}
    }
    if(parts[0]==2) {
	if((parts[2]%4)==0) {
	    if((parts[0]<1)||(parts[0]>29)) {
		return false;
	    }
	}
	else {
	    if((parts[0]<1)||(parts[0]>28)) {
		return false;
	    }
	}
    }
    if(parts[2]<1900) {
	return false;
    }
    return true;
}


function GetXMLText(tag,n,obj) {
    if(obj.getElementsByTagName(tag).length>n) {
	if(obj.getElementsByTagName(tag)[n].childNodes.length>0) {
	    /*
	    alert('len: '+obj.getElementsByTagName(tag)[n].childNodes.length);
	    for(var i=0;i<obj.getElementsByTagName(tag)[n].childNodes.length;i++) {
		alert('nodeName: '+obj.getElementsByTagName(tag)[n].childNodes[0].nodeName);
		alert('nodeType: '+obj.getElementsByTagName(tag)[n].childNodes[0].nodeType);
	    }
	    */
	    return obj.getElementsByTagName(tag)[n].childNodes[0].nodeValue;
	}
    }
    return null;
}
