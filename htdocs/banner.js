//
// Loudwater Banner Widget
// 
//  (C) Copyright 2009,2010 Fred Gleason <fredg@paravelsystems.com>
//

%CURRENT_TITLES%
%CURRENT_DESCRIPTIONS%
%CURRENT_ENCLOSURE_URLS%

var item_ptr=0;

function updateList() {
    if(++item_ptr==current_titles.length) {
	item_ptr=0;
    }
    Id('title_cell').innerHTML='<strong>'+current_titles[item_ptr]+'</strong><br>'+
	current_descriptions[item_ptr];
}


function StartBanner() {
    updateList();
    window.setInterval('updateList();',5000);
}


function StartPlayer() {
    window.open('%PLAYER_PATH%?name=%NAME%&url='+
		current_enclosure_urls[item_ptr]+
		'%BRANDID_ARG%','player','height=585,width=770');
}
