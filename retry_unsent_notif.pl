#!/opt/HUB/perl/bin/perl

use strict;
use warnings;
use File::Find;
use File::Path;
use File::Copy;
use File::Basename;
use Storable;
use Time::HiRes qw( usleep );

# Script for the retry of unsent httpsmtpnotifs
# Author: Sanjan Grero (sanjan.grero@sap.com)
# (c) 2012 SAP Mobile Services

$| = 1; #enable autoflush for logging (logging under lance stops without this)

my $unsent_folder="/opt/HUB/NOTIF/httpsmtpnotify/unsent";
my $http_input_folder="/opt/HUB/NOTIF/updatemtnotif/outputspool/http";
my $https_input_folder="/opt/HUB/NOTIF/updatemtnotif/outputspool/https";
my $smtp_input_folder="/opt/HUB/NOTIF/updatemtnotif/outputspool/smtp";
my $hash_file="/opt/HUB/etc/retry_unsent_notif.hash"; #hash file
#matching erroneous URLs

my @unreachable = ( qr/.*localhost.*/, qr/.*192\.168\.60\.99.*/, qr/.*127\.0\.0\.1.*/, qr/.*telekom-gewinnspiele\.de\/sybase.*/, qr/.*ack\.ota\.com\.tw:8888\/default\.asp.*/, qr/.*ameren\.ifactornotifi\.com\/notifi\/sms\/inbound\/sybase.*/, qr/.*trc-sms\.emv2\.com\/SDN.*/ );
my @httperror = ( qr/.*Not Found.*/, qr/.*Proxy authentication required.*/, qr/.*Method not allowed.*/, qr/.*Moved permanently.*/, qr/.*Bad gateway.*/, qr/.*Bad request.*/ );

my %retrydb; #hash table to keep retry count

if (! -e $hash_file ){
        open( my $fh, '>', $$hash_file ) or die "Can't create $hash_file: $!";
        close $fh;
}

if (! -z $hash_file){
        %retrydb = %{retrieve($hash_file)}; #retrieve hash from file
}

my $max_retry=$ARGV[0]; #maximum retry count for a notification
my $wait=$ARGV[1]; #waiting time interval between scanning directories

