#!/opt/HUB/perl/bin/perl -w

#usage:
#postMT.pl <contentfilename> <url> <maxcount>
#example:
#/opt/HUB/scripts/postMT_HttpInput.pl /opt/production1/sample_httpinput.txt localhost:8000 1 mir3loadtest TIRXRBTD



use strict;
use LWP::UserAgent;

my $ua = new LWP::UserAgent;

my $start = time();

if ($ARGV[0] eq ""){
print "usage:\n";
print "postMT_HttpInput.pl <message content file> <submit url without username part> <number of messages> <userid> <password> <type of url ('test' or 'real')>\n";
exit;
}
my $file = $ARGV[0];
my $url = $ARGV[1];
my $maxcount= $ARGV[2];
my $user=$ARGV[3];
my $pwd=$ARGV[4];
my $type=$ARGV[5];
my $content = (`cat $file`);

#replace the value 'mobile365_92203' in below line to match the account username


my $request = HTTP::Request->new ("POST","http://$url/$user/$user.sms");

if ($type eq "test"){
$request = HTTP::Request->new ("POST","http://$url/$user/message-test.sms");
}

$request->content_type('application/x-www-form-urlencoded');

#replace the value 'mobile365_92203' in below line to match the account username and 'sbTt1yWC' to match the password
$request->authorization_basic($user,$pwd);
#$request->content("\n");
#$request->content("\r\n");
$request->content($content);
#$request->add_content($content);
$request->protocol('HTTP/1.1');
print $request->as_string;

my $count = 1;
while ($count <= $maxcount) {
        my $res = $ua->request($request);
        print $res->content;
        $count ++;
}

my $end = time();
printf("\nTime Taken : $maxcount MT / %i Seconds\n",$end-$start);
