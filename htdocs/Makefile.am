## automake.am
##
## htdocs/Makefile.am for Loudwater
##
## Use automake to process this into a Makefile.in
##
##   (C) Copyright 2009 Fred Gleason <fredg@paravelsystems.com>
##
##      $Id: Makefile.am,v 1.10 2012/01/20 17:43:05 pcvs Exp $
##

install-exec-local:	
	mkdir -p $(DESTDIR)@libexecdir@/loudwater
	cat admin.js | ../helpers/jsmin > $(DESTDIR)@libexecdir@/loudwater/admin.js
	cp admin.pl $(DESTDIR)@libexecdir@/loudwater/
	cp admin-doc.html $(DESTDIR)@libexecdir@/loudwater/
	cp andotag.html $(DESTDIR)@libexecdir@/loudwater/
	cat banner.js | ../helpers/jsmin > $(DESTDIR)@libexecdir@/loudwater/banner.js
	cp banner.pl $(DESTDIR)@libexecdir@/loudwater/
	cp common.pl $(DESTDIR)@libexecdir@/loudwater/
	cp expressInstall.swf $(DESTDIR)@libexecdir@/loudwater/
	cat facebook.js | ../helpers/jsmin > $(DESTDIR)@libexecdir@/loudwater/facebook.js
	cp feed.pl $(DESTDIR)@libexecdir@/loudwater/
	rm -f $(DESTDIR)@libexecdir@/loudwater/feed.xml
	ln -s feed.pl $(DESTDIR)@libexecdir@/loudwater/feed.xml
	cp greenball.png $(DESTDIR)@libexecdir@/loudwater/
	cp hbanner.html $(DESTDIR)@libexecdir@/loudwater/
	cp hplay.png $(DESTDIR)@libexecdir@/loudwater/
	cp listvars.pl $(DESTDIR)@libexecdir@/loudwater/
	cp live.pl $(DESTDIR)@libexecdir@/loudwater/
	cp makemap.html $(DESTDIR)@libexecdir@/loudwater/
	cp makemap.pl $(DESTDIR)@libexecdir@/loudwater/
	cp modieus.swf $(DESTDIR)@libexecdir@/loudwater/
	cp play-base.png $(DESTDIR)@libexecdir@/loudwater/
	cp player.css $(DESTDIR)@libexecdir@/loudwater/
	cp player.html $(DESTDIR)@libexecdir@/loudwater/
	cp player-sparse.html $(DESTDIR)@libexecdir@/loudwater/
	cat player.js | ../helpers/jsmin > $(DESTDIR)@libexecdir@/loudwater/player.js
	cp player.pl $(DESTDIR)@libexecdir@/loudwater/
	cp player.swf $(DESTDIR)@libexecdir@/loudwater/
	cp progressbar.gif $(DESTDIR)@libexecdir@/loudwater/
	cp redball.png $(DESTDIR)@libexecdir@/loudwater/
	cp remap.pl $(DESTDIR)@libexecdir@/loudwater/
	cp runspot.html $(DESTDIR)@libexecdir@/loudwater/
	cat runspot.js | ../helpers/jsmin > $(DESTDIR)@libexecdir@/loudwater/runspot.js
	cp runspot.pl $(DESTDIR)@libexecdir@/loudwater/
	cp social_test.png $(DESTDIR)@libexecdir@/loudwater/
	cat swfobject.js | ../helpers/jsmin > $(DESTDIR)@libexecdir@/loudwater/swfobject.js
	cp test_player_config.pl $(DESTDIR)@libexecdir@/loudwater/
	cp test_player_head.txt $(DESTDIR)@libexecdir@/loudwater/
	cp track.pl $(DESTDIR)@libexecdir@/loudwater/
	cp utils.js $(DESTDIR)@libexecdir@/loudwater/
	cat utils.js | ../helpers/jsmin > $(DESTDIR)@libexecdir@/loudwater/utils.js
	cp vbanner.html $(DESTDIR)@libexecdir@/loudwater/
	cp version.pl $(DESTDIR)@libexecdir@/loudwater/
	cp vplay.png $(DESTDIR)@libexecdir@/loudwater/
	cp whiteball.png $(DESTDIR)@libexecdir@/loudwater/

