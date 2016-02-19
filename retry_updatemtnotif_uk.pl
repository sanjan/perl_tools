#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use File::Path;
use File::Copy;
use File::Basename;

my $maxretry=5;

my $fr_inputspool_dir="/opt/HUB/NOTIF/updatemtnotif_fr/inputspool";
my $fr_dbnotfound_dir="/opt/HUB/NOTIF/updatemtnotif_fr/error/dbnotfound";
my $fr_dberror_dir="/opt/HUB/NOTIF/updatemtnotif_fr/error/database";

my $uk_inputspool_dir="/opt/HUB/NOTIF/updatemtnotif/inputspool";
my $uk_dbnotfound_dir="/opt/HUB/NOTIF/updatemtnotif/error/dbnotfound";
my $uk_dberror_dir="/opt/HUB/NOTIF/updatemtnotif/error/database";


my @fr_dbnotfound_files=glob ("${fr_dbnotfound_dir}/*.err");
my @fr_dberror_files=glob ("${fr_dberror_dir}/*.err");
my @fr_files_to_process;

push (@fr_files_to_process, @fr_dbnotfound_files );
push (@fr_files_to_process, @fr_dberror_files );


my @uk_dbnotfound_files=glob ("${uk_dbnotfound_dir}/*.err");
my @uk_dberror_files=glob ("${uk_dberror_dir}/*.err");
my @uk_files_to_process;

push (@uk_files_to_process, @uk_dbnotfound_files );
push (@uk_files_to_process, @uk_dberror_files );


print format_time(time()). " Processing FR spool ...\n";

foreach my $msg_file (@fr_files_to_process) {

my ($filename,$dir,$ext) = fileparse($msg_file, qr/\.[^.]*/); #get name of the file from full file name
my $file = $filename . $ext;
my $destdir="";
my $retrycount = -1;
my $procdb="";
my $filecontent="";
my $retrythis=0;

open( my $fh, '<', $msg_file ) or die "Can't open $msg_file: $!"; #open the notif file

while ( my $line = <$fh> ) {

#print format_time(time()) . " $file : $line";

if ( $line =~ /^retrycount/ ) {
  $retrycount=substr $line, 11;
  chomp($retrycount);
}
elsif ( $line =~ /^processedby/ ) {
  $procdb= substr $line, 12;
  chomp($procdb);
}
else{
  $filecontent .= $line;
}

}

close $fh; #close file handler

# process file

if (($retrycount == -1) || (($retrycount > 0) && ($procdb eq ""))) {

$filecontent .= "retrycount=1\n";
$filecontent .= "processedby=FR\n";
$destdir=$fr_inputspool_dir . "_" . gen_rand();
print format_time(time()) . " $file never retried, move to: $destdir\n";


}

elsif (($retrycount > 0) && ($retrycount < $maxretry)){

  $filecontent .= "retrycount=" . ($retrycount+1) . "\n";
  
  if ( $procdb eq "UK" ){
  $filecontent .= "processedby=Both\n";
  }
  else {
  $filecontent .= "processedby=" . $procdb . "\n";
  }

  $destdir=$fr_inputspool_dir . "_" . gen_rand();
  print format_time(time()) . " $file , retried: $retrycount time(s). move to: $destdir\n";
  
}

elsif ($retrycount == $maxretry){

  if ( $procdb eq "FR" ){
    $filecontent .= "retrycount=1\n";
    $filecontent .= "processedby=" . $procdb . "\n";
    $destdir=$uk_inputspool_dir . "_" . gen_rand();
    print format_time(time()) . " $file , max retries reached on FR. Switch to UK. move to: $destdir\n";
  }
  elsif ( $procdb eq "Both" ){
    $filecontent .= "retrycount=" . $retrycount . "\n";
    $filecontent .= "processedby=" . $procdb . "\n";
    $destdir=$dir . "archive";
    print format_time(time()) . " $file , retries on both FR & UK exhausted. move to: $destdir\n";
  }

}

my $newfile=$destdir .'/'. $filename . '.ini'; #change the new file path and modify extension to ini

open (OUT,"> $newfile") or die "Can't open: $newfile to write\n";
print OUT "$filecontent";

unlink($msg_file) or die "Can't delete: $msg_file\n";

print format_time(time()) . " $msg_file -> $newfile\n";

}


