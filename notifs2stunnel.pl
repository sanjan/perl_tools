#!/usr/bin/perl
use strict;
$| = 1;

# URL mapping
my %mapping = (
#Citibank mapping
'.*citigroupsoasit\.citigroup\.com/SMSHTTPServices/AckListener$' => '127.0.0.1\:6200/SMSHTTPServices/AckListener',
'.*consumersoa\.citi\.com/SAPCitiAlerts/decision_service/dino/customerresponse/SybaseAck' => '127.0.0.1\:6209/SAPCitiAlerts/decision_service/dino/customerresponse/SybaseAck',
'.*citigroupsoauat\.citigroup\.com/SMSHTTPServices/AckListener$' => '127.0.0.1\:6201/SMSHTTPServices/AckListener',
 '.*citigroupsoauat\.citigroup\.com/MWDCSMSHTTPServices/AckListener$' => '127.0.0.1\:6201/MWDCSMSHTTPServices/AckListener',
'.*citigroupsoa\.citigroup\.com/SMSHTTPServices/AckListener$' => '127.0.0.1\:6202/SMSHTTPServices/AckListener',
'.*citigroupsoasit\.citigroup\.com/SMS/CitiDirect/delivered_sms_response$' => '127.0.0.1\:6200/SMS/CitiDirect/delivered_sms_response',
'.*citigroupsoasit\.citigroup\.com/DIT/SMSSaaS/sms$'  => '127.0.0.1\:6200/DIT/SMSSaaS/sms',
'.*citigroupsoasit\.citigroup\.com/SMSSaaS/sms$'  => '127.0.0.1\:6200/SMSSaaS/sms',
'.*citigroupsoasit\.citigroup\.com/DIT/SMSSaaS/sms/$'  => '127.0.0.1\:6200/DIT/SMSSaaS/sms',
'.*citigroupsoasit\.citigroup\.com/DIT/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest\.action$' =>  '127.0.0.1\:6200/DIT/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoasit\.citigroup\.com/DEV/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest\.action$' => '127.0.0.1\:6200/DEV/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoasit\.citigroup\.com/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest\.action$' => '127.0.0.1\:6200/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoauat\.citigroup\.com/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest\.action$' => '127.0.0.1\:6201/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoasit\.citigroup\.com/SIT/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest\.action$' => '127.0.0.1\:6200/SIT/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoauat\.citigroup\.com/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest\.action$' => '127.0.0.1\:6201/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoauat\.citigroup\.com\:443/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest\.action$' => '127.0.0.1\:6201/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoasit\.citigroup\.com/SMSSaaS/sms/$'  => '127.0.0.1\:6200/SMSSaaS/sms',
'.*citigroupsoauat\.citigroup\.com/SMS/CitiDirect/delivered_sms_response$' => '127.0.0.1\:6201/SMS/CitiDirect/delivered_sms_response',
'.*citigroupsoa\.citigroup\.com/SMS/CitiDirect/delivered_sms_response$' => '127.0.0.1\:6202/SMS/CitiDirect/delivered_sms_response',
'.*citigroupsoa\.citigroup\.com/MWDCSMSHTTPServices/AckListener$' => '127.0.0.1\:6202/MWDCSMSHTTPServices/AckListener',
#27766
'.*citigroupsoa\.citigroup\.com\:443/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action$' => '127.0.0.1\:6202/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
#27763
'.*citigroupsoasit\.citigroup\.com/BDIT/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action$' => '127.0.0.1\:6200/BDIT/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
#27764
'.*citigroupsoasit\.citigroup\.com/BSIT/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action$' => '127.0.0.1\:6200/BSIT/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
#27765
'.*citigroupsoauat\.citigroup\.com/UAT2/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action$' => '127.0.0.1\:6201/UAT2/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoauat\.citigroup\.com\:443/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action$' => '127.0.0.1\:6201/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
#27503
'.*citigroupsoa\.citigroup\.com/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6202/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',

#Citibank Case: 400020209 and 400020604 - SIT - SAP CRM 200106534 (Changed to 2016 cert)
'.*consumersoasit\.citi\.com\:443/AOPaperless/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action'  => '127.0.0.1\:6209/AOPaperless/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
#SAP CRM 200106534 (Changed to 2016 cert) - New DIT URL
'.*consumersoasit\.citi\.com\:443/DIT/AOPaperless/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action'  => '127.0.0.1\:6209/DIT/AOPaperless/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',

# New URL for Citi SIT 27501 and 27530
'.*consumersoasit\.citi\.com\:443/DEV/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action'  => '127.0.0.1\:6209/DEV/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*consumersoasit\.citi\.com\:443/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action'  => '127.0.0.1\:6209/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',

# New URL for Citi 29071
'.*consumersoauat\.citi\.com\:443/WP/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6215/WP/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',

#AIG mapping
# Account 27125
'.*www\.dpsvcinteg\.aig\.com\:15407/$' => '127.0.0.1\:6206/',
#rest of AIG
'.*www\.dpsvc\.aig\.com\:15407/$' => '127.0.0.1\:6207/',

#TRP mapping
'.*www2qual\.troweprice\.com\:50443/inboundsms-dev/sms/test/mobile-acknowledgements$' => '127.0.0.1\:6203/inboundsms-dev/sms/test/mobile-acknowledgements',
'.*home2qual\.troweprice\.com\:50443/inboundsms-dev/sms/test/mobile-acknowledgements$' => '127.0.0.1\:6204/inboundsms-dev/sms/test/mobile-acknowledgements',
'.*home2qual\.troweprice\.com\:50443/inboundsms-dev/sms/876937/mobile-acknowledgements$' => '127.0.0.1\:6204/inboundsms-dev/sms/876937/mobile-acknowledgements',
'.*home2qual\.troweprice\.com\:50443/inboundsms/sms/test/mobile-acknowledgements$' => '127.0.0.1\:6204/inboundsms/sms/test/mobile-acknowledgements',
'.*home2qual\.troweprice\.com\:50443/inboundsms/sms/876937/mobile-acknowledgements$' => '127.0.0.1\:6204/inboundsms/sms/876937/mobile-acknowledgements',
'.*home2\.troweprice\.com\:50443/inboundsms/sms/876937/mobile-acknowledgements$' => '127.0.0.1\:6205/inboundsms/sms/876937/mobile-acknowledgements',
'.*home2\.troweprice\.com\:50443/inboundsms-prod/sms/876937/mobile-acknowledgements$' => '127.0.0.1\:6205/inboundsms-prod/sms/876937/mobile-acknowledgements',
'.*home2qual\.troweprice\.com\:50443/inboundsms-dev/sms/32351/mobile-acknowledgements$' => '127.0.0.1\:6204/inboundsms-dev/sms/32351/mobile-acknowledgements',
'.*home2qual\.troweprice\.com\:50443/inboundsms/sms/32351/mobile-acknowledgements$' => '127.0.0.1\:6204/inboundsms/sms/32351/mobile-acknowledgements',
'.*home2\.troweprice\.com\:50443/inboundsms/sms/32351/mobile-acknowledgements$' => '127.0.0.1\:6205/inboundsms/sms/32351/mobile-acknowledgements',
'.*home2\.troweprice\.com\:50443/inboundsms-prod/sms/32351/mobile-acknowledgements$' => '127.0.0.1\:6205/inboundsms-prod/sms/32351/mobile-acknowledgements',

# iFactor mapping, account 29156
'.*nve-dev\.ifactornotifi\.com/notifi/inbound/sms/sybase/status$' => '127.0.0.1\:6213/notifi/inbound/sms/sybase/status',

# iFactor mapping for account 28476
'.*nve\.ifactornotifi\.com/notifi/inbound/sms/sybase/status$' => '127.0.0.1\:6216/notifi/inbound/sms/sybase/status',
#'.*nve\.ifactornotifi\.com$' => '127.0.0.1\:6216/',

# SAP CRM 400021691 : Ack URL change for 28194 and 27502
'.*citigroupsoauat\.citigroup\.com/UAT2/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6214/UAT2/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*citigroupsoauat\.citigroup\.com/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6214/MSM/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',

# New URL for Citi 28716
'.*consumersoauat\.citi\.com/GBLSMS/Paperless/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6215/GBLSMS/Paperless/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',


# New URL for Citi 29706 and 20705
'.*consumersoasit\.citi\.com/DIGSMSDIT/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6209/DIGSMSDIT/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*consumersoasit\.citi\.com/DIGSMSSIT/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6209/DIGSMSSIT/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',

# New URL for Citi AU 30221 30225 30231 30267 (SAP CRM 400024356)
'.*consumersoasit\.citi\.com/asia/decision_service/dino/customerResponse/AUBOQResponse' => '127.0.0.1\:6209/asia/decision_service/dino/customerResponse/AUBOQResponse',
'.*consumersoasit\.citi\.com/asia/decision_service/dino/customerResponse/AUCRDResponse' => '127.0.0.1\:6209/asia/decision_service/dino/customerResponse/AUCRDResponse',
'.*consumersoasit\.citi\.com/asia/decision_service/dino/customerResponse/AUGCBResponse' => '127.0.0.1\:6209/asia/decision_service/dino/customerResponse/AUGCBResponse',
'.*consumersoasit\.citi\.com/asia/decision_service/dino/customerResponse/AUSCPResponse' => '127.0.0.1\:6209/asia/decision_service/dino/customerResponse/AUSCPResponse',
'.*consumersoasit\.citi\.com/asia/decision_service/dino/customerResponse/AUVMAResponse' => '127.0.0.1\:6209/asia/decision_service/dino/customerResponse/AUVMAResponse',
'.*consumersoasit\.citi\.com\:443/decision_service/dino/uksybaseresponse/sybaseack' => '127.0.0.1\:6209/decision_service/dino/uksybaseresponse/sybaseack',
'.*consumersoasit\.citi\.com\:443/decision_service/dino/uaesybaseresponse/sybaseack' => '127.0.0.1\:6209/decision_service/dino/uaesybaseresponse/sybaseack',
'.*consumersoa\.citi\.com/SAPCitiAlerts/decision_service/dino/customerresponse/SybaseAck' => '127.0.0.1\:6209/SAPCitiAlerts/decision_service/dino/customerresponse/SybaseAck',
'.*uat2\.citibank\.com\.au/AUGCB/apma/sms/servlet/sms-receiver.do' => '127.0.0.1\:6218/AUGCB/apma/sms/servlet/sms-receiver.do',

# New URL for Citi 27503 and 27766 ticket 200122608
'.*consumersoa\.citi\.com/GBLSMS/Paperless/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6217/GBLSMS/Paperless/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',
'.*consumersoa\.citi\.com/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6217/CEPHealthCare/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action',

# New URL for Appdragon parcelforce
'.*pf\.btmessaging\.com/sybase-acknowledgement' => '127.0.0.1\:6219/sybase-acknowledgement',

# New URL for citi 30008
'.*consumersoa\.citi\.com/DIGSMS/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action' => '127.0.0.1\:6217/DIGSMS/SMSSaaS/ACK/sms/mo/ProcessSMSRequest.action'

);

