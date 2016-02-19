#!/usr/bin/perl -w

use strict;
use Fcntl qw(:DEFAULT :flock);
use Time::Local;
use POSIX qw(strftime);
use File::stat;

#Define constant
my $DEBUG="Debug";
my $INFO="Info";
my $WARN="Warning";
my $ERROR="Error";
my $FATAL="Fatal";

my $EXIT_OK=0;
my $EXIT_NOK=-1;
my $KeepAlive=10000; #every $KeepAlive a log is display

#Define configuration file constant
my $SECTION_ORACLE="[ASE]";
my $SECTION_EXTRACT="[EXTRACT]";
my $TAG_ORACLE_SQLPLUS="ASE_isql";
my $TAG_ORACLE_USER="ASE_user";
my $TAG_ORACLE_PASS="ASE_pass";
my $TAG_ORACLE_BASE="ASE_base";

#ASE config
#ASE_isql=/opt/HUB/sybase/SDK-15.5/OCS-15_0/bin/isql
#ASE_base=DEV101
#ASE_user=a2p_admin
#ASE_pass=sqlsql


#Define oracle authentication file constant
#my $SECTION_BASE="[BASE]";
#my $TAG_LOGIN="LOGIN";
#my $TAG_PASSWORD="PASSWORD";

#Define setup file constant
my $SECTION_SETUP="[SETUP]";
my $TAG_DEBUG="Debug";
my $TAG_LOCK_FILE="LockFileName";
my $TAG_BACKUP_PATH="BackUpPath";

#define global variables
my $LOCK_PATH="/usr/mobileway/tmp";
my $BackUpPath="/usr/mobileway/tmp";
my $user="";
my $TraceLevel=0;

$|=1;                   #Set automatic flush at each \n print

my $ExitRequest= 0;   # to ensure it has a value
#$SIG{INT} = sub {
#    $ExitRequest++;
#};

$user=defined ($ARGV[1])? $ARGV[1] : getpwent(); # set the user name of the command

&main($ARGV[0],$user);  #Call main program, give configuration file and the user name in argument

