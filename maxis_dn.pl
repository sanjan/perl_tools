#!/usr/bin/perl

use strict;
use Net::SFTP;

my $ftp_address = '';
my $ftp_user = '';
my $ftp_password = '';
my $ftp_port = '';
my $ftp_path = '';

my $temp_spool = '';
my $archive_spool = '';
my $notif_spool = '';

my $timezone = 1;
my $timeadj = 1080;

my %mapping;

if ($ARGV[0] and -e $ARGV[0]) {
    print "Loading Configuration...\n";
    open(INI, "<$ARGV[0]");
    while (<INI>) {
        $_ =~ s/\r|\n//isg;
        if ($_ =~ /^ftp_address=(.+)/i) {
            $ftp_address = $1;
        }
        elsif ($_ =~ /^ftp_user=(.+)/i) {
            $ftp_user = $1;
        }
        elsif ($_ =~ /^ftp_password=(.+)/i) {
            $ftp_password = $1;
        }
        elsif ($_ =~ /^ftp_port=(.+)/i) {
            $ftp_port = $1;
        }
        elsif ($_ =~ /^ftp_path=(.+)/i) {
            $ftp_path = $1;
        }
        elsif ($_ =~ /^temp_spool=(.+)/i) {
            $temp_spool = $1;
        }
        elsif ($_ =~ /^archive_spool=(.+)/i) {
            $archive_spool = $1;
        }
        elsif ($_ =~ /notif_spool=(.+)/i) {
            $notif_spool = $1;
        }
        elsif ($_ =~ /timezone=(.+)/i) {
            $timezone = $1;
        }
        elsif ($_ =~ /timeadj=(.+)/i) {
            $timeadj = $1;
        }

        elsif ($_ =~ /^status=(.+)/i) {
            my $tmp1 = $1;
            my @tmp2 = split(/,/isg, $tmp1);
            $mapping{$tmp2[0]} = $tmp2[1];
        }
    }
    close(INI);
    $mapping{'1'} = '';
}
else {
    die "Error: Configuration file not found: $ARGV[0]";
}


my @localfiles2;

print "Firstly we try to clean up previously downloaded DN files\n";

opendir DIR, $temp_spool;
my @files2 = grep !/^\.\.?$/, readdir DIR;
close DIR;

my $found = 0;
foreach (reverse sort @files2) {
    if ($_ =~ /DN_(\d+)_(\d\d\d\d)-(\d\d)-(\d\d) (\d\d)-(\d\d)-(\d\d)\.txt/i) {
        if (!-e $archive_spool . '/' . $_) {
            print "Found previously downloaded DN file: " . $_ . "\n";
            push @localfiles2, $_;
            $found = 1;
        }
    }
}