# -------------------------------------------------------------------------

my $in_spool = $ARGV[0];
my $out_spool = $ARGV[1];
my $in_file;
my $out_file;
my $tmp_file;
my $already;
my $files;
my $base_file;
my $src;
my $dst;
my $customerid;

opendir(SPOOL, $in_spool) or die("can't open directory $in_spool: $!");
#run forever
while(42)
{
    $files = 0;
    rewinddir(SPOOL);
    while (defined($in_file=readdir(SPOOL)))
    {
        $out_file = "$out_spool/$in_file";
        $tmp_file = "$out_file.tmp";
        $base_file ="$in_file";
        $in_file = "$in_spool/$in_file";
        if (not -f $in_file )
        {
            next;
        }
        if (not open(IN_FILE, "<$in_file"))
        {
            warn("Couldn't open $in_file: $!");
            next;
        }
        if (not open(OUT_FILE, ">$tmp_file"))
        {
            warn("Couldn't open $out_file: $!");
            close(IN_FILE);
            sleep(1);
            next;
        }
        print "Patching $in_file\n";
        $already = 0; #Only 1 line need to be edited
        while(<IN_FILE>)
        {
            if (not $already)
            {
                foreach $src (keys(%mapping))
                {
                    $dst = $mapping{$src};
                    if (s:^MailReply=$src$:MailReply=$dst:i)
                    {
                        $already = 1;
                        last;
                    }
                }
            }
            print OUT_FILE $_;
        }
        close(IN_FILE);
        close(OUT_FILE);
        if (not unlink($in_file))
        {
            warn("Couldn't delete $in_file: $!");
            unlink($tmp_file) or warn ("Couldn't delete $tmp_file: $!");
            next;
        }
        if (not rename($tmp_file, $out_file))
        {
            warn("Couldn't move $tmp_file to $out_file: $!");
            sleep(1);
        }
        else
        {
            $files++;
            print "$in_file -> $out_file\n";
        }
    }
    if (not $files)
    {
        sleep(1);
    }
}