sub main{
        #Get argument
        my $configuration_file=$_[0];
        my $user=$_[1];

        #Declaration
        my %configuration_file_hash;                    #Global hash table containing configuration file parameters
        my %oracle_authentication_file_hash;            #Global hash table containing oracle authentication file parameters
        my $LockSet;
        my $FullLockPath="";
        my $LockFileName="";

        display($INFO,"$configuration_file $user");
        display($INFO, "Start / maj_ase");
        if(-f $configuration_file){
                if(-r $configuration_file){
                        display($INFO,"Load configuration file \"$configuration_file\"");
                        %configuration_file_hash=load_configuration_file($configuration_file);
                        display($INFO,"Load configuration file \"$configuration_file\", done");
                        display($INFO,"");
                        display($INFO,"Start / Display configuration file settings");
                        print_configuration_file(\%configuration_file_hash);
                        display($INFO,"End / Display configuration file settings");
                        display($INFO,"");

                        my $Sqlplus=$configuration_file_hash{$SECTION_ORACLE}{$TAG_ORACLE_SQLPLUS};
                        my $Database=$configuration_file_hash{$SECTION_ORACLE}{$TAG_ORACLE_BASE};
                        my $Login=$configuration_file_hash{$SECTION_ORACLE}{$TAG_ORACLE_USER};
                        my $Password=$configuration_file_hash{$SECTION_ORACLE}{$TAG_ORACLE_PASS};
                        $TraceLevel=$configuration_file_hash{$SECTION_SETUP}{$TAG_DEBUG};
                        $LockFileName=$configuration_file_hash{$SECTION_SETUP}{$TAG_LOCK_FILE};
                        my $tmp=$configuration_file_hash{$SECTION_SETUP}{$TAG_BACKUP_PATH};

                        if( defined($tmp)){
                                if($tmp ne ""){ #check if the path is terminated by a slash
                                        my $bpath = substr($tmp, -1, 1);
                                        $BackUpPath = $tmp;
                                }
                        }
                        $BackUpPath .="/" if( $BackUpPath ne "/");

                        display($INFO,"Set Datafile Back-Up path to \"$BackUpPath\"");

                        if( not defined($TraceLevel)){
                                $TraceLevel=0;
                        }else {
                                $TraceLevel=0 if ( $TraceLevel eq "");
                        }

                        #if($Section ne "" and $Base ne ""){
                                #if(-f $Authfile){
                                        #if(-r $Authfile){
                                                #display($INFO,"Load authentication file \"$Authfile\"");
                                                #%oracle_authentication_file_hash=load_configuration_file($Authfile);
                                                #display($INFO,"Load authentication file \"$Authfile\", done");

                                                #my $Login=$oracle_authentication_file_hash{"[$Section]"}{$TAG_LOGIN};
                                                #my $Password=$oracle_authentication_file_hash{"[$Section]"}{$TAG_PASSWORD};
                                                #my $Database=$oracle_authentication_file_hash{$SECTION_BASE}{$Base};

                                                if( not defined ($LockFileName)){
                                                        display($WARN,"Undefined lockfilename in configuration file");
                                                        display($WARN,"Use $Database as lockfilename");
                                                        $LockFileName=$Database;
                                                }
                                                if(($LockFileName=~/\//) and ($LockFileName ne "")){ #get a path as lockfilename
                                                         $FullLockPath=$LockFileName;
                                                }else{
                                                        $FullLockPath=sprintf("%s/%s",$LOCK_PATH,$LockFileName);
                                                }

                                                if($Login ne "" and $Password ne "" and $Database ne ""){
                                                        display($INFO,"");
                                                        $LockSet=LockProcessing($FullLockPath,$user);
                                                        display($INFO,"");
                                                        if( $LockSet == $EXIT_OK){
                                                                if(-f $Sqlplus){                #If sqlplus program exist
                                                                        if(-x $Sqlplus){        #and if have right access on sqlplus program, then make the extract
                                                                                display($INFO,"Sqlplus program \"$Sqlplus\" exist and have executable right access");
                                                                                my $authentication=$Login."/".$Password."@".$Database;
                                                                                display($INFO,"");
                                                                                display($INFO,"Start / datafiles generation");

                                                                                my $sql;
                                                                                display($DEBUG,"ASE Login :  $authentication");

                                                                                #For each .sql in EXTRACT section, make extraction
                                                                                foreach $sql ( keys %{ $configuration_file_hash{$SECTION_EXTRACT} }) {
                                                                                        if ( not $ExitRequest){
                                                                                                if(-f $sql){
                                                                                                        if(-r $sql){
                                                                                                                my $tmp=$configuration_file_hash{$SECTION_EXTRACT}{$sql};
                                                                                                                (my $dat,my $empty)=split(',',$tmp,2);
                                                                                                                # use $empty if $empty is defined, else 0
                                                                                                                extract($Sqlplus, $Login,$Password,$Database, $sql, $dat,defined($empty)? $empty : 0, $user);
                                                                                                        }else{
                                                                                                        display($ERROR,"Sql file \"$sql\" can't be read from filesystem, skip datafile generation");
                                                                                                        }
                                                                                                }else{
                                                                                                        display($ERROR,"Sql file \"$sql\" doesn't exist on filesystem, skip datafile generation");
                                                                                                }
                                                                                        }else{
                                                                                                display($FATAL,"Trap signal. Stop Processing");
                                                                                                last;
                                                                                        }
                                                                                }

                                                                                display($INFO,"End / datafiles generation");
                                                                                display($INFO,"");
                                                                                display($INFO, "End / maj_ase, success");
                                                                                UnlockProcessing($FullLockPath) if( $LockSet!= $EXIT_NOK);
                                                                                exit($EXIT_OK);
                                                                        }else{  display($FATAL, "Doesn't have execution access right on sqlplus program : \"$Sqlplus\"");}
                                                                }else{  display($FATAL, "Sqlplus program : \"$Sqlplus\" doesn't exist on filesystem");}
                                                        }
                                                }else{
                                                        display($FATAL, "missing login/password/base parameters");
                                                }
                                        #}else{ display($FATAL, "Doesn't have read access right on configuration file : \"$configuration_file\"");}
                                #}else{ display($FATAL, "Oracle authentication file : \"$Authfile\" doesn't exist on filesystem");}
                        #}else{ display($FATAL, "Missing parameters inside configuration file \"$configuration_file\" to retrieve authentication parameters");
                        #       display($FATAL, "Here the parameters, $TAG_ORACLE_SECTION=\"$Section\", $TAG_ORACLE_BASE=\"$Base\"");
                        #}
                }else{  display($FATAL, "Doesn't have read access right on configuration file : \"$configuration_file\"");}
        }else{  display($FATAL, "Configuration file : \"$configuration_file\" doesn't exist or is not a regular file");}

        display($FATAL, "End maj_ase, failed");
        if (defined ($LockSet)){
                UnlockProcessing($FullLockPath) if( $LockSet != $EXIT_NOK);
        }
        exit($EXIT_NOK);
}

sub display{
        my $level=$_[0];
        return if(($level =~ $DEBUG ) && ($TraceLevel == 0)); #debug mode ??
        my $message=$_[1];
        my $Time=GetTime("%Y/%m/%d %H:%M:%S");
        if($TraceLevel){
                (my $nada,my $nada2,my $fctname) = split (':', (caller(1))[3]);
                my $fctline =  (caller(0))[2];

                printf "$Time : ($$) - [ $fctname : $fctline ] - $level - $message\n"

        }else { printf "$Time : ($$) - $level - $message\n";}
}

sub load_configuration_file($){
        #Get argument
        my $file_name=$_[0];
        my %configuration_file_hash;

        #Initialization
        my $SECTION_EMPTY="[]";
        my $NO=0;
        my $YES=1;

        #Declaration
        my $section_key=$SECTION_EMPTY;                 #Containing the current section name, initialize to empty section []
        my $tag;                                        #Containing the current tag name
        my $value;                                      #Containing the current tag value
        my $line;                                       #Containing the current readline value

        my $is_necessary_to_create_empty_section=$YES;

        open (IN,$file_name);
        while ($line = <IN>){
                chomp($line);
                $line =~ s/^\s*$//g;                                            #Trim line, remove all blank and space character
                if($line =~ /^#/ or $line eq ""){                               #It's a comment or a blank line, don't load in memory
                }elsif($line =~ /^\[.*\]/){                                     #It's a section, create a new hash table
                        $section_key=$line;
                        $is_necessary_to_create_empty_section=$NO;              #Disable creation of empty section
                }else{                                                          #It's a tag=value to add to current section
                        if($section_key eq $SECTION_EMPTY and $is_necessary_to_create_empty_section == $YES){
                                $is_necessary_to_create_empty_section=$NO;
                        }
                        ($tag, $value) = split /=/, $line;                      #Split the line into tag and value, the delimiter is '=' char

                        $configuration_file_hash{$section_key}{$tag}=$value;
                        display($DEBUG,"$section_key : $tag : $configuration_file_hash{$section_key}{$tag}");
                }
        }
        close (IN);

        return %configuration_file_hash;
}

#Print the content of a configuration file previously loaded with load_configuration_file function
sub print_configuration_file(\%){
        #Get argument
        my (%hash) = %{(shift)};

        #Declaration
        my $section_key;
        my $tag;
        my $value;

        foreach $section_key ( keys %hash ) {
                display($INFO,"$section_key");
                foreach $tag ( keys %{ $hash{$section_key} } ) {
                        $value=$hash{$section_key}{$tag};
                        display($INFO,"$tag=$value");
                }
        }
}


# ---------------------------------------
sub extract{
        my $sqlplus=$_[0];
        my $db_user =$_[1];
        my $db_pass =$_[2];
        my $db_base =$_[3];
        my $sql_file = $_[4];
        my $output = $_[5];
        my $CanBeEmpty=$_[6];
        my $CurrentUser=$_[7];
        my $sql = "$sqlplus -S $db_base -U $db_user -P $db_pass -w 3000 -i $sql_file";
        #my $sql = "$sqlplus -S $db_base -U $db_user -P $db_pass -w 3000 -s\\' -i $sql_file";
        display($INFO, $sql);

        my $out_tmp = "$output.tmp";
        my $BackUpDone = 0;
        my $BackUpName ="";
        my $OracleError = 0;
        my $OracleErrorString = "";
        my $Log=0;
        my $DataFileIsEmpty=1;
        my $retsys="";


        display($DEBUG,"ARGS :  $sqlplus  $db_user $db_pass $db_base  $sql_file $output $CanBeEmpty");
        display($INFO,"Datafile generation \"$output\" by using \"$sql_file\"");
        display($DEBUG,"Sqlplus client : $sqlplus");
        display($DEBUG,"Sql query file : $sql_file");
        display($DEBUG,"Sql login/pwd : $sql");
        display($DEBUG,"DataFile Name : $output");
        display($INFO,($CanBeEmpty)?"The Datafile can be empty":"The Datafile can't be empty");

        $BackUpName = GenerateBackUpName($output) if (-e $output); #check if file exist and generate the name for the back-up file

        unless (open(IN,"$sql|")){
                display($ERROR,"Can't execute sqlplus \"$sql\", $!\n");
                display($ERROR,"Datafile generation \"$output\", failed");
                return $EXIT_NOK;
        }

        unless (open(OUT,">$out_tmp")) {
                display($ERROR,"Can't open temporary file \"$out_tmp\" for writing, $!");
                display($ERROR,"Datafile generation \"$output\", failed");
                return $EXIT_NOK;
        }

        while(<IN>){
                s/(^\s*)|(\s*$)//g;     # remove leading or trailing space
                if (not /^.*(;.*)*;$/){ # skip invalid lines
                        if(/^ORA/){ # oracle error , print them
                                display($ERROR,"$_");
                                display($FATAL,"Datafile generation \"$output\", failed");
                                $OracleError=1;
                                $OracleErrorString = $_;
                                last;
                        }elsif(/CT-LIBRARY error/){ # ase error
                                display($ERROR,"$_");
                                display($FATAL,"Problem with database.");
                                display($FATAL,"Datafile generation \"$output\", failed");
                                $OracleError=1;
                                $OracleErrorString = $_;
                                last;
                        }else{
                                display($DEBUG,"skipping $_");
                                next;
                        }
                 }
                                #keep alive
                if( $Log == $KeepAlive){
                        display($INFO,"Processing ...");
                        $Log=0;
                }else { $Log = $Log +1;}

                s/\s*;\s*/;/g;          # remove spaces before or after ';'
                s/\s*;'\s*/;'/g;        # remove spaces before or after ';'
                s/\s*';\s*/';/g;        # remove spaces before or after ';'
                s/;$//;                 # remove ending ';'
                #new
                s/\\/\\\\/g;            # double backslash
                #end new
                s/,/\\,/g;              # escape ','
                s/;/,/g;                # convert ';' to ','
                s/,NULL,/,,/g;
                s/,NULL,/,,/g;
                s/,NULL$/,/g;
                s/^NULL,/,/g;
                if (/^N\/A,/){
                        display($DEBUG,"skipping $_");
                        next;
                }
                print OUT "$_\n";
                $DataFileIsEmpty=0 if($DataFileIsEmpty);
        }

        close(IN) ;
        close(OUT);
        return $EXIT_NOK if ( $OracleError );   #return on Oracle Error

        if($DataFileIsEmpty){                #Check if temporary datafile have a zero size
                if($CanBeEmpty == 1) {
                        display($WARN,"The temporary datafiles \"$out_tmp\" have a zero size");
                }else{
                        display($FATAL,"The temporary datafiles \"$out_tmp\" have a zero size");
                        display($FATAL,"Datafile generation \"$output\", failed");
                        return $EXIT_NOK;
                }
        }else{
                display($INFO,"Empty Datafile Check Pass");
        }

        if($BackUpName ne ""){
                                        #save the current datafile
                display($INFO,"Start BackUp");
                if( ! rename($output, $BackUpName) ){
                        display($WARN,"Can't rename \" $output \" to \" $BackUpName \", $!");
                        display($WARN,"BackUp, failed");
                        $BackUpDone = 0;
                }else{
                        display($INFO,"Rename \" $output \" to \" $BackUpName \"");
                        display($INFO,"BackUp, done");
                        $BackUpDone = 1;
                }
        }
                                        #Now, we can replace current datafiles by new one
        unless(rename($out_tmp, $output)){
                display($FATAL,"Can't rename \"$out_tmp\" to \"$output\", $!");

                                        #restore Back-Up
                if( $BackUpDone == 1 ){
                        display($WARN,"Restore  \" $output \" with \" $BackUpName \"");
                        if( ! rename($BackUpName, $output) ){
                                display($FATAL,"Can't restore  \" $output \" with \" $BackUpName \", $!");
                                display($FATAL,"Restore, failed");
                        }else{
                                display($INFO,"Restore for \" $output \" with \" $BackUpName \", done");
                        }
                }
                display($ERROR,"Datafile generation \"$output\", failed");
                return $EXIT_NOK;
        }
        GenerateDataFileInfoFile($CurrentUser,$output);
        display($INFO,"Datafile generation \"$output\", done");
        return $EXIT_OK;
}

sub GenerateDataFileInfoFile
{       my $User =  $_[0];
        my $InfoFileName="";

        my $date=GetTime("%Y-%m-%d %H:%M:%S");
        my $DataFileHeader = " $User | $date $_[1]\n";

        $InfoFileName = GenerateInfoFileName($_[1]);
                        #write datafile information file which contains the name of the user and the creation date
        if( sysopen (IN, $InfoFileName, O_RDWR|O_CREAT|O_TRUNC) ){
                if( ! print IN $DataFileHeader){
                        display($WARN,"Can't write datafile information to $InfoFileName : $!");
                }
                close(IN);
        }else{
                display($WARN,"Can't create datafile information file \" $InfoFileName \" : $!");
        }
}

sub GenerateInfoFileName{
        my $DataFileInfoFile = $_[0];
        my $InfoFileName="";
        my $Ret=$EXIT_OK;

        $DataFileInfoFile=~ s/.*\///;
        my $path=substr($_[0], 0, length($_[0]) - length($DataFileInfoFile));
        $DataFileInfoFile=~ s/.dat//;
        $InfoFileName=sprintf("%s.%s",$path,$DataFileInfoFile);

        return $InfoFileName;
}

sub GenerateBackUpName
{
        my $output = $_[0];
        my $BackUpName="";
        my $Count=1;

        display($INFO,"Generate BackUp Name for $output");
                        #get the creation date
        my $FileInfo = stat($output);
        my $Cdate=strftime("%Y%m%d%H%M%S",localtime($FileInfo->mtime));
        my $BaseName=$output;

                        #get the basename
        $BaseName=~ s/.*\///;


        my $InfoFileName = GenerateInfoFileName($output);
                        #get the name of the user who generate the datafile
        if(  ! sysopen (IN, $InfoFileName, O_RDONLY)){

                unless (open(IN,"<$output")){
                        display($WARN,"Can't open $output : $!");
                        display($WARN,"Use current date to generate the BackUp Name for $output");
                        $BackUpName=sprintf("%s%s-%s",$BackUpPath,$BaseName,GetTime("%Y%m%d%H%M%S"));
                        sleep 1;
                        return $BackUpName;
                }
        }

        while(<IN>){
                display($DEBUG," $_");
                if(/$output/){
                        (my $tmp, my $unused) = split /\|/,$_;
                        $user= substr($tmp,1);
                        substr($user,-1)  = "";#remove the last space character
                        display($INFO,"Previous version was generated by \" $user \"");
                        $user=~ s/\ /_/g;
                        $BackUpName = sprintf("%s%s-%s-%s",$BackUpPath,$BaseName,$user,$Cdate);
                        last; #exit from the loop
                }
                $Count = $Count + 1;
                last if($Count > 4);#exit from the loop, but there is an error
        }
        close(IN);

        if( $BackUpName eq ""){
                display($WARN,"Use current date to generate the BackUp Name for $output");
                $BackUpName=sprintf("%s%s-%s",$BackUpPath,$BaseName,GetTime("%Y%m%d%H%M%S"));
                sleep 1;
        }
        display($DEBUG,"BackUp Name for $output : $BackUpName");
        return $BackUpName;

}

sub LockProcessing
{
        my $path=$_[0];
        my $current_user=$_[1];
        my $line="";
        my $Ret=$EXIT_OK;

        display($INFO,"Lock Processing");
        if( ! sysopen (IN, $path, O_RDWR|O_CREAT|O_EXCL) )
        {
                $Ret=$EXIT_NOK;
                display($WARN,"Can't create $path: $!");
                if( ! sysopen(IN, $path, O_RDONLY)){
                        display($FATAL,"Can't open in read only $path : $!");
                }else{
                        my $pid;                #Containing the current pid value
                        my $user;               #Containing the current user value
                        my $date;               #Containing the current date value

                        while ($line = <IN>){
                                chomp($line);
                                if( ! $line eq ""){
                                        $line =~ s/^\s*$//g;
                                        ($pid,$user,$date) = split /,/, $line;
                                        display($WARN,"The process ($pid) launched by \" $user \" uses the lock file \" $path \" since $date");
                                        display($ERROR,"Can't perfom the command requested by user \" $current_user \"");
                                }
                        }
                        close(IN);
                }
        }else{
                $line=sprintf("%s,%s,%s",$$,$current_user,GetTime("%Y/%m/%d %H:%M:%S"));
                if( ! print IN $line, "\n" ){
                        display($WARN,"Can't write lock information : $!");
                        $Ret=$EXIT_NOK;
                }else{
                        display($INFO,"Set lock $path for User \" $current_user \"");
                        display($INFO,"Lock Processing, done");
                }
                close(IN);
        }

        display($FATAL,"Lock Processing, failed") if($Ret == $EXIT_NOK);
        return $Ret;
}

sub UnlockProcessing
{
        display($INFO,"Remove lock file $_[0]");
        if ( ! unlink("$_[0]") ){
                display($WARN,"Problem when try to unlink $_[0] : $!");
                display($INFO,"Remove lock file $_[0], failed");
        }
        display($INFO,"Remove lock file $_[0], done");
}

sub GetTime
{
    my $date = time();

    return strftime($_[0], localtime($date));
}



sub TestOracleCnx
{
        my $sqlplus=$_[0];
        my $authentication=$_[1];
        my $OracleError=0;
        my $First=1;
        my $pid=-1;
        local $SIG{ALRM} = sub { die "TIMEOUT\n";exit; }; # NB: \n

            display($INFO,"Check Oracle right access");                             #check login pb
        eval {
                alarm 1;
                system("echo \$\$> log ;$sqlplus -S $authentication >> log");
                alarm 0;
        };

        if($@){
                display($INFO,"Check attempt log");
                open(IN,"<log");
                while(<IN>){
                        display($DEBUG,"$_");
                        if( $First ){
                                $pid = $_;
                                $pid =~ s/\ //g;
                                display($DEBUG,"----> $pid");
                                $pid =~ s/\n//g;
                                display($DEBUG,"----> $pid");
                                $First=0;
                                next;
                        }

                        if(/ORA-/){
                                display($FATAL,"Check Oracle right access, failed");
                                display($FATAL,"$_");
                                $OracleError=1;
                                last;
                        }
                }
                close(IN);
                unlink("log");
                return $EXIT_NOK if ( $OracleError );   #return on Oracle Error


        }
        display($DEBUG,"kill -9  $pid");
         #system ("kill -9 -$pid");
        my $cnt=kill 9 ,$pid;
       display($INFO,"Check Oracle right access, done, $cnt");
        return $EXIT_OK;
}
