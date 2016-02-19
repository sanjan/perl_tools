#!/usr/bin/perl -w

use strict;
use warnings;
use Switch;
use utf8;
use httprequest;
use httpresponse;

my $logfile;
my $contents;
my $count=0;
my ($myhttpReq,$action,$threadId,$startDateandTime,$endDateandTime) = "";
my ($myhttpResp,$accountName,$httpVersion,$httpStatus) = "";
my ($startSeconds,$endSeconds) = "";

# mytempHash is needed because the thread is re-used.
my (%myhttpHash,%mytempHash);

$logfile = shift;

open (FILE, $logfile) or die "Can't Open $logfile !!";
while (<FILE>)
{
    $contents=$_;
    next if (($contents !~ /HttpConnection.*.REQUEST/) && ($contents !~ /HttpConnection.*.RESPONSE/));
    if (($contents =~ m/HttpConnection.*.REQUEST/))
    {
        my $nextline    = <FILE>;
        $contents      .= $nextline;

        $myhttpReq              = new httprequest($contents);
        $threadId               = $myhttpReq->getThreadId();
        $startDateandTime       = $myhttpReq->getDateandTime();
        $accountName            = $myhttpReq->getAccountName();
        $startSeconds           = $myhttpReq->getSeconds();

=for debug purpose
        print $myhttpReq->getRequest();
        print $myhttpReq->getSeconds()."\n";
        print $myhttpReq->getDateandTime()."\n";
        print $myhttpReq->getDate()."\n";
        print $myhttpReq->getTime()."\n";
        print $myhttpReq->getThreadId()."\n";
        print $myhttpReq->getAccountName()."\n";
=cut
        if ( defined($threadId) && defined($startDateandTime) && defined($accountName) && defined($startSeconds) )
        {
            $mytempHash{"$threadId"} = {'threadid'              => $threadId,
                                        'startdateandtime'      => $startDateandTime,
                                        'startseconds'          => $startSeconds,
                                        'accountname'           => $accountName};
        }
        undef $myhttpReq;
    }
    if (($contents =~ m/HttpConnection.*.RESPONSE/))
    {
        my $nextline = <FILE>;
        $contents .= $nextline;

        $myhttpResp             = new httpresponse($contents);
        $threadId               = $myhttpResp->getThreadId();
        $endDateandTime         = $myhttpResp->getDateandTime();
        $httpVersion            = $myhttpResp->getHttpVer();
        $httpStatus             = $myhttpResp->getHttpStatus();
        $endSeconds             = $myhttpResp->getSeconds();

=for debug purpose
        print $myhttpResp->getResponse();
        print $myhttpResp->getDateandTime()."\n";
        print $myhttpResp->getDate()."\n";
        print $myhttpResp->getTime()."\n";
        print $myhttpResp->getThreadId()."\n";
        print $myhttpResp->getHttpVer()."\n";
        print $myhttpResp->getHttpStatus()."\n";
=cut

        if (exists $mytempHash{$threadId})
        {
            $startDateandTime   = $mytempHash{$threadId}{"startdateandtime"};
            $threadId           = $mytempHash{$threadId}{"threadid"};
            $accountName        = $mytempHash{$threadId}{"accountname"};
            $startSeconds       = $mytempHash{$threadId}{"startseconds"};

            $myhttpHash{$startDateandTime} = {'threadid'        => $threadId,
                                              'startdateandtime'=> $startDateandTime,
                                              'enddateandtime'  => $endDateandTime,
                                              'accountname'     => $accountName,
                                              'httpver'         => $httpVersion,
                                              'duration'        => $endSeconds-$startSeconds,
                                              'status'          => $httpStatus};

            delete($mytempHash{$threadId});
        }
        undef $myhttpResp;
    }
=for to limit the number of lines
    last if ($count == 10 );
    $count = $count + 1;
    next;
=cut

}
close (FILE);

foreach my $key (sort keys %myhttpHash)
{
   if (exists $myhttpHash{$key})
   {

#=for debug purpose
        print $myhttpHash{$key}{"threadid"}.",";
        print $myhttpHash{$key}{"accountname"}.",";
        print $myhttpHash{$key}{"startdateandtime"}.",";
        print $myhttpHash{$key}{"enddateandtime"}.",";
        print $myhttpHash{$key}{"duration"}.",";
        print $myhttpHash{$key}{"httpver"}.",";
        print $myhttpHash{$key}{"status"};
#=cut
   }
   print "\n";
}

