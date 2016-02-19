#!/usr/bin/perl
#----------------------------------------------------------------------------
# Author: Sanjan Grero (sanjan.grero@sap.com)
# File:   queue_depth.pl
#----------------------------------------------------------------------------

# Always use strict
use strict;
use Shell;
use Getopt::Long;

# Initialize strings
my $router = '';
my $port = '';
my $queue = '';
my $crouter = '';
my $result;
my @queue_result;
my $ip = '';
my $file='/opt/HUB/tmp/queue_depth.cli';
my $smq="swiftmq";
my $fixedqueue='';


# Get parameters
Getopt::Long::config('bundling');
GetOptions(
    "r|router=s"     => \$router,
    "p|port=s"       => \$port,
    "c|crouter=s"       => \$crouter,
    "s|smq=s"               =>      \$smq,
    "q|queue=s"             =>      \$fixedqueue
);

# Shortcircuit the switches
($router && $port && $crouter) || print_help("Warning: Not all required arguments were specified\n");

use Fcntl qw(:flock);
open(SELF,"<",$0) or die "Cannot open $0 - $!";
flock(SELF, LOCK_EX|LOCK_NB) or die "$0 is already running. please wait... ";


my $cli="java -cp /opt/HUB/$smq/jars/swiftmq.jar:/opt/HUB/$smq/jars/jline.jar:/opt/HUB/$smq/jars/jndi.jar:/opt/HUB/$smq/jars/jms.jar com.swiftmq.admin.cli.CLI smqp://localhost:$port plainsocket\@$router $file";

get_queues_list($fixedqueue);

if (@queue_result != 0){
foreach $queue (@queue_result)
{
        get_queue_count($queue);
        $queue =~ s/\r|\n//g;
        print "$queue : $result\n";
}
}
else {
print "No matching queue found!\n";
}

#clean up
unlink $file or warn "Could not delete temporary file: $file: $!";

#end

# sub functions
# get queues
sub get_queues_list {
                my $queuematch=shift;
        my $sh;
                #Generating CLI script
        open(CLI,">$file") or die("Can't create QueryQueue file: $!");
        print CLI "wr $crouter
        sr $crouter
        lc sys\$queuemanager/usage
        exit ";

        close(CLI);

        #Exec the Cli
                if ($queuematch eq "") {
        $sh=$cli . "| sed -ne '/----*/,\$p' | sed '/-----/d'| grep -v \"^tmp\"";
                }
                else {
                $sh=$cli . "|  sed -ne '/----*/,\$p' | sed '/-----/d'| grep -v \"^tmp\" | grep " . $queuematch;
                }
        open(EXEC,"$sh|") or die("Can't exec command: $!");
        push (@queue_result, "$_")
        while <EXEC>;
        close(EXEC) or die("No matching result. Can't close QueryQueue file: $!");

}

# Get the message count in a queue
sub get_queue_count {

        my $queue = shift||0;
        my $sh_result;
        my @result1 = ();

                #Generating CLI script
        open(CLI,">$file") or die("Can't create QueryQueue file: $!");
        print CLI "wr $crouter
        sr $crouter
        lc sys\$queuemanager/usage/$queue
        exit ";

        close(CLI);

        #Exec the Cli

        my $sh=$cli . "| grep messagecount";

        open(EXEC,"$sh|") or die("Can't exec QueryQueue file: $!");
        $sh_result=$_
        while <EXEC>;
        close(EXEC) or die("Can't close QueryQueue file: $!");
        @result1=split(' ',$sh_result);
        $result=$result1[2];
}

# Print usage
sub print_help {
    my $str = shift;

    print "\n";
    print "$str\n" if $str;
    print "Router Queue Depth Check.\n";
    print "\n";
    print "Usage: queue_depth.pl -r <local router name> -p <local router port> -c <router to be checked> (optional: -q <queue name pattern>)\n";
    print "\n";
    print "-r, --router=<router>\n";
    print "    The name of local router to connect to\n";
    print "-p, --port=<port>\n";
    print "    The port of the local router\n";
	print "-c, --crouter=<the name of the router needs to be checked>\n";
    print "    The router to be checked (where the queue is)\n\n";
	print "Optional arguments:\n\n";	
    print "-s, --smq=<smq directory name>\n";	
    print "    The smq directory name if differ from 'swiftmq'\n";
    print "-q, --queue=<queue name>\n";
    print "    The queue name pattern. some regex may work\n";
    print "\n";
    exit 1;
}

# Print version info
sub print_version {
    print "\n\$Id: $0, version 2.12 2015/02/02\$\n";
    exit 1;
}