if ($found) {
    foreach my $lf (reverse sort @localfiles2) {
        print "processing $temp_spool/$lf\n";
        open(FILE, "<$temp_spool/$lf");
        while (<FILE>) {
            my $line = $_;
            $line =~ s/\r|\n//isg;
            next if ($line =~ /^\s*$/);

            # Time Stamp  |DNMsgId |MTMsgId|Service Id |MessageStatus |ShortCode
            # 4/1/2005 9:30:32 AM|56970174|180328935900001|810|2|36999
            # 4/1/2005 9:34:25 AM|56971428|180362540600001|810|2|36999
            my @fields = split(/\|/, $line);
            my $year = 0;
            my $month = 0;
            my $day = 0;
            my $hour = 0;
            my $minute = 0;
            my $second = 0;
            my $ampm = 'AM';

            my $smscdate = '';
            my $receptiondate = &getdate(time()+$timezone*3600);
            if ($fields[0] =~ /(\d+)\/(\d+)\/(\d+)\s+(\d+):(\d+):(\d+)\s+(AM|PM)/i) {
                $year = $3;
                $month = $1;
                $day = $2;
                $hour = $4;
                $minute = $5;
                $second = $6;
                $ampm = uc($7);

                $hour += 12 if ($ampm eq 'PM' && $hour ne '12');
                $month = "0" . $month if (length($month) < 2);
                $day = "0" . $day if (length($day) < 2);
                $hour = "0" . $hour if (length($hour) < 2);
                $minute = "0" . $minute if (length($minute) < 2);
                $second = "0" . $second if (length($second) < 2);
                $hour = '00' if ($ampm eq 'AM' && $hour eq '12');

                $smscdate = &getdate(time_to_unix("$year-$month-$day $hour:$minute:$second")+(2*$timezone-8)*3600+$timeadj);
            }
            else {
                print "Can not match timestamp format: $fields[0]\n";
                next;
            }

            my $notifbody =
                "[MOBILE_ACK]\n" .
                "UsedProvider=MY_Maxis_Rs_TRx\n" .
                "Protocol=SMPP\n" .
                "ProofOfReceip=1\n" .
                "FROM=\n" .
                "StatusCode=" . $mapping{$fields[4]} . "\n" .
                "StatusInfo=\n" .
#                "Originator=1234567890\n" .
                "Originator=\n" .
                "Recipient=\n" .
                "Message=\n" .
                "UsedDevice=network\n" .
                "MessageID=" . $fields[2] . "\n" .
                "StatusReportRequest=0\n" .
                "SmscDate=$smscdate\n" .
                "ReceptionDate=$receptiondate\n";

            my $notifname =
                "maxis_" . $fields[1] . '_' . $fields[2] . '_' . $fields[5] . '.ini';

            open(NOTIF, ">$temp_spool/$notifname");
            print NOTIF $notifbody;
            close(NOTIF);

            rename("$temp_spool/$notifname", "$notif_spool/$notifname");

            print "$line ==>\n";
            print "$notif_spool/$notifname:\n";
            print $notifbody . "\n\n";
        }
        close(FILE);

        rename("$temp_spool/$lf", "$archive_spool/$lf");
        print "Moving to $archive_spool/$lf\n\n";
    }
}

print "Then we try to get new DN files from Maxis FTP\n";

my %args = (
    user => $ftp_user,
    password => $ftp_password,
    ssh_args => [port => $ftp_port]
);

my $sftp = Net::SFTP->new($ftp_address, %args) or die "Cannot connect to $@";

print "Connected\n";

my @files = $sftp->ls($ftp_path);
my @localfiles;

foreach (reverse sort @files) {
    if ($_->{'filename'} =~ /DN_(\d+)_(\d\d\d\d)-(\d\d)-(\d\d) (\d\d)-(\d\d)-(\d\d)\.txt/i) {
        if (!-e $archive_spool . '/' . $_->{'filename'} and !-e $temp_spool . '/' . $_->{'filename'}) {
            print "Found new DN file: " . $_->{'filename'} . ", downloading...\n";
            $sftp->get($ftp_path.'/'.$_->{'filename'}, $temp_spool . '/' . $_->{'filename'});
            if (-s $temp_spool . '/' . $_->{'filename'}) {
                print "deleting DN file from server...\n";
                $sftp->do_remove($ftp_path.'/'.$_->{'filename'});
                push @localfiles, $_->{'filename'};
            }
        }
    }
}