uninstall:	
	rm -f $(DESTDIR)@libexecdir@/loudwater/admin.js
	rm -f $(DESTDIR)@libexecdir@/loudwater/admin.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/admin-doc.html
	rm -f $(DESTDIR)@libexecdir@/loudwater/andotag.html
	rm -f $(DESTDIR)@libexecdir@/loudwater/banner.js
	rm -f $(DESTDIR)@libexecdir@/loudwater/banner.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/common.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/expressInstall.swf
	rm -f $(DESTDIR)@libexecdir@/loudwater/facebook.js
	rm -f $(DESTDIR)@libexecdir@/loudwater/feed.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/feed.xml
	rm -f $(DESTDIR)@libexecdir@/loudwater/greenball.png
	rm -f $(DESTDIR)@libexecdir@/loudwater/hbanner.html
	rm -f $(DESTDIR)@libexecdir@/loudwater/hplay.png
	rm -f $(DESTDIR)@libexecdir@/loudwater/listvars.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/live.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/makemap.html
	rm -f $(DESTDIR)@libexecdir@/loudwater/makemap.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/modieus.swf
	rm -f $(DESTDIR)@libexecdir@/loudwater/play-base.png
	rm -f $(DESTDIR)@libexecdir@/loudwater/player.css
	rm -f $(DESTDIR)@libexecdir@/loudwater/player.html
	rm -f $(DESTDIR)@libexecdir@/loudwater/player-sparse.html
	rm -f $(DESTDIR)@libexecdir@/loudwater/player.js
	rm -f $(DESTDIR)@libexecdir@/loudwater/player.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/player.swf
	rm -f $(DESTDIR)@libexecdir@/loudwater/progressbar.gif
	rm -f $(DESTDIR)@libexecdir@/loudwater/redball.png
	rm -f $(DESTDIR)@libexecdir@/loudwater/remap.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/runspot.html
	rm -f $(DESTDIR)@libexecdir@/loudwater/runspot.js
	rm -f $(DESTDIR)@libexecdir@/loudwater/runspot.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/social_test.png
	rm -f $(DESTDIR)@libexecdir@/loudwater/swfobject.js
	rm -f $(DESTDIR)@libexecdir@/loudwater/test_player_config.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/test_player_head.txt
	rm -f $(DESTDIR)@libexecdir@/loudwater/track.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/utils.js
	rm -f $(DESTDIR)@libexecdir@/loudwater/vbanner.html
	rm -f $(DESTDIR)@libexecdir@/loudwater/version.pl
	rm -f $(DESTDIR)@libexecdir@/loudwater/vplay.png
	rm -f $(DESTDIR)@libexecdir@/loudwater/whiteball.png

EXTRA_DIST =  admin.js\
              admin.pl\
              admin-doc.html\
              andotag.html\
              banner.js\
              banner.pl\
              common.pl\
              expressInstall.swf\
              facebook.js\
              feed.pl\
              greenball.png\
              hbanner.html\
              hplay.png\
              listvars.pl\
              live.pl\
              makemap.html\
              makemap.pl\
              modieus.swf\
              play-base.png\
              player.css\
              player.html\
              player-sparse.html\
              player.js\
              player.pl\
              player.swf\
              progressbar.gif\
              redball.png\
              remap.pl\
              runspot.html\
              runspot.js\
              runspot.pl\
              social_test.png\
              swfobject.js\
              test_player_config.pl\
              test_player_head.txt\
              track.pl\
              vbanner.html\
              version.pl.in\
              vplay.png\
              utils.js\
              whiteball.png

CLEANFILES = *~
DISTCLEANFILES = *~
MAINTAINERCLEANFILES = *~ Makefile.in