print format_time(time()). " Processing UK spool ...\n";


foreach my $msg_file (@uk_files_to_process) {

my ($filename,$dir,$ext) = fileparse($msg_file, qr/\.[^.]*/); #get name of the file from full file name
my $file = $filename . $ext;
my $destdir="";
my $retrycount = -1;
my $procdb="";
my $filecontent="";
my $retrythis=0;

open( my $fh, '<', $msg_file ) or die "Can't open $msg_file: $!"; #open the unsent file

while ( my $line = <$fh> ) {

#print format_time(time()) . " $file : $line";

if ( $line =~ /^retrycount/ ) {
  $retrycount=substr $line, 11;
  chomp($retrycount);
}
elsif ( $line =~ /^processedby/ ) {
  $procdb= substr $line, 12;
  chomp($procdb);
}
else{
  $filecontent .= $line;
}

}

close $fh; #close file handler

# process file

if (($retrycount == -1) || (($retrycount > 0) && ($procdb eq ""))) {

$filecontent .= "retrycount=1\n";
$filecontent .= "processedby=UK\n";
$destdir=$uk_inputspool_dir . "_" . gen_rand();
print format_time(time()) . " $file never retried, move to: $destdir\n";
}

elsif (($retrycount > 0) && ($retrycount < $maxretry)){

  $filecontent .= "retrycount=" . ($retrycount+1) . "\n";
  
  if ( $procdb eq "FR" ){
    $filecontent .= "processedby=Both\n";
  }
  else {
    $filecontent .= "processedby=" . $procdb . "\n";
  }
  
  $destdir=$uk_inputspool_dir . "_" . gen_rand();
  print format_time(time()) . " $file , retried: $retrycount time(s). move to: $destdir\n";
  
}

elsif ($retrycount == $maxretry){

if ( $procdb eq "UK" ){
  $filecontent .= "retrycount=1\n";
  $filecontent .= "processedby=" . $procdb . "\n";
  $destdir=$fr_inputspool_dir . "_" . gen_rand();
  print format_time(time()) . " $file , max retries reached on UK. Switch to FR. move to: $destdir\n";
}
elsif ( $procdb eq "Both" ){
  $filecontent .= "retrycount=" . $retrycount . "\n";
  $filecontent .= "processedby=" . $procdb . "\n";
  $destdir=$dir . "archive";
  print format_time(time()) . " $file , retries on both FR & UK exhausted. move to: $destdir\n";  
}

}

my $newfile=$destdir .'/'. $filename . '.ini'; #change the new file path and modify extension to ini

open (OUT,"> $newfile") or die "Can't open: $newfile to write\n";
print OUT "$filecontent";

unlink($msg_file) or die "Can't delete: $msg_file\n";;

print format_time(time()) . " $msg_file -> $newfile\n";

}


sub format_time {
    my $time = shift();
    my ($sec,$min,$hour,$dd,$mon,$yy,$wday,$yday,$isdst)= localtime($time);

    my $yyyy = $yy+1900;
    my $mm   = $mon+1;

    ($mm   < 10) and ($mm = "0$mm");
    ($dd   < 10) and ($dd = "0$dd");
    ($hour < 10) and ($hour = "0$hour");
    ($min  < 10) and ($min = "0$min");
    ($sec  < 10) and ($sec = "0$sec");

    return "$yyyy-$mm-$dd $hour:$min:$sec";
}

sub gen_rand {
return int(rand(3)) + 1;
}

