#!/usr/bin/pl

# test_player_config.pl
#
# This is the configuration file for "test".

# ############################################################################
# Player Title
# This will appear on the title bar of thr browser.

$player_title="World Net Daily Player";
# ############################################################################

# ############################################################################
# Splash Link
# This is the link to the "splash" media that will play when the player in
# first invoked.
$player_splash_link="http://live.radioamerica.org/images/wnd_technosis.flv";
# ############################################################################

# ############################################################################
# Live Link
# This is the link to the live stream.
$player_live_link="http://radio.radioamerica.org:8000/radioamerica.flv";
# ############################################################################

# ############################################################################
# Default Link
# This is what will play upon opening the player if no target is specified
# in the URL.
$player_default_link=$player_live_link;
# ############################################################################

# ############################################################################
# Player Audio Logo
# This is the URL for the logo to display on the player stage when playing
# audio-only content. 
$player_audio_logo_link="http://live.radioamerica.org/images/logo_wnd_ra.gif";
# ############################################################################

# ############################################################################
# Player Video Logo
# This is the URL for the logo to display on the player stage.
$player_video_logo_link="http://live.radioamerica.org/images/logo_wnd_small.gif";
# ############################################################################

# ############################################################################
# Live Link Start Times (UTC)
# This is the set of hours at which the player will begin offering the live 
# feed, expressed as a set of JavaScript array values.
#
# This value is in UTC!
$player_live_sun_start_hours="start_sun_hours[0]=0;";
$player_live_mon_start_hours="start_mon_hours[0]=14;start_mon_hours[1]=22;start_mon_hours[2]=0;";
$player_live_tue_start_hours="start_tue_hours[0]=14;start_tue_hours[1]=22;start_tue_hours[2]=0;";
$player_live_wed_start_hours="start_wed_hours[0]=14;start_wed_hours[1]=22;start_wed_hours[2]=0;";
$player_live_thu_start_hours="start_thu_hours[0]=14;start_thu_hours[1]=22;start_thu_hours[2]=0;";
$player_live_fri_start_hours="start_fri_hours[0]=14;start_fri_hours[1]=22;start_fri_hours[2]=0;";
$player_live_sat_start_hours="start_sat_hours[0]=0;";
# ############################################################################

# ############################################################################
# Live Link Lengths (Seconds)
# This is the length of time for which the player will offer the live 
# feed, expressed as a set of JavaScript array values.
#
# This value is in UTC!
$player_live_sun_lengths= "start_sun_lengths[0]=0;";
$player_live_mon_lengths= "start_mon_lengths[0]=18000;start_mon_lengths[1]=7200;";
$player_live_tue_lengths= "start_tue_lengths[0]=18000;start_tue_lengths[1]=7200;start_tue_lengths[2]=14400;";
$player_live_wed_lengths= "start_wed_lengths[0]=18000;start_wed_lengths[1]=7200;start_wed_lengths[2]=14400;";
$player_live_thu_lengths= "start_thu_lengths[0]=18000;start_thu_lengths[1]=7200;start_thu_lengths[2]=14400;";
$player_live_fri_lengths= "start_fri_lengths[0]=18000;start_fri_lengths[1]=7200;start_fri_lengths[2]=14400;";
$player_live_sat_lengths= "start_sat_lengths[0]=14400;";
# ############################################################################

# ############################################################################
# Live Show Divider Hour
# The dividing line between the 'LIVE1' and 'LIVE2' programs.
$player_live_divider_hour=20;
# ############################################################################

# ############################################################################
# Live Logos
$player_live_ondemand_link="http://live.radioamerica.org/images/logo_wnd_ra.gif";
$player_live_live1_link="http://live.radioamerica.org/wnd/images/logo-liddy.jpg";
$player_live_live2_link="http://live.radioamerica.org/wnd/images/logo-hedgecock.jpg";
# ############################################################################

# ############################################################################
# Live Link Button Image
# This is the URL to the image to display on the Live Feed button.
$player_live_button_image="http://live.radioamerica.org/images/btn-talkradio.gif";
# ############################################################################

# ############################################################################
# Live Feed Inactive Link
# This is the URL to return if the LIVE button is clicked when the live
# feed is inactive.
$player_live_inactive_link="http://feeds.radioamerica.org/rd-bin/rdfeed.xml?WND";
# ############################################################################

# ############################################################################
# ANDO Station ID
# The ANDO Station ID (SID) to use for getting ads.

$player_sid=9422;
# ############################################################################

# ############################################################################
# Gateway Spot Bitrate/Quality
# The audio quality/bitrate to use for the gateway ad.  Three levels are 
# available: "High" (adURL_high), "Medium" (adURL_med) or "Low" (adURL_low)

$player_gateway_quality="adURL_med";
# ############################################################################

# ############################################################################
# On-Demand Button 1 Image
# This is the URL to the image to display on On Demand button #1.
$player_ondemand_button1_image="http://live.radioamerica.org/images/news2.gif";
# ############################################################################

# ############################################################################
# On-Demand Button 1 Link
# This is the URL to the image to the target for the On Demand button #1.
$player_ondemand_button1_link="http://feeds.radioamerica.org/rd-bin/rdfeed.xml?DWP";
# ############################################################################

# ############################################################################
# On-Demand Button 2 Image
# This is the URL to the image to display on On Demand button #1.
$player_ondemand_button2_image="http://live.radioamerica.org/images/commentary2.gif";
# ############################################################################

# ############################################################################
# On-Demand Button 2 Link
# This is the URL to the image to the target for the On Demand button #1.
$player_ondemand_button2_link="http://live.radioamerica.org/wnd/video/commentary.xml";
# ############################################################################

# ############################################################################
# On-Demand Button 3 Image
# This is the URL to the image to display on On Demand button #1.
$player_ondemand_button3_image="http://live.radioamerica.org/images/satire2.gif";
# ############################################################################

# ############################################################################
# On-Demand Button 3 Link
# This is the URL to the image to the target for the On Demand button #1.
$player_ondemand_button3_link="http://live.radioamerica.org/wnd/video/satire.xml";
# ############################################################################

# ############################################################################
# Top Banner
# This is the HTML to display for the top banner (<IMG>+<A> tags).
$player_top_banner="<script type=\"text/javascript\">GA_googleFillSlot(\"WND_PLYR_P728\");</script>";
# ############################################################################

# ############################################################################
# Side Banner
# This is the HTML to display for the top banner (<IMG>+<A> tags).
$player_side_banner="<script type=\"text/javascript\">GA_googleFillSlot(\"WND_PLYR_P300\");</script>";
# ############################################################################

# ############################################################################
# Live Flashvars
# This string will be appended to the 'flashvars' value for the live player.
$player_live_flashvars="";
# ############################################################################

# ############################################################################
# On Demand Flashvars
# This string will be appended to the 'flashvars' value for the on demand
# player.
$player_ondemand_flashvars="";
# ############################################################################

# ############################################################################
# Optional Links Area
# This is code to render the optional links at the bottom of the player.
$player_optional_link_code="&nbsp;";
# ############################################################################
