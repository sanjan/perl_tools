#!/usr/bin/perl -I.

use strict;
use CGI qw/:standard/;
use CGI qw/:standard escapeHTML/;

my @names;

print header(-status=>'200'), start_html(-title=>'MO/NOTIF Receiving Check');
open (LOG, ">>/usr/mobileway/steven/tmp/$$.txt") or warn("cant open log: $!");
print LOG "------- start ---------\n";
@names = param();
open (PROG, "| /usr/sbin/sendmail -t") or die("cannot fork: $!");
print PROG "From: mo_notif_check
To: sanjan.grero\@sybase.com
Subject: New MO/NOTIF Received
";
foreach (@names)
{
    print LOG "$_ = ".param($_)."\n";
    print PROG "$_ = ".param($_)."\n";
}
print LOG "------- end ---------\n";
print "OK\n";
close(PROG);
close(LOG);
print end_html();