foreach my $lf (reverse sort @localfiles) {
    print "processing $temp_spool/$lf\n";
    open(FILE, "<$temp_spool/$lf");
    while (<FILE>) {
        my $line = $_;
        $line =~ s/\r|\n//isg;
        next if ($line =~ /^\s*$/);

        # Time Stamp  |DNMsgId |MTMsgId|Service Id |MessageStatus |ShortCode
        # 4/1/2005 9:30:32 AM|56970174|180328935900001|810|2|36999
        # 4/1/2005 9:34:25 AM|56971428|180362540600001|810|2|36999
        my @fields = split(/\|/, $line);
        my $year = 0;
        my $month = 0;
        my $day = 0;
        my $hour = 0;
        my $minute = 0;
        my $second = 0;
        my $ampm = 'AM';

        my $smscdate = '';
        my $receptiondate = &getdate(time()+$timezone*3600);
        if ($fields[0] =~ /(\d+)\/(\d+)\/(\d+)\s+(\d+):(\d+):(\d+)\s+(AM|PM)/i) {
            $year = $3;
            $month = $1;
            $day = $2;
            $hour = $4;
            $minute = $5;
            $second = $6;
            $ampm = uc($7);

            $hour += 12 if ($ampm eq 'PM' && $hour ne '12');
            $month = "0" . $month if (length($month) < 2);
            $day = "0" . $day if (length($day) < 2);
            $hour = "0" . $hour if (length($hour) < 2);
            $minute = "0" . $minute if (length($minute) < 2);
            $second = "0" . $second if (length($second) < 2);
            $hour = '00' if ($ampm eq 'AM' && $hour eq '12');

            $smscdate = &getdate(time_to_unix("$year-$month-$day $hour:$minute:$second")+(2*$timezone-8)*3600+$timeadj);
        }
        else {
            print "Can not match timestamp format: $fields[0]\n";
            next;
        }

        my $notifbody =
            "[MOBILE_ACK]\n" .
            "UsedProvider=MY_Maxis_Rs_TRx\n" .
            "Protocol=SMPP\n" .
            "ProofOfReceip=1\n" .
            "FROM=\n" .
            "StatusCode=" . $mapping{$fields[4]} . "\n" .
            "StatusInfo=\n" .
#            "Originator=1234567890\n" .
            "Originator=\n" .
            "Recipient=\n" .
            "Message=\n" .
            "UsedDevice=network\n" .
            "MessageID=" . $fields[2] . "\n" .
            "StatusReportRequest=0\n" .
            "SmscDate=$smscdate\n" .
            "ReceptionDate=$receptiondate\n";

        my $notifname =
            "maxis_" . $fields[1] . '_' . $fields[2] . '_' . $fields[5] . '.ini';

        open(NOTIF, ">$temp_spool/$notifname");
        print NOTIF $notifbody;
        close(NOTIF);

        rename("$temp_spool/$notifname", "$notif_spool/$notifname");

        print "$line ==>\n";
        print "$notif_spool/$notifname:\n";
        print $notifbody . "\n\n";
    }
    close(FILE);

    rename("$temp_spool/$lf", "$archive_spool/$lf");
    print "Moving to $archive_spool/$lf\n\n";
}

sub time_to_unix
{
    my $time_str = shift;
    my %months = ("01" => 0, "02" => 1, "03" => 2, "04" => 3, "05" => 4, "06" => 5,
                  "07" => 6, "08" => 7, "09" => 8, "10" => 9, "11" => 10,"12" => 11);
    my $time;
    my ($s1, $s2) = split(/ /, $time_str);
    my ($year, $mon, $day) = split(/-/, $s1);
    my ($hour, $min, $sec) = split(/:/, $s2);

    unless ($day and $mon and $year)  { return undef; }
    unless (defined($months{$mon}))   { return undef; }

    use Time::Local;
    eval {
        $day = int($day); $year = int($year) - 1900;
        $hour=int($hour); $min = int($min); $sec = int($sec);
        $time = timelocal($sec,$min,$hour,$day,$months{$mon}, $year);
    };
    return undef if ($@);
    return $time;
}

sub getdate
{
    my $time = shift();
    my ($sec,$min,$hour,$dd,$mon,$yy,$wday,$yday,$isdst)= gmtime($time);

    my $yyyy = $yy+1900;
    my $mm   = $mon+1;

    ($mm   < 10) and ($mm = "0$mm");
    ($dd   < 10) and ($dd = "0$dd");
    ($hour < 10) and ($hour = "0$hour");
    ($min  < 10) and ($min = "0$min");
    ($sec  < 10) and ($sec = "0$sec");

    return "$yyyy$mm$dd$hour$min$sec";
}


