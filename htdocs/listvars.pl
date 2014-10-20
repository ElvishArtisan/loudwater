#!/usr/bin/perl
#
# listvars.pl
#
# List all environmental variables
#

print "Content-type: text/html\n\n";

print "<table cellspacing=\"0\" cellpadding=\"5\" border=\"1\">\n";

foreach my $key (keys %ENV)
{
    print "<tr><td>".$key."</td><td>".$ENV{$key}."</td></tr>\n";

}
print "</table>\n";
