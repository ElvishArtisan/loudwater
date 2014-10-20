#!/usr/bin/perl

# statest.pl
#
# (C) Copyright 2011 Fred Gleason <fredg@paravelsystems.com>
#
#  Generate a Loudwater Client Report
#
#   USAGE loudwater_stats_client_report.pl <table-name> <date>

use Date::Manip;

do "loudwater_stats_common.pl";


my $err="";
$dbh=&OpenDb();

my $table=$ARGV[0];
my $date=ParseDate($ARGV[1]);
my $bg0="#EEEEEE";
my $bg1="#FFFFFF";

#
# Header
#
print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"0\" width=\"600\">\n";
print "<tr><td align=\"center\"><strong>LOUDWATER CLIENT/DEVICE REPORT</strong></td></tr>\n";
print "<tr><td align=\"center\">".UnixDate($date,"%B %Y")."</td></tr>\n";
print "</table>\n";


#
# Operating Systems
#
my $counted=0;
print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"0\" width=\"600\">\n";
print "<tr><th colspan=\"4\">PLATFORMS</th></tr>\n";
$total=scalar(&IpCount($dbh,$table,"USER_AGENT is not null"));
$counted+=&ReportLine("Android Device","android-16x16.png",
		      scalar(&IpCount($dbh,$table,
			     "USER_AGENT like \"%android%\"")),$total,$bg0);
$counted+=&ReportLine("Apple iOS Device","ipod-16x16.png",
		      scalar(&IpCount($dbh,$table,
			     "USER_AGENT like \"%ipod%\"")),$total,$bg1);
$counted+=&ReportLine("Apple MacIntosh Computer","osx-16x16.png",
		      scalar(&IpCount($dbh,$table,
			     "USER_AGENT like \"%macintosh%\"")),$total,$bg0);
$counted+=&ReportLine("BlackBerry Device","blackberry-16x16.png",
		      scalar(&IpCount($dbh,$table,
			     "USER_AGENT like \"%blackberry%\"")),$total,$bg1);
$counted+=&ReportLine("Linux Computer","linux-16x16.png",
		      scalar(&IpCount($dbh,$table,
			     "USER_AGENT like \"%linux%\"")),$total,$bg0);
$counted+=&ReportLine("Microsoft Windows Computer","windows-16x16.png",
		      scalar(&IpCount($dbh,$table,
			     "USER_AGENT like \"%windows%\"")),$total,$bg1);
&ReportLine("Other/Unknown:","question-16x16.png",$total-$counted,$total,$bg0);
#&ReportLine("TOTAL:","",$total,$total,$bg1);
print "<tr><td colspan=\"4\">&nbsp;</td></tr>\n";
print "</table>\n";

#
# Browsers/Clients
#
$counted=0;
print "<table cellpadding=\"5\" cellspacing=\"0\" border=\"0\" width=\"600\">\n";
print "<tr><th colspan=\"4\">BROWSER/CLIENT</th></tr>\n";
$counted+=&ReportLine("Chrome:","chrome-16x16.png",scalar(&IpCount($dbh,$table,
				    "USER_AGENT like \"%chrome%\"")),$total,$bg0);
$counted+=&ReportLine("Firefox:","firefox-16x16.png",
		      scalar(&IpCount($dbh,$table,
				      "USER_AGENT like \"%firefox%\"")),$total,$bg1);
$counted+=&ReportLine("iTunes:","itunes-16x16.png",scalar(&IpCount($dbh,$table,
				    "USER_AGENT like \"%itunes%\"")),$total,$bg0);
$counted+=&ReportLine("Internet Explorer:","ie-16x16.png",scalar(&IpCount($dbh,$table,
				    "USER_AGENT like \"%msie%\"")),$total,$bg1);
$counted+=&ReportLine("Opera:","opera-16x16.png",scalar(&IpCount($dbh,$table,
				    "USER_AGENT like \"%opera%\"")),$total,$bg0);
$counted+=&ReportLine("Safari:","safari-16x16.png",scalar(&IpCount($dbh,$table,
				    "USER_AGENT like \"%safari%\"")),$total,$bg1);
$counted+=&ReportLine("Yahoo Pipes:","yahoopipes-16x16.png",scalar(&IpCount($dbh,$table,
				    "USER_AGENT like \"%yahoo pipes%\"")),$total,$bg0);
&ReportLine("Other/Unknown:","question-16x16.png",$total-$counted,$total,$bg1);
#&ReportLine("TOTAL:","",$total,$total,$bg0);
print "<tr><td colspan=\"4\">&nbsp;</td></tr>\n";
print "</table>\n";
exit(0);


sub ReportLine
{
    my($title,$image,$count,$total,$bgcolor)=@_;

    my $img="&nbsp;";
    if($image ne "") {
	$img="<img src=\"/loudwater/images/".$image."\" border=\"0\">";
    }
    print "<tr bgcolor=\"".$bgcolor."\">";
    print "<td width=\"20\">".$img."</td>";
    print "<td>".$title."</td>";
    printf "<td align=\"right\">".$count."</td><td width=\"60\" align=\"right\">%5.1f%%</td>",100*$count/$total;
    print "</tr>\n";

    return $count;
}