while (1) { # Start of job


print "INFO: STARTING DIRECTORY SCAN\n";


my @customers= glob ("${unsent_folder}/*"); #get list of customer directories
my $totalretried=0;
my $totalexpired=0;
my $newretries=0;
my $throttle=0;

my $dir = '/opt/HUB/NOTIF/updatemtnotif/outputspool/http';
my @spoolfiles = <$dir/*>;
my $spoolcount = @spoolfiles;

print "INFO: current spool in /opt/HUB/NOTIF/updatemtnotif/outputspool/http : $spoolcount\n";

if ( $spoolcount > 1000 ){

print "INFO: enabling throttle because of high spool\n";
$throttle =1;

}

foreach my $customer(@customers) { #loop through each customer directory

        if ( -d $customer ) { #check if its a customer directory

                my @files=glob ("${customer}/*.un"); #get list of unsent files
                                my $count=@files;

                my ($customerpath,$customerid)=split(/\/([^\/]+)$/, $customer); #get customerid from path

        if ($count > 0){

                                my $retried = 0;
                                my $expired = 0;

                print "INFO: Start processing for customer $customerid. $count file(s) are in spool.\n";

                                unless (-d "${customer}/expired"){
                                        mkpath("${customer}/expired"); #if there is no expired directory create it
                                        print "INFO: Created expired directory $customer/expired\n";
                                }

                foreach my $unsent_file(@files) { # Run the task for each unsent notif in the customer folder

                                                                                                if ( $throttle == 1) {
                                                                                                usleep(10);
                                                                                                }

                                                my ($filename,$dir,$ext) = fileparse($unsent_file, qr/\.[^.]*/); #get name of the file from full file name

                                                #print "DEBUG: Found unsent file $filename$ext\n";

                                                my @fileinfo = split (/-/,$filename); #split filename to get orderid and messageid

                                                my $key=$fileinfo[1] . $fileinfo[2]; # key is orderid followed by messageid

                                                my $curtime = time(); #get current time in seconds

                                                unless(exists $retrydb{$key}){ #if information for this orderid not exist in hash, add it to the hash
                                                $retrydb{$key} = "0-$curtime"; # value of hash is retry count initiated with zero
                                                $newretries++;
                                                }

                                                my $keyvalue = $retrydb{$key};
                                                my @keyvaluearray = split (/-/,$keyvalue);

                                                my $nb_retry = $keyvaluearray[0]; #retrieve retry count from hash

                                                #print "DEBUG: $filename$ext has been retried for $nb_retry time(s)\n";

                                                my $destdir;

                                                if ( $nb_retry < $max_retry ){ #check if file been retried maximum number of times

                                                        $retrydb{$key}=++$nb_retry . "-$curtime"; #update retry count in hash

                                                        my $destline;
                                                                                                                my $errorline;

                                                        #find the mail reply line
                                                        open( my $fh, '<', $unsent_file ) or die "Can't open $unsent_file: $!"; #open the unsent file
                                                        while ( my $line = <$fh> ) {
                                                                if ( $line =~ /^MailReply/ ) { #look for line with MailReply parameter
                                                                        $destline=substr $line, 10; #get value of the MailReply parameter
                                                                        chomp($destline); #trim unwanted characters at the beginning and end
                                                                }

                                                                if ( $line =~ /^ErrorString/ ) { #look for line with HTTP error description parameter
                                                                        $errorline=substr $line, 12; #get value of the MailReply parameter
                                                                        chomp($errorline); #trim unwanted characters at the beginning and end
                                                                }
                                                        }
                                                        close $fh; #close file handler

                                                        #print "DEBUG: $filename$ext has URL $destline\n";

                                                        if ( $destline ~~ @unreachable ) { #check if mail reply URL is an unreachable url
                                                                print "WARN: $filename$ext has an unreachable url:$destline. Moving to expired directory.\n";
                                                                delete($retrydb{$key}); #delete information from the hash
                                                                $destdir=$customer . '/expired'; #set destination to expired spool if contain a local URL
                                                                $expired++;
                                                        }
                                                        elsif ( $errorline ~~ @httperror ) { #check if error line is 4xx errors
                                                                print "WARN: $filename$ext url reply was:$errorline. Moving to expired directory.\n";
                                                                delete($retrydb{$key}); #delete information from the hash
                                                                $destdir=$customer . '/expired'; #set destination to expired spool if contain a local URL
                                                                $expired++;
                                                        }
                                                        elsif (index($destline,"http:") != -1) {
                                                                $destdir=$http_input_folder; #set destination to http spool if protocol is http
                                                                $retried++;
                                                        }
                                                        elsif (index($destline,"https:") != -1) {
                                                                $destdir=$https_input_folder; #set destination to https spool if protocol is https
                                                                $retried++;
                                                        }
                                                        else {
                                                                $destdir=$smtp_input_folder; # treat the rest of the destinations as smtp. (this need to be reconsidered)
                                                                $retried++;
                                                        }

                                                }
                                                else { #if retry count exceed the maximum retry count
                                                        print "WARN: $filename$ext has already reached the maximum retry count. Moving to expired directory.\n";
                                                        delete($retrydb{$key}); #delete information from the hash
                                                        $destdir=$customer . '/expired'; #set destination to expired spool
                                                        $expired++;

                                                }

                                                my $newfile=$destdir .'/'. $filename . '.ini'; #change the new file path and modify extension to ini

                                                move($unsent_file, $newfile) or die "Move file failed: $!"; ; #move the file to destination
                                                #print "DEBUG: Moved $filename$ext to $newfile\n";

                                } #done for unsent_file

                                print "REPORT: Completed processing for customer $customerid. Retried: $retried, Expired: $expired\n";
                                $totalretried = $totalretried + $retried;
                                $totalexpired = $totalexpired + $expired;

        } #done for count > 0
        }
} #done for customer directory

print "REPORT: Total retried: $totalretried (New: $newretries), Total expired: $totalexpired. Total processed: " . ($totalretried + $totalexpired) . "\n";
print "INFO: FINISHED DIRECTORY SCAN\n";

print "INFO: Initiating Hash Scan. Hash Size: ".keys( %retrydb )."\n";

while ((my $key, my $value) = each(%retrydb)){

        my @valuearray = split (/-/,$value);

        my $timediff = time() - $valuearray[1];

    if ( $timediff > 21600 ){ #delete information about orderid's older than 6 hours in retry. (because the retry should have been successful)
#               print "Deleting ".$key.", ".$value.", ".$timediff."\n";
                delete($retrydb{$key});
        }
}

print "INFO: Finished Hash Scan. Removed OrderID info older than 6 Hours. New Hash Size: ".keys( %retrydb )."\n";



print "------------------------------WAITING FOR NEXT RUN--------------------------------\n";

store(\%retrydb,$hash_file); # store hash to a file

sleep $wait; #wait before looping again

} #end of while loop
