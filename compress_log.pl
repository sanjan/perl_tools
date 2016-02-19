#!/usr/bin/perl


# Always use strict
use strict;
use File::Basename;

$| = 1; #enable autoflush for logging (logging under lance stops without this)

my $lockfile='/opt/HUB/tmp/compress_log.lock';
my $old_pid;
my $new_pid;
my @scanpaths = ("/opt/HUB/log");
my $archivepath = "/opt/HUB/log/archive";
my $century = `date +%C`;
my @files_to_compress;


#to ensure only one instance is running
if( -e $lockfile ){
        $old_pid = `cat $lockfile`;

        chomp($old_pid);

        #check process
        $new_pid=`ps auxfwww | grep compress_log.pl | grep -v "grep"   | tr -s " " | cut -f 2 -d " "`;

        if( $old_pid == $new_pid ){
                print `date +%F" "%T  | tr '\n' ' '` . " : (Old:$old_pid : New:$new_pid)Process already running...\n";
                exit 0;
        }
        else{
                print `date +%F" "%T  | tr '\n' ' '` . " : (Old:$old_pid : New:$new_pid)zombi lock, removing...\n";
                unlink($lockfile);
        }
}

#Get process pid
my $pid = `echo $$ > $lockfile`;
#end of check

#remove old files in archive directory

opendir DIR, "$archivepath";
my @oldarchivefiles = grep /\.gz$/, readdir DIR;
close DIR;

foreach my $oldarchivefile (@oldarchivefiles) {
    my @stat = stat("$archivepath/$oldarchivefile");
    if (int((time() - $stat[9])/60/60/24) > 7) {
        unlink("$archivepath/$oldarchivefile");
    }
}


#look for files to be archived

foreach my $scanpath (@scanpaths){

        print `date +%F" "%T  | tr '\n' ' '` . " : Processing path: $scanpath \n";

        #remove zero size log files older than a week
        #`find $scanpath -maxdepth 1 -type f -size 0 -mtime +7 | xargs rm -v`;

        #look for large files
        my @large_files = `find $scanpath -maxdepth 1 -type f -size +100000k \\( -name "*.log" ! -name "mtrouter.log" ! -name "*jms*.log" \\)`;
        #look for old files
        my @old_files = `find $scanpath -maxdepth 1 -type f -mtime +7 -name "*.log"`;
        #look for rotated files
        my @rotated_files = `find $scanpath -maxdepth 1 -type f -name "*.log.20*" -o -name "*.log*old"`;

        push (@files_to_compress, @large_files);
        push (@files_to_compress, @old_files);
        push (@files_to_compress, @rotated_files);

}

my $result = $#files_to_compress + 1;

if ($ result > 0){

        print `date +%F" "%T  | tr '\n' ' '` . " : INFO : $result log files need to be compressed\n";
        foreach my $file_to_compress (@files_to_compress) {
                chomp $file_to_compress;
                compress($file_to_compress);
        }
}

else {
        print `date +%F" "%T  | tr '\n' ' '` . " : INFO : NO log file needs to be compressed\n";
}

print `date +%F" "%T  | tr '\n' ' '` . " : INFO : Removing lock file: " . `rm -v $lockfile` . "\n";

print `date +%F" "%T  | tr '\n' ' '` . " : INFO : Processing complete!\n";


sub compress
{

# get timestamp
my $now = format_time(time());

#get the file to compress
my $file_to_compress = shift();

print print `date +%F" "%T  | tr '\n' ' '` . " : INFO : Processing : $file_to_compress\n";

        #if file not rotated, rotate it
        if( $file_to_compress =~ /log$/ ) {

                # Create a temp file, we redirect stdin and stdout to avoid losing data
                if(open(IN,"<$file_to_compress")) {
                        print `date +%F" "%T  | tr '\n' ' '` . " : INFO : Rotating log... writing to file : $file_to_compress.$now\n";
                        if(open(OUT,">$file_to_compress.$now")) {
                                while(<IN>) {
                                        print OUT "$_";
                                }
                        }
                        else {
                                close(IN);
                                die($!);
                        }
                        close(IN);
                        close(OUT);
                }

                # Rotate log file
                print `date +%F" "%T  | tr '\n' ' '` . " : INFO : Rotating log... emptying the current file : $file_to_compress\n";
                open(OUT,">$file_to_compress") or die($!);
                close(OUT);

                #change file to be compressed to rotated file name
                $file_to_compress = "${file_to_compress}.${now}";

        }


# Compress temp file
print `date +%F" "%T  | tr '\n' ' '` . " : INFO : Compressing : $file_to_compress\n";
print `date +%F" "%T  | tr '\n' ' '` . " " . `gzip -1 -v -f $file_to_compress` . "\n";

# Move compressed file to archive folder

my $filename = basename($file_to_compress);

print `date +%F" "%T  | tr '\n' ' '` . " " . `mv -v $file_to_compress.gz $archivepath/$filename.gz` . "\n";
print `date +%F" "%T  | tr '\n' ' '` . " " . `chown -v production1.prodops $archivepath/$filename.gz` . "\n";



}

sub format_time
{
    my $time = shift();
    my ($sec,$min,$hour,$dd,$mon,$yy,$wday,$yday,$isdst)= localtime($time);

    my $yyyy = $yy+1900;
    my $mm   = $mon+1;

    ($mm   < 10) and ($mm = "0$mm");
    ($dd   < 10) and ($dd = "0$dd");
    ($hour < 10) and ($hour = "0$hour");
    ($min  < 10) and ($min = "0$min");
    ($sec  < 10) and ($sec = "0$sec");

    return "$yyyy$mm$dd$hour$min$sec";
}
