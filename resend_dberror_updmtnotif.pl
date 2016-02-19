#!/usr/bin/perl
use strict;

if ($#ARGV < 1) {
        print "usage: $0 retrydir inputspool\n";
        exit 1;
}
my $dir = $ARGV[0];
my $spool = $ARGV[1];

opendir(DIR,"$dir")or die "Can't open $dir\n";

my @file = readdir(DIR);

foreach my $msg (@file) {
     if ($msg =~ /err$/){
        open (IN, "< $dir/$msg")or die "Can't open $msg\n";
        open (OUT,"> $dir/$msg.tmp") or die "Can't open $msg.tmp to write\n";

        my $retrycount = 0;
        while(my $line = <IN>) {
                chomp($line);
                if( $line !~ /retrycount/) {
                        print OUT "$line\n";
                        next;
                }
                else {
                        my @retry = split(/=/,$line);
                        $retrycount = $retry[1];
                }
        }
        if ($retrycount == 0 ){
                print OUT "retrycount=1\n";
                print "$dir/$msg never retried,retrycount added:1\n";
        }
        else {
                $retrycount = $retrycount+1;
                print "$dir/$msg retrycount added:$retrycount\n";
                print OUT "retrycount=$retrycount\n";
        }
        if ($retrycount < 4) {
                unlink("$dir/$msg") or warn "could't delete $dir/$msg : $!\n";
                rename ("$dir/$msg.tmp", "$spool/$msg.ini") or warn "Could't rename $dir/$msg.tmp :$!\n";
                print "move $dir/$msg.ini to $spool/$msg.ini\n";
        }
        else {
                unlink("$dir/$msg.tmp");
                rename ("$dir/$msg", "$dir/archive/$msg") or warn "Could't rename $dir/$msg: $!\n";
                print "already retried 3 times, put into archive\n";
        }

     }
}

close(DIR);
