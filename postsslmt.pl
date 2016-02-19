#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request;
#use LWP::Debug qw(+);
#use LWP::Debug qw(level); level('+');

use Time::localtime qw(localtime ctime);
use Time::HiRes;

#client authentication
$ENV{HTTPS_CERT_FILE} = '/var/home/cng/SSL/mw.pem';
$ENV{HTTPS_KEY_FILE}  = '/var/home/cng/SSL/mw.key';


my $ua = new LWP::UserAgent;

use LWP::ConnCache;
$ua->conn_cache(LWP::ConnCache->new());
#$ua->timeout(1);

my $url = $ARGV[0];
my $file1 = $ARGV[1];
my $num = $ARGV[2] || 10;

print "./test.pl $url $file1 $num\n";

my $msg1 = (`cat $file1`);
#my $msg2 = (`cat $file2`);

my $start = [Time::HiRes::gettimeofday()];

my $req1;
foreach (1..$num) {
        if (not defined $req1) {
        print "creating new http object...\n";

#$req1 = HTTP::Request->new ("POST","https://$url/citi_test_98859/citi_test_98859.sms");
#$req1->authorization_basic('citi_test_98859','CXiW5RQI');
#$req1 = HTTP::Request->new ("POST","https://$url/m365_hb_na20837/m365_hb_na20837.sms");
$req1 = HTTP::Request->new ("POST","https://$url/m365_hb_na20837/message-test.sms");
$req1->authorization_basic('m365_hb_na20837','FOI2aRPz');

#$req1->content_type('application/x-www-form-urlencoded');
#$req1->content_length(length($msg1));
#$req1->authorization_basic('y_fifa_tes14243','TwtUBCWx');
#$req1->header('Connection' => 'Keep-Alive');
#$req1->header('Host' => 'messsaging.mobile-way.com');
$req1->protocol("HTTP/1.1");
}
$req1->content($msg1);

#print $req1->as_string;

my $res1 = $ua->request($req1);
#$ua->request($req1);
print $res1->as_string;
#my $req1;
print $_ . "\n";
#print "\n\n=================================================\n\n";

}

my $proctime = Time::HiRes::tv_interval($start);
my $avg = sprintf("%.2f", $proctime/$num);
print "\n\nprocessing time $proctime\n";
print "average per request: " . $avg . "\n";
