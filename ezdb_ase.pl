#!/usr/bin/perl

use strict;
use CGI qw/:standard :html3/;
use CGI qw(:standard escapeHTML);

#### CRP migration status
#
# if crp_status == 0   before CRP
# else   after CRP
#
my $crp_status = 1;

#### ASE access configuration
my $db_cmd = "/opt/HUB/sybase/ASE-SDK-15.7/OCS-15_0/bin/isql";
my $db_base = "PDSA2PFR5";
my $db_user = "a2p_msgdb_script_user";
my $db_pass = "mk58hgjk";


my $delta_routing_file="/tmp/ezdb_deltarouting_$$.csv";
my $dup_smsc_tmp="/tmp/ezdb_dup_smsc_$$.csv";
my $tmp_extract="/tmp/ezdb_extract_$$.csv";
my $tmp_request="/tmp/ezdb_request_$$.csv";
my $tmp_get_result="/tmp/ezdb_get_result_$$.csv";
my $logfile="/usr/mobileway/log/ezdb.log";
my $runlevel=1;
my $version="1.6.1";
my $extract_counter=1;

my $LEVEL_EVERYBODY=1;
my $LEVEL_CCS=1.5;
my $LEVEL_SUPPORT=2;
my $LEVEL_OPERATOR=2.5;
my $LEVEL_PROD=3;

my @menus;
my %requests;

my $username;
my $comming_from;

my $interface;
my $display_sql;

my $primary_group;

my %runlevels=
    (
     "appdev"   =>      $LEVEL_PROD,
     #"appdev"  =>      $LEVEL_OPERATOR,
     #"appdev"  =>      $LEVEL_SUPPORT,
     #"appdev"  =>      $LEVEL_CCS,
     #"appdev"  =>      $LEVEL_EVERYBODY,
     "support"  =>      $LEVEL_SUPPORT,
     "custcare" =>      $LEVEL_SUPPORT,
     "noc"      =>      $LEVEL_SUPPORT,
     "operator" =>      $LEVEL_OPERATOR,
     "operator2"        =>      $LEVEL_OPERATOR,
     "prod"     =>      $LEVEL_PROD,
     "prodops"  =>      $LEVEL_PROD,
     "dba"      =>      $LEVEL_PROD,
     "stream"   =>      $LEVEL_SUPPORT,
     "syseng"   =>      $LEVEL_PROD,
     "ccssupport" =>    $LEVEL_CCS
     );

# *****************************************************************************
# *****************************************************************************
# *****************************************************************************
# *****************************************************************************

# ------------------------------------------------------------------------------
#                               SQL requests
# ------------------------------------------------------------------------------

#12)     Display customers impacted by forbidden routing

#13)     Customerroaming with priorities impacted by a forbidden routing

#14)     Display all SMSC informations


#17)     Customerroaming activated on smsc that are not working
#18)     Verify the customerroaming compared with roaming preferences
#19)     Enter customerid to verify
#20)     Liste accounts closed
#21)     RS flag missing
#22)     Roaming by operator
#23)     Roaming per country
#24)     Verify message with Lsenquence



%requests=
    (
     VIEW_DELTA_ROUTING_ROAMING_CR      =>
"-- Customer routings not in routing preferences
select
  c.customerid, ';',
  c.name, ';', ':', ';',
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  s.smscid, ';',
  s.smscname, ';'
from
  customerrouting r,
  customers c,
  operator o,
  smsc s
where
  r.operatorid=o.operatorid
  and o.liveoperator=1
  and r.smscid=s.smscid
  and r.customerid=c.customerid
  and r.operatorid not in (select distinct operatorid from routingpreferences)
  and s.smscid<>999999
  and c.companyid<>1
  and c.liveaccount=1
order by o.operatorname, s.smscname, c.name
go
",

     VIEW_DELTA_ROUTING_OFF_CR  =>
"-- Customer routings on smsc set to OFF
select
  c.customerid, ';',
  c.name, ';', ':', ';',
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  s.smscid, ';',
  s.smscname, ';'
from
  customerrouting r,
  customers c,
  operator o,
  smsc s
where
  r.operatorid=o.operatorid
  and o.liveoperator=1
  and r.smscid=s.smscid
  and r.customerid=c.customerid
  and s.onoff=0
  and r.rc=0
  and r.onoff=1
  and s.smscid<>999999
  and c.companyid<>1
  and c.liveaccount=1
order by c.name, o.operatorname, s.smscname
go
",

     VIEW_DELTA_ROUTING_FORBIDDEN_CR    =>
"--  Customer routings on forbidden routes (preference=0)
select
  c.customerid, ';',
  c.name, ';', ':', ';',
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  s.smscid, ';',
  s.smscname, ';'
from
  customerrouting r,
  customers c,
  operator o,
  smsc s
where
  r.operatorid=o.operatorid
  and o.liveoperator=1
  and r.smscid=s.smscid
  and r.customerid=c.customerid
  and  r.smscid in (select smscid from routingpreferences where operatorid=r.operatorid and preference=0)
  and s.smscid<>999999
  and c.companyid<>1
  and c.liveaccount=1
order by o.operatorname, s.smscname, c.name
go
",

     VIEW_OFF_RC_CR             =>
"-- Customer routing set to OFF while permanent flag set to 1
select
  c.customerid, ';',
  c.name, ';', ':', ';',
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  s.smscid, ';',
  s.smscname, ';'
from
  customerrouting r,
  customers c,
  operator o,
  smsc s
where
  r.operatorid=o.operatorid
  and o.liveoperator=1
  and r.smscid=s.smscid
  and s.livesmsc=1
  and r.customerid=c.customerid
  and r.rc=1
  and r.onoff=0
  and c.companyid<>1
  and c.liveaccount=1
order by c.name, o.operatorname, s.smscname
go
",

     VIEW_FORBIDDEN_ROUTING     =>
"-- All forbidden routes (preference=0) in routing preferences table
select
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  s.smscid, ';',
  s.smscname, ';',  ':', ';',
  r.comments, ';',
  r.preference, ';'
from
  routingpreferences r,
  operator o,
  smsc s
where
  r.operatorid=o.operatorid
  and r.smscid=s.smscid
  and r.preference=0
order by o.operatorname, s.smscname
go
",

     VIEW_OFF_CONNECTIONS       =>
"-- Connections set to OFF
select
  smscid, ';', smscname, ';'
from
  smsc
where
  livesmsc=1 and
  onoff=0
go
",

     RECALC_ROUTING             =>
"-- Update default routing
UPDATE smscnber SET smscid=\$expected_smscid WHERE
  operatorid=\$operatorid AND
  smscid=\$smscid
COMMIT
go
",


     VIEW_ROUTING_PREFERENCES   =>
"-- Routing preferences
select
  s.smscid, ';', ':', ';',
  s.smscname, ';', ':', ';',
  r.preference, ';'
from
  routingpreferences r,
  operator o,
  smsc s
where
  r.operatorid=\$operatorid
  and r.operatorid=o.operatorid
  and s.smscid=r.smscid
order by r.preference, s.smscname
go
",

     VIEW_NUMBERING_PLAN        =>
"-- Numbering plan
select
  p.phonenber, ';', ':', ';',
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  s.smscid, ';',
  s.smscname, ';'
from
  smscnber p,
  smsc s,
  operator o
where
  p.smscid=s.smscid AND
  p.operatorid=o.operatorid AND
  p.operatorid=\$operatorid AND
  p.smscid<>999999
order by p.smscid, p.phonenber
go
",

     VIEW_SMSC_USAGE_DR         =>
"-- Default routing on this smsc
select distinct
  o.operatorid, ';',
  o.operatorname, ';'
from
  smscnber s,
  operator o
where
  s.smscid=\$smscid AND
  s.operatorid=o.operatorid
order by o.operatorname
go
",

     VIEW_SMSC_USAGE_MO         =>
"-- MO routing on this smsc
select
  m.returnedtpda, ';',
  m.servicenumber, ';', ':', ';',
  m.parserflag, ';', ':', ';',
  c.customerid, ';',
  c.name, ';'
from momapping m, customers c where
  m.smscid=\$smscid
  and m.customerid=c.customerid
order by c.name
go
",

     VIEW_SMSC_USAGE_CR         =>
"-- Customer routing on this smsc
select
  c.customerid, ';',
  c.name, ';', ':', ';',
  o.operatorid,   ';',
  o.operatorname, ';',':',';',
  r.rc,';'
from
  customers c
Left Outer Join
customerrouting r
On
c.customerid = r.customerid
Left Outer Join
operator o
On
r.operatorid = o.operatorid
where
  r.smscid=\$smscid and
  r.onoff=1 and
  c.liveaccount=1
order by c.name, o.operatorname
go
",

     VIEW_OPERATOR_ROUTING_DR   =>
"-- Default routing for this operator
select distinct
  s.smscid, ';',
  s.smscname, ';'
from
  smsc s,
  smscnber n
where
  n.operatorid=\$operatorid and
  s.smscid=n.smscid and
  s.smscid<>999999 and
  char_length(n.phonenber)<=8
order by s.smscname
go
",

     VIEW_OPERATOR_ROUTING_CR   =>
"-- Customer routing for this operator
select
  c.customerid, ';',
  c.name, ';', ':', ';',
  s.smscid, ';',
  s.smscname, ';', ':', ';',
  r.onoff, ';'
from
  customerrouting r,
  customers c,
  smsc s
where
  r.operatorid=\$operatorid and
  c.customerid=r.customerid and
  c.liveaccount=1 and
  s.smscid=r.smscid
order by c.name
go
",

     VIEW_CUSTOMER_ROUTING      =>
"-- Customer routing for this operator
select
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  s.smscid, ';',
  s.smscname, ';'
from
  operator o,
  smsc s,
  customerrouting c
where
  c.customerid=\$customerid AND
  o.operatorid=c.operatorid AND
  s.smscid=c.smscid
order by s.smscname
go
",

     VIEW_DELTA_ROUTING         =>
"-- Show differences between default routing and routing preferences
SELECT DISTINCT
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  s2.smscid as real, ';',
  s2.smscname as real_name, ';', ':', ';',
  smsc.smscid as expected, ';',
  smsc.smscname as expected_name, ';'
FROM
  routingpreferences r1,
  smsc,
  smsc s2,
  operator o,
  smscnber s
WHERE
  NOT EXISTS (SELECT * FROM smscnber WHERE operatorid=r1.operatorid AND smscid!=s.smscid and smscid<>999999) AND
  r1.preference=
  (
        select min(r2.preference) FROM routingpreferences r2, smsc s3 WHERE
        r2.operatorid=r1.operatorid AND
        r2.preference>0 AND
        r2.onoff=1 AND
        r2.smscid=s3.smscid AND
        s3.onoff=1
  ) AND
  r1.smscid=smsc.smscid AND
  r1.operatorid=s.operatorid AND
  r1.smscid!=s.smscid AND
  r1.smscid!=999999 AND
  s2.smscid=s.smscid AND
  o.operatorid=r1.operatorid
ORDER BY o.operatorid
go
",

    TRASH_NUMBER =>
"-- Trash this phone number (to be renamed with new ctool)
declare \@result int
declare \@phone varchar(100)
declare \@operator varchar(200)
declare \@comment varchar(200)
begin
set \@phone = \"\$phonenber\"
set \@operator = \"\$operatorname\"
set \@comment = \"Operator\"
execute p_ctool_numplan_setupfilterednumber \@phone, \@operator, \@comment, \@result out
end
go
/
",



    UNTRASH_NUMBER              =>
"-- Untrash this phone number (to be renamed with new ctool)
declare \@result int
declare \@phone varchar(100)
begin
set \@phone = \"\$phonenber\"
execute p_ctool_numplan_deletefilterednumber \@phone, \@result out
end
go
",

    FIND_OPERATOR               =>
"-- Search an operatorid by name
select
  o.operatorid, ';',
  o.operatorname, ';', ':', ';',
  o.liveoperator, ';',
  o.entrykind, ';',
  c.countryname, ';'
from
  operator o,
  countries c
where
  upper(o.operatorname) like upper('\%\$name\%') and
  o.countryid=c.countryid
go
",

    FIND_SMSC                   =>
"-- Search a smscid by name
select
  smscid, ';',
  smscname, ';', ':', ';',
  livesmsc, ';',
  onoff, ';',
  servicetype, ';',
  entrykind, ';'
from
  smsc
where
  upper(smscname) like upper('\%\$name\%')
order by smscname
go
",

    FIND_CUSTOMER                       =>
"-- Search a customerid by name
select
  c.customerid, ';',
  c.name, ';', ':', ';',
  o.companyid, ';',
  o.companyname, ';', ':', ';',
  c.servicetype, ';'
from
  customers c, companies o
where
  upper(name) like upper('\%\$name\%') and
  c.companyid=o.companyid
order by o.companyname, c.servicetype, c.name
go
",

    FIND_OPERATOR_ID            =>
"-- Name of this operatorid
select
  operatorid, ';',
  operatorname, ';',
  liveoperator, ';'
from
  operator
where
  operatorid in (\$operatorid)
go
",


    FIND_SMSC_ID                =>
"-- Name of this smscid
select
  smscid, ';',
  smscname, ';'
from
  smsc
where
  smscid in (\$smscid)
order by smscid
go
",

    VIEW_MO_MESSAGE                     =>
"-- Show MO message
select
  c.name, ';',
  m.msisdn, ';',
  m.statusid, ';',
  m.lsequenceno, ';',
  o.operatorname, ';',
  s.smscname, ';',
  m.tpda, ';',
  m.returnedtpda,  ';',
  m.insertdate, ';',
  m.updatedate, ';'
from
  momessages m,
  operator o,
  smsc s,
  customers c
where
  m.messageid=\$messageid and
  m.operatorid=o.operatorid and
  m.smscid=s.smscid and
  m.customerid=c.customerid
go
",


    VIEW_MT_MESSAGE                     =>
"-- Name of this smscid
select
  c.name, ';',
  m.messageid, ';',
  m.msisdn, ';',
  m.statusid, ';',
  m.lsequenceno, ';',
  o.operatorname, ';',
  s.smscname, ';',
  m.clusteripaddress, ';',
  m.insertdate, ';',
  m.smscdeliverytime,';'
from
  messages m,
  operator o,
  smsc s,
  customers c
where
  m.orderid=\$orderid and
  m.operatorid=o.operatorid and
  m.smscid=s.smscid and
  m.customerid=c.customerid
order by m.messageid
go
",

    VIEW_CUSTOMER_INFO                  =>
"-- Customer information
select
  c.name, ';',
  c.liveaccount, ';',
  c.closuredate, ';',
  c.servicelevel, ';',
  c.rsflag, ';',
  a.name, ';'
from
  customers c,
  accountmanagers a
where
  c.customerid=\$customerid and
  a.contactid=c.accountmanagerid
go
",

#    UNTRASH_NUMBER              =>
#"-- Untrash this phone number (to be renamed with new ctool)
#declare \@result int
#declare \@phone varchar(100)
#begin
#set \@phone = \"\$phonenber\"
#execute p_ctool_numplan_deletefilterednumber \@phone, \@result out
#end
#go

    PKG_MANAGE_CONNECTION_SWITCH_ON             =>
"-- Oracle package to switch on a connection
declare \@result int
declare \@smsc varchar(100)
begin
set \@smsc = \"\$smscname\"
execute p_ctool_connection_manageconnectionswitchon \@smsc, \@result out
end
go
",
#set serveroutput on;
#dbms_output.put_line(:tstatus);

    PKG_MANAGE_CONNECTION_SWITCH_OFF            =>
"-- Oracle package to switch off a connection
declare \@result int
declare \@smsc varchar(100)
begin
set \@smsc = \"\$smscname\"
execute p_ctool_connection_manageconnectionswitchoff \@smsc, \@result out
end
go
",
#set serveroutput on;
#:tstatus:=setupconnection.manageconnectionswitchoff(\'\$smscname\');
#dbms_output.put_line(:tstatus);

    PKG_CHANGE_INTO_PRIORITY                    =>
"-- Oracle package to prioritycize a smsc
declare \@result int
declare \@smsc varchar(100)
begin
set \@smsc = \"\$smscname\"
execute p_ctool_connection_changeintopriority \@smsc, \@result out
end
go
",
#set serveroutput on;
#var tstatus number;
#:tstatus:=setupconnection.changeintopriority(0, \'\$smscname\');
#dbms_output.put_line(:tstatus);

#    PKG_DUPLICATE_SMSC                         =>
#"-- Oracle package to duplicate a connection
#set serveroutput on;
#var tstatus number;
#begin
#:tstatus:=setupconnection.duplicatesmsc(0, \'\$sourcesmscname\', \'\$targetsmscname\', \'\$servicetype\');
#dbms_output.put_line(:tstatus);
#end;
#/
#exit
#",
    SEARCH_MO_KEYWORD                           =>
"-- MO keyword information
select
  distinct b.customerid, ';',
  substring(a.smscname,1,30) Smscname,  ';',
  (case when b.comparisoncriteria = 1 then 'EXACT' else 'BeginBy' end) Compare, ';',
  substring(b.servicenumber,1,10) ShortCode, ';',
  substring(b.rsf, 1,20) rsf, ';'
from
  parsermapping b,
  smsc a
where
  b.servicenumber=\'\$servicenumber\' and
  upper(\'\$keyword\') like ('%'+substring(b.rsf,1,1)+'%')
  and a.smscid=b.smscid
order by rsf
go
",

# decode(b.comparisoncriteria, 1, 'EXACT',2,'BeginBy') Compare, ';',
# substring(b.rsf,1,1) =  upper(\'\$keyword\')
# substr(b.RSF,1,1)  upper(\'\$keyword\')


    FIND_MO     =>
"-- Find MO
SELECT ';',
messageid, ';',
msisdn, ';',
tpda, ';',
insertdate,';',
smscid, ';',
customerid, ';',
statusid , ';',
msgtext, ';'
FROM momessages
WHERE day = '\$day' and (msisdn='\$msisdn' or messageid=\$msisdn)
ORDER BY insertdate
go
",

    FIND_MT    =>
"-- Find MT
SELECT ';',
m.orderid,';',
m.messageid,';',
m.msisdn,';',
m.tpoa,';',
a.mailsubmitdate \"SYB 365 ACK TIME\",';',
m.smscdeliverytime \"SMSC ACK TIME\",';',
(case when m.proofofreceipt = 0 then 'Not Requested' else 'Requested' end) \"MOBILE ACK\",';',
m.medeliverytime \"MOBILE ACK TIME\",';',
o.operatorname,';',
s.smscname,';',
m.customerid,';',
c.name \"HUB ACCOUNT\",';',
m.statusid,';',
t.description \"STATUS OF MT MESSAGE\",';',
m.msgtext, ';'
FROM messages m, smsc s, customers c, mailorder a, operator o, status t
WHERE m.day = '\$day'
AND (m.orderid = \$input OR m.msisdn='\$input')
AND m.orderid = a.orderid
AND m.smscid = s.smscid
AND m.customerid = c.customerid
AND m.operatorid = o.operatorid
AND m.statusid = t.statusid
ORDER BY a.mailsubmitdate ASC
go
"
#decode(m.proofofreceipt,0,'Not Requested',1,'Requested') "MOBILE ACK",
,

    BEFORE_CRP_MT_CUSTOMIZED_ROUTING_CREATION    =>
"
declare cur_customer cursor
for select customerid from customers
    where liveaccount = 1 and rsflag = 0
    and customerid in (\$destcustomers)
for read only
go
declare cur_insert cursor
for select b.operatorname, d.smscname, c.tpda, a.rc, a.onoff from customerrouting a
    left outer join customertpoa c on a.customerid = c.customerid and a.smscid = c.smscid
    inner join operator b on a.operatorid = b.operatorid and b.countryid in (\$countryids) and b.liveoperator=1
    inner join smsc d on a.smscid = d.smscid
    where a.customerid = \$sourcecustomer
    and a.subsmscid = 0
for read only
go
declare \@custid int,
        \@operatorname varchar(100),
        \@smscname varchar(100),
        \@tpda varchar(40),
        \@rc tinyint,
        \@onoff tinyint,
        \@retstatus int
open cur_customer
fetch cur_customer into \@custid
while (\@\@SQLSTATUS <> 2)
begin
    open cur_insert
    fetch cur_insert into \@operatorname, \@smscname, \@tpda, \@rc, \@onoff
    while (\@\@SQLSTATUS <> 2)
    begin
        exec \@retstatus = p_ctool_routing_setupmtrouting \@custid, \@operatorname, \@smscname, \@tpda, \@rc, \@onoff, \@retstatus output
        print '%1!, %2!, %3!, %4!, %5!', \@custid, \@operatorname, \@smscname, \@tpda, \@retstatus
        fetch cur_insert into \@operatorname, \@smscname, \@tpda, \@rc, \@onoff
    end
    close cur_insert
    fetch cur_customer into \@custid
end
deallocate cur_insert
close cur_customer
deallocate cur_customer
go
",

    AFTER_CRP_MT_CUSTOMIZED_ROUTING_CREATION    =>
"
declare cur_customer cursor
for select customerid from customers
    where liveaccount = 1 and rsflag = 0
    and customerid in (\$destcustomers)
for read only
go
declare cur_insert cursor
for select b.operatorname, d.smscname, c.tpda, a.rc, a.onoff, a.preference from customerrouting a
    left outer join customertpoa c on a.customerid = c.customerid and a.smscid = c.smscid
    inner join operator b on a.operatorid = b.operatorid and b.countryid in (\$countryids) and b.liveoperator=1
    inner join smsc d on a.smscid = d.smscid
    where a.customerid = \$sourcecustomer
    and a.subsmscid = 0
for read only
go
declare \@custid int,
        \@operatorname varchar(100),
        \@smscname varchar(100),
        \@tpda varchar(40),
        \@rc tinyint,
        \@onoff tinyint,
        \@pref tinyint,
        \@retstatus int
open cur_customer
fetch cur_customer into \@custid
while (\@\@SQLSTATUS <> 2)
begin
    open cur_insert
    fetch cur_insert into \@operatorname, \@smscname, \@tpda, \@rc, \@onoff, \@pref
    while (\@\@SQLSTATUS <> 2)
    begin
        exec \@retstatus = p_ctool_routing_setupmtrouting \@custid, \@operatorname, \@smscname, \@tpda, \@rc, \@onoff, \@pref, \@retstatus output
        print '%1!, %2!, %3!, %4!, %5!', \@custid, \@operatorname, \@smscname, \@tpda, \@pref, \@retstatus
        fetch cur_insert into \@operatorname, \@smscname, \@tpda, \@rc, \@onoff, \@pref
    end
    close cur_insert
    fetch cur_customer into \@custid
end
deallocate cur_insert
close cur_customer
deallocate cur_customer
go
"
     );


# ------------------------------------------------------------------------------
#                                   Menus
# ------------------------------------------------------------------------------


#  Syntax:
#  [
#    function_name (string) or sql request (pointer on function),
#    variable names to get from user,
#    Text displayed in the menu,
#    Question displayed when this menu is selected,
#    run level
#  ]
#

@menus =
(
# [
#  "FIND_OPERATOR, FIND_SMSC",
#  "SEARCH an operator/SMSC by its name",
#  $LEVEL_EVERYBODY
# ],

# [
#  "FIND_OPERATOR_ID",
#  "SEARCH an operator by its operatorid",
#  $LEVEL_EVERYBODY
# ],

# [
#  "FIND_SMSC_ID",
#  "SEARCH a smsc by its smscid",
#  $LEVEL_EVERYBODY
# ],

# [
#  "FIND_CUSTOMER",
#  "SEARCH a customer by its name\n",
#  $LEVEL_EVERYBODY
# ],

# [
#  "VIEW_SMSC_USAGE_DR, VIEW_SMSC_USAGE_CR, VIEW_SMSC_USAGE_MO",
#  "SHOW smsc usage",
#  $LEVEL_EVERYBODY
# ],

# [
#  "VIEW_OPERATOR_ROUTING_DR,VIEW_OPERATOR_ROUTING_CR",
#  "SHOW operator routing",
#  $LEVEL_EVERYBODY
# ],

# [
#  "VIEW_CUSTOMER_ROUTING",
#  "SHOW customer routing",
#  $LEVEL_EVERYBODY
# ],

# [
#  "VIEW_ROUTING_PREFERENCES",
#  "SHOW routing preferences",
#  $LEVEL_EVERYBODY
# ],

# [
#  "VIEW_NUMBERING_PLAN",
#  "SHOW the numbering plan of an operator",
#  $LEVEL_EVERYBODY
# ],

 [
  "VIEW_OFF_CONNECTIONS",
  "SHOW connections set to off",
  $LEVEL_EVERYBODY
 ],

# [
#  "VIEW_OFF_ROUTINGS",
#  "SHOW routing preferences set to off",
#  $LEVEL_EVERYBODY
# ],

# [
#  "VIEW_FORBIDDEN_ROUTING",
#  "SHOW all forbidden routings",
#  $LEVEL_EVERYBODY
# ],

#11
# [
#  "VIEW_MO_MESSAGE",
#  \&find_mo,
#  "FIND_MO",
#  "SHOW mo message (need day of month + msisdn or msgid)",
#  $LEVEL_EVERYBODY
# ],
#12
# [
#  \&find_mt,
#  "FIND_MT",
#  "SHOW mt message (need day of month + msisdn or orderid)",
#  $LEVEL_EVERYBODY
# ],

 [
  "SEARCH_MO_KEYWORD",
  "SHOW mo keyword",
  $LEVEL_EVERYBODY
 ],

 [
  "VIEW_CUSTOMER_INFO",
  "SHOW customer\n",
  $LEVEL_EVERYBODY
 ],

# [
#  \&extract_mo,
#  "EXTRACT MO MESSAGE",
#  $LEVEL_EVERYBODY
# ],

# [
#  \&extract_mt,
#  "EXTRACT MT MESSAGE",
#  $LEVEL_EVERYBODY
# ],

# [
#  "VIEW_OFF_RC_CR",
#  "SHOW customer routing set to off while routing is flagged \"permanent\"",
#  $LEVEL_SUPPORT
# ],

# [
#  "VIEW_DELTA_ROUTING",
#  "SHOW bad default routings",
#  $LEVEL_PROD
# ],

# [
#  "VIEW_DELTA_ROUTING_ROAMING_CR, VIEW_DELTA_ROUTING_FORBIDDEN_CR, VIEW_DELTA_ROUTING_OFF_CR",
#  "SHOW bad routings for customers routing",
#  $LEVEL_SUPPORT
# ],

# [
#  \&show_bad_udh_routings,
#  "SHOW bad UDH routings\n",
#  $LEVEL_SUPPORT
# ],

# [
#  "FIND_SMSC_ID; SWITCH_SMSC_DR_ONOFF, SWITCH_SMSC_CR_ONOFF",
#  "SET a connection to ON or OFF (select by smscid)",
#  $LEVEL_PROD,
# ],

# [
#  "FIND_SMSC; SWITCH_SMSC_NAME_DR_ONOFF, SWITCH_SMSC_NAME_CR_ONOFF",
#  "SET a connection to ON or OFF (select by smscname)",
#  $LEVEL_PROD,
# ],

# [
#  "SWITCH_PREFERENCE_ONOFF",
#  "SET a routing preference to ON or OFF (roaming working or roaming lost)",
#  $LEVEL_PROD
# ],

#15
 [
  \&switch_smsc_on,
  "SET a connection to on (using the package)",
  $LEVEL_SUPPORT
 ],

 [
    \&switch_smsc_off,
  "SET a connection to off (using the package)\n",
  $LEVEL_SUPPORT
 ],

# [
#  "TRASH_NUMBER",
#  "TRASH a phone number",
#  $LEVEL_CCS
# ],

# [
#  \&trash_numbers,
#  "TRASH a list of numbers (provided in a text file (one number per line))",
#  $LEVEL_CCS
# ],

#17
# [
#  \&trash_numbers2,
#  "TRASH a list of phonenumbers",
#  $LEVEL_CCS
# ],

# [
#  "UNTRASH_NUMBER",
#  "UNTRASH a phone number\n",
#  $LEVEL_CCS
# ],

#19
 [
 \&add_new_portednumber,
  "ADD new ported number (NOTE: only single MSISDN allowed)",
  $LEVEL_SUPPORT
 ],

# [
#  \&add_new_portednumber2,
#  "ADD new ported numbers (provided in a text file (See example: /usr/mobileway/example/portednumber.txt))",
#  $LEVEL_EVERYBODY
# ],

#20
 [
  \&add_new_mosession_keyword,
  "ADD new keyword to MO Sessionmanager",
  $LEVEL_SUPPORT
 ],

 [
  \&add_new_customerid,
  "ADD new CustomerID to MO SessionID/Taccode list (ONLY for HTTP/HTTPS accounts)\n",
  $LEVEL_SUPPORT
 ],

# [
#  \&ch_http_password,
#  "Update HTTP passwords (Must inform DBA to update DB record manually)",
#  $LEVEL_SUPPORT
# ],

# [
#  \&create_modem,
#  "Create modem account",
#  $LEVEL_SUPPORT
# ],

#22
# [
#  \&create_ixng,
#  "Create an account on IXNG",
#  $LEVEL_PROD
# ],

# [
#  \&add_mlb_ixng,
#  "Add an account on MLB IXNG",
#  $LEVEL_PROD
# ],

 [
  \&add_qpass,
  "Add Qpass (Cingular/Blue/Alltel)\n",
  $LEVEL_PROD
 ],

# [
#  \&search_cx,
#  "Search connection on connection servers\n",
#  $LEVEL_SUPPORT
# ],

# [
#  "DUP_SMSC",
#  "duplicate smsc (only sub-mt)",
#  100+$LEVEL_PROD
# ],

#26
 [
  "PKG_CHANGE_INTO_PRIORITY",
  "Create a connection operating with input priority (MUST INFORM DBA)\n",
  $LEVEL_OPERATOR
 ],

# [
#  "PKG_DUPLICATE_SMSC",
#  "Duplicate a smsc and its subsmsc. Servicetype is MT, MO or MT/MO",
#  $LEVEL_OPERATOR
# ],

# [
#  \&create_subsmsc,
#  "create a subsmsc\n",
#  $LEVEL_PROD
# ],

# [
#  \&update_routing,
#  "RECOMPUTE optimal routing",
#  $LEVEL_PROD
# ],

 [
  \&resync_cluster,
  "UPDATE cluster",
  $LEVEL_SUPPORT
 ],

 [
  \&resync_mo,
  "UPDATE mo chain",
  $LEVEL_SUPPORT
 ],

 [
  \&resync_cmg,
  "UPDATE cmg\n",
  $LEVEL_SUPPORT
 ],

 [
  \&resync_smscclose,
  "CLOSE SMSC\n",
  $LEVEL_SUPPORT
 ],

 [
  \&mtcustroutingcreate,
  "MT Customized Routing creation",
  $LEVEL_SUPPORT
 ],

 [
  \&bye_bye,
  "Exit $ARGV[0]\n",
  $LEVEL_SUPPORT
 ]
);


# ------------------------------------------------------------------------------
#                               Menus functions
# ------------------------------------------------------------------------------

sub default_function
{
    my %args = %{$_[0]};
    my @requests;
    my $sql;

    @requests = split(/ *, */, $args{"requests"});
    foreach (@requests)
    {
        $sql = $requests{$_};
        if ($sql =~ /((?:update)|(?:insert +into)) +([^ ,]+)/im)
        {
            if ($interface ne "html")
            {
                print "Warning: you are going to $1 table $2. Are you sure you want to proceed ?";
                last if (read_answer() eq "YeS");
                print "Action canceled...\n";
                return (0);
            }
        }
    }
    foreach (@requests)
    {
        sql_exec($requests{$_}, \%args);
    }
}


#sub switch_smsc_onoff
#{
#    my %args = %{$_[0]};
#
#    if ( ($args{"onoff"}!=1) and ($args{"onoff"}!=0) )
#    {
#       print STDERR "Invalid argument onoff in function switch_smsc_onoff.\n";
#       return (0);
#    }
#    sql_exec($requests{SWITCH_SMSC_DR}, \%args);
#    sql_exec($requests{SWITCH_SMSC_CR}, \%args);
#    #mail("updaterouting\@mobileway.com", "smscid $args{smscid} set to $args{onoff}", "by $username: $comming_from.");
#    return (1);
#}

#sub switch_preference_onoff
#{
#    my %args = %{$_[0]};
#
#    if ( ($args{"onoff"}!=1) and ($args{"onoff"}!=0) )
#    {
#       print STDERR "Invalid argument onoff in function switch_preference_onoff.\n";
#       return (0);
#    }
#    sql_exec($requests{SWITCH_PREFERENCE_ONOFF}, \%args);
#    #mail("updaterouting\@mobileway.com", "Routing of operatorid $args{operatorid} through smscid $args{smscid} set to $args{onoff}", "by $username: $comming_from.");
#    return (1);
#}

sub switch_smsc_on
{
    my %args = %{$_[0]};
    my $function;
    my ($smscid, $smscname);
    my $smsc;
    my $comment;
    my $now = localtime time;

    $smsc = ask_variable("smscid or smscname");
    $comment = ask_variable("comment");

    if ($smsc =~ /^[0-9]+$/)
    {
        $args{"smscid"} = $smsc;
        ($smscid, $smscname) = sql_get_result_array($requests{FIND_SMSC_ID}, \%args);
        print "Warning: you are going to switch on smsc \"$smscname\". Are you sure you want to proceed ?(Y/n)";
        if (read_answer() ne "Y")
        {
            print "Action canceled...\n";
            return (0);
        }
        $args{"smscname"} = $smscname;
    }
    else
    {
        $args{"smscname"} = $smsc;
    }

    sql_exec($requests{PKG_MANAGE_CONNECTION_SWITCH_ON}, \%args);
#    print "ssh 10.150.8.15 sudo /usr/mobileway/scripts/UDHrouting_ase.pl udh_routing_preferences-2-0.dat $smscid on $db_base $db_user $db_pass";
    system "ssh 10.150.8.15 sudo -u production1 /usr/mobileway/scripts/UDHrouting_ase.pl /opt/HUB/datafiles/udh_routing_preferences-2-0.dat $smscid on $db_base $db_user $db_pass";
    mail("routeops\@sap.com", "ezDB : $args{smscname} has been turn ON","Timestamp : $now\nThe Smsc  : $args{smscname} has been turn ON by $username\nComment   : $comment\n\nThis is an automated response from ezDB.\nPlease do not reply to this. Thank You.");
}

sub switch_smsc_off
{
    my %args = %{$_[0]};
    my $function;
    my ($smscid, $smscname);
    my $smsc;
    my $comment;
    my $now = localtime time;

    $smsc = ask_variable("smscid or smscname");
    $comment = ask_variable("comment");

    if ($smsc =~ /^[0-9]+$/)
    {
        $args{"smscid"} = $smsc;
        ($smscid, $smscname) = sql_get_result_array($requests{FIND_SMSC_ID}, \%args);
        print "Warning: you are going to switch off smsc \"$smscname\". Are you sure you want to proceed ?(Y/n)";
        if (read_answer() ne "Y")
        {
            print "Action canceled...\n";
            return (0);
        }
        $args{"smscname"} = $smscname;
    }
    else
    {
        $args{"smscname"} = $smsc;
    }

    sql_exec($requests{PKG_MANAGE_CONNECTION_SWITCH_OFF}, \%args);
#    print "ssh 10.150.8.15 sudo /usr/mobileway/scripts/UDHrouting_ase.pl udh_routing_preferences-2-0.dat $smscid off $db_base $db_user $db_pass";
    system "ssh 10.150.8.15 sudo -u production1 /usr/mobileway/scripts/UDHrouting_ase.pl /opt/HUB/datafiles/udh_routing_preferences-2-0.dat $smscid off $db_base $db_user $db_pass";
    mail("routeops\@sap.com", "ezDB : $args{smscname} has been turn OFF","Timestamp : $now\nThe Smsc  : $args{smscname} has been turn OFF by $username\nComment   : $comment\n\nThis is an automated response from ezDB.\nPlease do not reply to this. Thank You.");
}

#sub switch_smscs
#{
#    my %args = %{$_[0]};
#    my %args2;
#    my $smscid;
#
#    %args2 = %args;
#    foreach(split(/,/, $args{"smscids"}))
#    {
#       $args{"smscid"} = $_;
#       print "setting $_...\n";
#    }
#}

#sub find_mt
#{
#    system "/opt/oracle/OraHome1/bin/sqlplus -S easydb/eau711bu\@billing \@/opt/mobileway/scripts/mt_query.sql";
#}

#sub find_mo
#{
#    system "/opt/oracle/OraHome1/bin/sqlplus -S easydb/eau711bu\@billing \@/opt/mobileway/scripts/mo_query.sql";
#}

#sub extract_mo
#{
#    system "/opt/oracle/OraHome1/bin/sqlplus -S easydb/eau711bu\@billing \@/opt/mobileway/scripts/mo_extract.sql";
#}

#sub extract_mt
#{
#    system "/opt/oracle/OraHome1/bin/sqlplus -S easydb/eau711bu\@billing \@/opt/mobileway/scripts/mt_extract.sql";
#}


#sub show_bad_udh_routings
#{
#    system "ssh 10.150.8.15 /usr/mobileway/scripts/UDHrouting.pl /usr/mobileway/datafiles/udh_routing_preferences-2-0.dat report billing easydb eau711bu";
#}

#sub create_modem{
#    my %args = %{$_[0]};
#    my $msisdn;
#    my $router_address;
##./moModemProvisionning-1.4.sh SimcardMsisdn TargetInvertRouterComputer
#
#    $msisdn=ask_variable("msisdn");
#    $router_address=ask_variable("router_address");
#    system ("ssh autoaccount\@192.168.6.99 /home/autoaccount/moModemProvisionning-1.4/moModemProvisionning-1.4.sh /home/autoaccount/etc/moModemProvisionningNewArchitecture.cfg $msisdn $router_address");
#}

#sub ch_http_password
#{
#    my %args = %{$_[0]};
#    my $login;
#    my $password;
#
#    $login=ask_variable("http_login");
#    $password=ask_variable("new_password");
#    system ("ssh 192.168.60.11 sudo /usr/mobileway/scripts/ch_http_password.sh $login $password");
#}

sub create_ixng{
    my %args = %{$_[0]};
    my $login;
    my $password;
    my $accountid;
    my $ticket;

    if (-f "/tmp/ixng/request.txt")
    {
        print "A request is already pending, please retry in 1 minute\n";
        return(0);
    }
    $login=ask_variable("smpp_login");
    $password=ask_variable("smpp_password");
    $accountid=ask_variable("accountid");
    $ticket=ask_variable("WRM or magic number");
    $ticket =~ s/ //g;
    open(REQ, ">/tmp/ixng/request.txt") or die("Cannot create request file: $!");
    print REQ "$login $password $accountid $username $ticket\n";
    close(REQ);
    chmod(0666,">/tmp/ixng/request.txt");
    print "The account will be created in less than a minute\n";
}

sub add_mlb_ixng{
    my %args = %{$_[0]};
    my $login1 = 'mlb_1093683668';
    my $login2 = 'mlb_4278833361';
    my $accountid;
    my $ticket;
    my $shortCode;

    if (-f "/tmp/ixng/request_mlb.txt")
    {
        print "A request is already pending, please retry in 1
minute\n";
        return(0);
    }
    $accountid=ask_variable("accountid");
    $ticket=ask_variable("WRM or magic number");
    $shortCode=ask_variable("Short Code=>");
    $shortCode =~ s/ //g;
    $ticket =~ s/ //g;
    open(REQ, ">/tmp/ixng/request_mlb.txt") or die("Cannot create request
file: $!");
    print REQ "$login1 $login2 $accountid $username $shortCode $ticket";
    close(REQ);
    chmod(0666,">/tmp/ixng/request_mlb.txt");
    print "The account will be created in less than a minute\n";
}

sub add_qpass{
    my %args = %{$_[0]};
    my $qpassType;
    my $shortCode;
    my $price;
    my $prodID;
    my $prodDesc;
    my $instanceID;

    $qpassType=ask_variable("Qpass Type (1) Cingular (2) Blue (3) Alltel => ");
    $shortCode=ask_variable("Short Code => ");
    $price=ask_variable("Price =>");
    $prodID=ask_variable("Product ID =>");
    $prodDesc=ask_variable("Product Desc =>");
    $instanceID=ask_variable("Instance ID =>");

    $shortCode =~ s/ //g;
    $qpassType =~ s/ //g;
    $price =~ s/ //g;
    $prodID =~ s/ //g;
    $instanceID =~ s/ //g;
    $prodDesc =~ s/ /^/g;

#    system ("ssh 192.168.60.200 sudo /usr/mobileway/scripts/add_qpass.pl $qpassType $shortCode $price $prodID $prodDesc $instanceID");

    print "Please restart the process on 192.168.60.200 ...\n";
    print "Please test the added qpass ... \n";
}

#sub switch_preference_on
#{
#    my %args = %{$_[0]};
#
#    $args{"onoff"} = 1;
#    switch_preference_onoff(\%args);
#}

#sub switch_preference_off
#{
#    my %args = %{$_[0]};
#
#    $args{"onoff"} = 0;
#    switch_preference_onoff(\%args);
#}

#sub update_routing
#{
#   my %args = %{$_[0]};
#    my ($operatorid, $operatorname, $smscid, $smscname, $expected_smscid, $expected_smscname);
#    my $sql_buffer;
#    my $mail_content;
#    my $choice;
#
##    print($requests{"VIEW_DELTA_ROUTING"}." ///////////////////// \n");
#
#    sql_exec_file($delta_routing_file, $requests{"VIEW_DELTA_ROUTING"}, \%args);
#    open(DELTA_ROUTING_FILE, "<$delta_routing_file")
#       or die("Can't open delta_routing file: $!");
#
#    $mail_content = "ezdb launched by $username: $comming_from\n\nThe routing is beeing updated as follow:\n";
#    $_ = <DELTA_ROUTING_FILE>;
#    while (<DELTA_ROUTING_FILE>)
#    {
#       chomp;
#       if (($operatorid, $operatorname, $smscid, $smscname, $expected_smscid, $expected_smscname) = split(/,/))
#       {
#           $sql_buffer .= "-- $operatorname: $smscname -> $expected_smscname\n";
#           $mail_content .= "  $operatorname($operatorid): $smscname($smscid) -> $expected_smscname($expected_smscid)\n";
#           $_ = $requests{RECALC_ROUTING};
#           s/\$expected_smscid/$expected_smscid/g;
#           s/\$smscid/$smscid/g;
#           s/\$operatorid/$operatorid/g;
#           $sql_buffer .= $_;
#       }
#       else
#       {
#           print STDERR "Bad formatted line: $_\n";
#       }
#    }
#    close(DELTA_ROUTING_FILE);
#
##    print $sql_buffer;
#    print "Are you sure you want to change the routing this way ? (YeS/NO)";
#    $choice = read_answer();
#    if ($choice ne "YeS")
#    {
#       print "Canceled\n";
#       return (0);
#    }
#    sql_exec($sql_buffer);
#    #mail("updaterouting\@mobileway.com", "routing update", $mail_content."\n\nSQL requests:\n".$sql_buffer);
#}

#sub trash_numbers
#{
#    my %args = %{$_[0]};
#    my $phonenber;
#    my $operatorname;
#    my $sql_buffer;
#    my $mail_content;
#    my $choice;
#    my $filename;
#    my $n;
#
##    print($requests{"VIEW_DELTA_ROUTING"}." ///////////////////// \n");
#
#    $operatorname = ask_variable("operatorname");
#    $operatorname =~ s/\&/\\&/g;
#    $filename = ask_variable("csv_location");
#    if (not open(FILE, "<$filename"))
#   {
#       warn "Can't open file \"$filename\": $!\n";
#       return (0);
#    }
#    $n = 0;
#    while(<FILE>)
#    {
#       $n++;
#       unless (/\+[0-9]+/)
#       {
#           warn("\"$filename\": bad line $n");
#           return(0);
#       }
#    }
#    if ($n>1000)
#    {
#       warn("\"$filename\" contains too many lines ($n lines)!");
#       return(0);
#    }
#    $mail_content = "Those phone number have been trashed for operator \"$operatorname\":\n";
#    seek(FILE, 0, 0);
#    while(<FILE>)
#    {
#       chomp;
#       $phonenber = $_;
#       if ($phonenber =~ /\+[0-9]+/)
#       {
#           $_ = $requests{TRASH_NUMBER};
#           s/\$phonenber/$phonenber/g;
#           s/\$operatorname/$operatorname/g;
#           $mail_content .= "          $phonenber\n";
#           print "             $phonenber\n";
#           $sql_buffer .= $_;
#           $n++;
#       }
#       else
#       {
#           warn ("At line $n: \"$phonenber\" is not a valid phone number.\n");
#       }
#    }
#
#    close(FILE);
#    print "-----\n$sql_buffer\n------";
#    if ($n>0)
#    {
#       print "Are you sure you want to trash $n phone number(s) ? (Yes/No)";
#       $choice = read_answer();
#    }
#    else
#    {
#       $choice = "NO";
#    }
#    if ($choice ne "YeS")
#    {
#       print "Canceled...\n";
#       return (0);
#    }
#    sql_exec($sql_buffer);
#    #mail("updaterouting\@mobileway.com", "numbers trashed", $mail_content."\n\nSQL requests:\n".$sql_buffer);
#}

sub trash_numbers2
{
        my %args = %{$_[0]};
        my $phonenber;
        my $operatorname;
        my $sql_buffer;
        my $mail_content;
        my $choice;
        my $filename;
        my $n;
        my $not_all;                                    #Boolean
        my $not_blacklisted_numbers;    #List with wrong numbers.
        my @output_routagenum;
        my $previous_line_empty;

        $not_all=0;
        $n = 0;
        $previous_line_empty=0;

        # Take the numbers
        print "Enter the MSISDNs (one per line) (enter 2 blank lines to end):\n";
        $phonenber=read_answer();

        # We read until we find 2 consecutive empty lines
        while( ($phonenber) or  (($previous_line_empty == 0) and not ($phonenber)) ){
                if ($phonenber eq ""){
                        $previous_line_empty++;
                        $phonenber=read_answer();
                }
                else {
                        #$phonenber = $_;    # The actual line is in  $_
                        $previous_line_empty=0;

                        # Remove spaces
                        $phonenber =~ s/^\s*//g ;  #replace/beginning(space,tab,\n,\r)(zero or more))/for nothing/global(all the matches)
                        $phonenber =~ s/\s*$//g ;  #replace/(space,tab,\n,\r)(zero or more)end/for nothing/global(all the matches)

                        # Check if the number starts with a +, otherwise add it.
                        unless ($phonenber =~ /^\+/)  {
                                $phonenber= "+$phonenber";
                        }

                        # Check that now it is a correct number
                        #The number must be   "+digits"   exactly
                        if ($phonenber =~ /^\+[0-9]+$/){

                                # To clean.
                                $operatorname="";
                                @output_routagenum="";

                                #Get the operator for this number executing routagenum_commandline.pl
                                open(ROUTAGENUM ,"/opt/mobileway/scripts/routagenum_commandline.pl $phonenber |")  or die "Couldn't fork: $!\n";
                                # Read the output and parse the fields
                                while(<ROUTAGENUM>){
                                        chomp($_); # Removes the trailing newline if present
                                        @output_routagenum = split(/;/, $_);
                                        $operatorname   =$output_routagenum[0];
                                }
                                close(ROUTAGENUM);

                                # Check that we got an operator
                                if ($operatorname =~ /\w/){
                                        print "------------------------------------------------------------------------\n";
                                        print "The number: $phonenber from the operator: $operatorname added to list.\n";
                                        print "------------------------------------------------------------------------\n";
                                        # Here we have all the necessary information
                                        $operatorname =~ s/\&/\&\'||\'/g; # Change & for &'||'  on the operatorname.
                                        $_ = $requests{TRASH_NUMBER};
                                        s/\$phonenber/$phonenber/g;
                                        s/\$operatorname/$operatorname/g;
                                        $sql_buffer .= $_;
                                        $n++;
                                }
                                else{
                                        print "------------------------------------------------------------------------\n";
                                        warn("The number: $phonenber CANNOT BE BLACKLISTED (OPERATOR NOT FOUND)\n");
                                        print "------------------------------------------------------------------------\n";
                                        $not_all++;
                                        $not_blacklisted_numbers .= "\t$phonenber\n";
                                }
                        }

                        else {
                                print "------------------------------------------------------------------------\n";
                                warn("The number: $phonenber CANNOT BE BLACKLISTED (NOT A VALID PHONE NUMBER).\n");
                                print "------------------------------------------------------------------------\n";
                                $not_all++;
                                $not_blacklisted_numbers .= "\t$phonenber\n";
                        }
                $phonenber=read_answer();
                }
        }
        # Here we stop reading the input
        # And process all the numbers obtained

        # Final step
        if ($n>0){
                # If something went fine we ask for confirmation.
                print "\nAre you sure you want to trash $n phone number(s) ? (Yes/No)[Yes]: ";
                $choice = read_answer();
        }

        # If something went fine and we have the confirmation.
        if ( ($choice !~ /n/i ) and ($n>0) ){   # If choice doesn't have a n/N, go ahead.

                        # Execute Blacklisting on the database.
                        print "\nexec: $sql_buffer";
                        sql_exec($sql_buffer);
        }
        # In any other case
        else{
                print "\nCanceled...\n";
                return (0);
        }
}

#sub dup_smsc_n
#{
#    my %args = %{$_[0]};
#    my $script="/usr/mobileway/scripts/dup_smsc.sh";
#
#    print "*** Starting script $script...\n";
#    system($script) or
#       warn("Cannot execute $script: $!");
#    print "*** end of $script\n";
#}

#sub create_subsmsc0
#{
#    my %args = %{$_[0]};
#    my $script="/usr/mobileway/scripts/create_subsmsc.sh";
#
#    print "*** Starting script $script...\n";
#    system($script) or
#       warn("Cannot execute $script: $!");
#    print "*** end of $script\n";
#}


#
# This is the old function
#
#sub dup_smsc_n_0
#{
#    my %args = %{$_[0]};
#    my %args2;
#    my $smscid;
#    my $n;
#    my $machine;
#    my $mask_libsendsms;
#    my $i;
#    my $smscname;
#    my $new_smscname;
#    my $new_smscid;
#
#    $smscid = ask_variable("smscid");
#    $n = ask_variabme("n");
#    $machine = ask_variable("machine");
#    $mask_libsendsms = ask_variable("mask_libsendsms");
#    $args2{"requests"} = "FIND_SMSC_ID";
#    $args2{"smscid"} = $smscid;
#    sql_exec($requests{"FIND_SMSC_ID"}, \%args2);
#    print "Duplication of smscid $smscid $n time(s) on machine $machine with libsendsmsmask=$mask_libsendsms. Ok to proceed ?(YeS/no)\n";
#    for ($i=1; $i<=$n; $n++)
#    {
#       $new_smscname = $smscname."_P".$i;
#       $args{"new_smscname"} = $new_smscname;
#       sql_exec_file($dup_smsc_tmp, $requests{"DUP_SMSC"}, \%args, 1); #in raw mode
#       open(TMP, "<$dup_smsc_tmp")
#           or die("Cannot open temporary file after exectuting package DUP_SMSC: $!");
#       while(<TMP>)
#       {
#           next unless (/^SMSCID : ([0-9]+)$/);
#           $new_smscid = $1;
#           last;
#       }
#       close(TMP);
#       print "new_smscid = $new_smscid\n";
#       system ("ssh production1\@192.168.60.$machine mkdir /usr/mobileway/sendsms/spool/$new_smscname");
#       system ("ssh production1\@192.168.60.11 /usr/mobileway/scripts/makeProviders.sh -t $machine -l $mask_libsendsms -s $$new_smscid -m $new_smscname");
#    }
#}


sub bye_bye
{
    print "Come back soon...\n";
    exit(0);
}

sub append_log
{
    my $line = $_[0];
    my $timestamp;

    if (not open(LOG, ">>$logfile"))
    {
        warn("Can't open logfile:$!");
        return(0);
    }
    foreach (split(/\n/, $line))
    {
        chomp;
        $timestamp=localtime();
        print LOG "$timestamp: ($$:$username) $_\n";
    }
    close(LOG);
}










# *****************************************************************************
# *****************************************************************************
#                    DO NOT CHANGE ANYTHING BELOW THIS LINE
# *****************************************************************************
# *****************************************************************************


# ------------------------------------------------------------------------------

#                               Internal functions

# ------------------------------------------------------------------------------

sub ask_variable
{
    my $name = $_[0];

    print "Enter value for $name: ";
    return (read_answer());
}

sub ask_variable_html
{
    my $name = $_[0];

    print "$name: ";
    print textfield("var_$name"),"<br>\n";
}

sub ask_variables
{
    my $vars = $_[0];
    my $var_list = $_[1];
    my $variable;

    foreach $variable ($var_list =~ m/\$([a-zA-Z0-9]+)/g)
    {
        next
            if (defined($vars->{$variable}));
        $vars->{$variable} = ask_variable($variable);
    }
}

sub ask_variables_html
{
    my $vars = $_[0];
    my $var_list = $_[1];
    my $variable;

    foreach $variable ($var_list =~ m/\$([a-zA-Z0-9]+)/g)
    {
        next
            if (defined($vars->{$variable}));
        ask_variable_html($variable);
        $vars->{$variable} = 42;
    }
}

sub mail
{
    my $to = $_[0];
    my $subject = $_[1];
    my $mail = $_[2];

#    $to = "routingupdate\@mobileway.com";
#    $to = "nlannuzel\@mobileway.com";
#    $to = "mngoh\@mobileway.com";
    open(MAIL, "| /usr/sbin/sendmail -t")
        or die("Cannot fork a sendmail: $!");
    print MAIL "From: ezDB <Automated.Response\@mobile365>
To: $to
Subject: $subject

$mail";
    close(MAIL);
}

sub add_new_portednumber
{
    my %args = %{$_[0]};
    my $msisdn;
    my $operatorid;

    $msisdn=ask_variable("Msisdn");
    $operatorid=ask_variable("Operator ID");

    #Insert on master server
#    system ("ssh 10.150.8.15 sudo /opt/mobileway/scripts/portednumber.sh $msisdn $operatorid");
#    system ("ssh -i /opt/mobileway/etc/ezdb_key -l production1 10.150.8.15 /opt/mobileway/scripts/portednumber.sh $msisdn $operatorid");
    system ("ssh 10.150.8.15 sudo -u production1 /opt/HUB/scripts/portednumber.sh $msisdn $operatorid");
}

sub search_cx
{
    my %args = %{$_[0]};
    my $expr;

    $expr=ask_variable("Connection Name");
    system ("/usr/mobileway/scripts/findcx.sh $expr");
}

#sub add_new_portednumber2
#{
#    my %args = %{$_[0]};
#    my $file;
#
#    $file=ask_variable("Full File path");
#    system ("/usr/mobileway/scripts/portednumber2.sh $file");
#
#}

sub add_new_mosession_keyword
{
#    system ("ssh -t 192.168.60.124 sudo -u production1 /usr/mobileway/bin/addkeyword.pl");
}

sub add_new_customerid
{
    my %args = %{$_[0]};
    my $list;

    $list=ask_variable("CustomerID List (Comma Limited)");
    $list=~ s/\s//g;
#    system ("ssh 192.168.60.122 sudo /opt/mobileway/scripts/update_sessionidtaccode.sh $list");
#    system ("ssh 192.168.60.123 sudo /opt/mobileway/scripts/update_sessionidtaccode.sh $list");
}

sub resync_cluster
{
    #system "ssh 10.150.8.15 sudo /usr/mobileway/scripts/update_routing_ase.sh";
#    system "ssh 10.150.8.15 sudo -u production1 /usr/mobileway/scripts/update_routing_ase.sh";
#    if ( $username eq "production1" )
#    {
#       system "ssh production1\@10.150.8.15 /usr/mobileway/scripts/update_routing_ase.sh";
#    }
#    else
#    {
#       system "ssh -i /opt/mobileway/etc/ezdb_key -l production1 10.150.8.15 /usr/mobileway/scripts/update_routing_ase.sh";
#    }
    system "ssh 10.150.8.15 sudo -u production1 /opt/HUB/scripts/update_routing_ase.sh";
}

sub resync_mo
{
    #system "ssh 10.150.8.15 sudo /usr/mobileway/scripts/update_mo_ase.sh";
#    if ( $username eq "production1" )
#    {
#       system "ssh production1\@10.150.8.15 /usr/mobileway/scripts/update_mo_ase.sh";
#    }
#    else
#    {
#       system "ssh -i /opt/mobileway/etc/ezdb_key production1\@10.150.8.15 /usr/mobileway/scripts/update_mo_ase.sh";
#    }
    system "ssh 10.150.8.15 sudo -u production1 /opt/HUB/scripts/update_mo_ase.sh";
}

sub resync_cmg
{
    #system "ssh 10.150.8.15 sudo /usr/mobileway/scripts/maj_mocustomerinf_ase.sh";
#    if ( $username eq "production1" )
#    {
#       system "ssh production1\@10.150.8.15 /usr/mobileway/scripts/maj_mocustomerinf_ase.sh";
#    }
#    else
#    {
#       system "ssh -i /opt/mobileway/etc/ezdb_key production1\@10.150.8.15 /usr/mobileway/scripts/maj_mocustomerinf_ase.sh";
#    }
    system "ssh 10.150.8.15 sudo -u production1 /opt/HUB/scripts/maj_mocustomerinf_ase.sh";
}

#sub recalc_routing
#{
#    sql_exec($delta_routing_file, $requests{VIEW_DELTA_ROUTING});
#}

sub resync_smscclose
{
    if ( $primary_group eq "prodops" )
    {
    system "/opt/HUB/scripts/smscclose.sh";
    }
    else
    {
    print "SMSC CLOSE privilege is restricted to prodops only. ";
    }
}

sub mtcustroutingcreate
{
    my %args = %{$_[0]};
    my $function;
    my ($smscid, $smscname);
    my $smsc;
    my $comment;
    my $now = localtime time;

    my $countryids = ask_variable("country id(s) separated by a comma");
    if ($countryids =~ /^[0-9, ]+$/)
    {
        $args{"countryids"} = $countryids;
    }
    else
    {
        print "country id(s) has wrong format\n";
        print "Action canceled...\n";
        return (0);
    }

    my $sourcecustomer = ask_variable("source customer id");
    if ($sourcecustomer =~ /^[0-9]+$/)
    {
        $args{"sourcecustomer"} = $sourcecustomer;
    }
    else
    {
        print "source customer has wrong format\n";
        print "Action canceled...\n";
        return (0);
    }

    my $destcustomers = ask_variable("destination customer(s) separated by a comma");
    if ($destcustomers =~ /^[0-9, ]+$/)
    {
        $args{"destcustomers"} = $destcustomers;
    }
    else
    {
        print "destination customers(s) has wrong format\n";
        print "Action canceled...\n";
        return (0);
    }

    if ($crp_status == 0)
    {
        sql_exec($requests{BEFORE_CRP_MT_CUSTOMIZED_ROUTING_CREATION}, \%args);
    }
    else
    {
        sql_exec($requests{AFTER_CRP_MT_CUSTOMIZED_ROUTING_CREATION}, \%args);
    }
}

sub extract
{
    my $sql_file = $_[0];
    my $output = $_[1];
    my $raw = $_[3];
    my $extract_filename;
    my $lines;
    my $l;
    my @l_max;
    my $field;
    my $exitstatus;
    my $errormsg;

    if ($output)
    {
        $extract_filename = $output;
    }
    else
    {
        $extract_filename = $tmp_extract;
        $extract_filename =~ s/\.csv$/_$extract_counter.csv/;
    }

# Production database
#
##my $sql = "export LD_LIBRARY_PATH=/opt/oracle/OraHome1/lib; export ORACLE_HOME=/opt/oracle/OraHome1; /opt/oracle/OraHome1/bin/sqlplus easydb/eau711bu\@BILLING \@$sql_file";

    my $sql = "export SYBASE=/opt/HUB/sybase/ASE-SDK-15.7; $db_cmd -S $db_base -U $db_user -P $db_pass -w 3000 -s\\' -i $sql_file";
#print $sql;
#
    open(OUT, ">$extract_filename") or die("Can't write to \"$output\": $!");
    $lines = 0;

#print "****************** Command:\n";
#print $sql;
#print "\n****************** Request:\n";
#open (FILE, "<$sql_file");
#while(<FILE>)
#{
#       print $_;
#   }
#  close(FILE);
#print "\nOk?";
#die if (read_answer() eq "no");

    system("$sql > /tmp/$$.tmp");
    open (SQL, "</tmp/$$.tmp");
    while(<SQL>)
    {
        if (not $raw)
        {
            if (/^ORA-(.*): (.*)$/)
            {
                print "Error while executing SQL request: ORA error $1, error message: $2\n";
                last;
            }
            if (/^ExitStatus *= *(.*) *: *(.*)$/)
            {
                $exitstatus=$1;
                $errormsg=$2;
                print "Error returned by the package: $exitstatus ($errormsg)\n";
                last;
            }

            if ($lines == 0) {
                s/' ' ' '/';':';'/g;
                s/' '/';'/g;
            }
            s/'//g;

            if (not /^.*(;.*)*;$/) # skip invalid lines
            {
                if (/^.*(\'.*)*\'$/)
                {
                    if (s/\'/;/g)
                    {
                        s/\s*//g;
                        s/;;;/;:;/g;
                    }
                }
                else
                {
                    append_log("    skipping $_");
                    next;
                }
            }
            if (/.*-------.*/) {next;}
            if (/.*rows affected\).*/) {next;}
            s/(^\s*)|(\s*$)//g; # remove leading or trailing space
            s/\s*\;\s*/\;/g;      # remove spaces before or after ';'
            s/\;$//;             # remove ending ';'
            s/\;\:$//;             # remove ending ';:'
            s/^\;//;             # remove ending ';'
            s/,/\\,/g;          # escape ','
            s/\;/,/g;            # convert ';' to ','
            foreach $field (split(/,:,/))
            {
                print "$field";
                for (my $j=0;$j<(4- length($field)/8); $j++)
                {
                    print "     ";
                }
            }
            print "\n";
            s/,\:,/,/g;
        }
        print OUT "$_\n";
        $lines++;
        print "...................................................\n" if ($lines==1);

    }
    close(SQL);
#    unlink(/tmp/$$.tmp);
    close(OUT);

#    close(PAGER);

    if (defined(not defined($output)))
    {
        open(OUT, "<$extract_filename")
            or die("Can't read from \"$output\": $!");


        if ($interface eq "html")
        {
            print "<table border=2>\n";
            while(<OUT>)
            {
                chop();
                s/^/<tr><td>/;
                s/$/<\/tr><\/td>/;
                s/([^\\]),,/$1<\/td><td>&nbsp;<\/td><td>/g;
                s/([^\\]),/$1<\/td><td>/g;
                print $_."\n";
            }
            print "</table>\n";
            close(OUT);
            print "<i>CSV file available <a href=./dl_csv.pl?filename=$extract_filename>here</a>.</i><br><br><br><br><br><br>\n";
        }
        else
        {
#           while(<OUT>)
#           {
#               chomp;
#               $i = 0;
#
#               foreach (split /,/)
#               {
#                   printf("%2d ......%s\n", $i, $menu);
#                   $_ = substr($_,0,23);
#                   printf "$_          ";
#                   printf "    " if (length($_)<8);
#               }
#               printf "\n";
#               print "$_";
#           }
            close(OUT);
            if ($lines)
            {
                print "($lines lines saved into \"$extract_filename\")\n";
            }
            else
            {
                print "(empty set)\n";
            }
        }
    }
    $extract_counter++
}

sub sql_exec_0
{
    my $request_0 = $_[0];
    my $args = $_[1];
    my $file = $_[2];
    my $raw = $_[3];
    my $key;
    my $request = $request_0;
    my %args;
    my $arg;

    die("Request empty")
        unless ($request);


    if (defined($args))
    {
        %args = %{$args};
        foreach $key (keys %args)
        {
            $arg=$args{$key};
            $arg =~ s/\&/\\\\\\&/g;
            $request =~ s/\$$key/$arg/g;
        }
    }
        #JBI
#       print("$request\n");

    append_log("Executing SQL request:\n".$request."\n");

    if ($interface eq "html")
    {
        print "<tt>\n";
        print "<font color=green>\n";
        my $tmp = escapeHTML($request);
        $tmp =~ s/\-\-(.*)\n/<b>$1<\/b>\n/;
        $tmp =~ s/\n/<br>\n/g;
        print $tmp;
        print "</font>\n";
    }
    else
    {
        if ($display_sql)
        {
            print "===================================================\n";
            print $request;
        }
        else
        {
            $_ = $request;
            s/^\-\- (.*)\n/$1/;
            print "---------------------------------------------------\n";
            print "$1\n";
            print "...................................................\n";
        }
    }


    open(TMP, ">$tmp_request")
        or die("Can't create temporary file: $!");

#print TMP "set pages 30000;\n";
#print TMP "set lines 3000;\n";
#print TMP "set num 42;\n";

    print TMP "$request";
#print TMP "\nexit\n";
    close(TMP);
    extract($tmp_request, $file, $raw);
    if ($interface eq "html")
    {
        print "</tt>\n";
    }
    else
    {
        if ($display_sql)
        {
            print "===================================================\n\n\n\n";
        }
        else
        {
            print "---------------------------------------------------\n\n\n\n";
        }
    }
}

sub sql_exec_file
{
    my $filename = $_[0];
    my $request_0 = $_[1];
    my $args = $_[2];
    my $raw = $_[3];

    sql_exec_0($request_0, $args, $filename, $raw);
}

sub sql_exec
{
    my $request_0 = $_[0];
    my $args = $_[1];

     sql_exec_0($request_0, $args);
}

#sub sql_exec_pkg
#{
#    my $request_0 = $_[0];
#    my $args = $_[1];
#
#     sql_exec_0($request_0, $args);
#}

sub sql_get_result_array
{
    my $request = $_[0];
    my $args = $_[1];
    my @res;

    sql_exec_file($tmp_get_result, $request, $args);
    open(TMP, "<$tmp_get_result")
        or die("Can't open temporary file \"$tmp_get_result\": $!");
    $_ = <TMP>;
    $_ = <TMP>;
    close(TMP);
    chomp();
    @res = split(/,/);
    return (@res);
}

sub show_menu_txt
{
    my $i = 1;
    my ($function, $menu, $level);
    my @list;
    my $row;


    foreach $row (@menus)
    {
        @list = @{$row};
        ($function, $menu, $level) = @list;
        if ($runlevel>=$level)
        {
            printf("    %2d ......%s\n", $i, $menu);
        }
        $i++;
    }
}

sub show_menu_html
{
    my $i = 1;
    my ($function, $menu, $level);
    my @list;
    my $row;

    print header;
    print start_html("ezdb menu page");
    foreach $row (@menus)
    {
        @list = @{$row};
        ($function, $menu, $level) = @list;
        if ($runlevel>=$level)
        {
            $menu =~ s/^([^ ]*) /<a href=.\/ezdb.pl\?menu=$i>$1<\/a> /;
            print "$i $menu<br>\n";
#           printf("<a href=./ezdb.pl?menu=$i".">$i</a> $menu<br>\n");
        }
        $i++;
    }
}

sub read_answer
{
    my $str;

    $str = <STDIN>;
    chomp($str);
    return ($str);
}

sub do_menu
{
    my $menu_id=$_[0];
    my $i=1;
    my $key;
    my ($function, $menu, $level, $vars);
    my $confirm;
    my %args;

    ($function, $menu, $level, $vars) = @{$menus[$menu_id]};
    return
        if ($level>$runlevel);

    append_log("text mode: executing menu entry $menu_id \"$menu\", function \"$function\"\n");
    if (ref($function))
    {
        ask_variables(\%args, $vars);
        &$function(\%args);
    }
    else
    {
        $confirm = $1 if ($function =~ s/^(.*) *; *(.*) *$/$2/);
        foreach (split(/ *, */, $function))
        {
            $vars .= $requests{$_};
        }
        ask_variables(\%args, $vars);
        if (defined($confirm))
        {
            $args{"requests"} = $confirm;
            default_function(\%args);
        }
        $args{"requests"} = $function;
        default_function(\%args);
    }
}

sub do_menu_html
{
    my $menu_id=$_[0];
    my $i=1;
    my $key;
    my ($function, $menu, $level, $vars);
    my %args;

    ($function, $menu, $level, $vars) = @{$menus[$menu_id]};
    return
        if ($level>$runlevel);
    append_log("html: executing menu entry $menu_id \"$menu\", function \"$function\"\n");
    if (param("answered"))
    {
        foreach (param())
        {
#           print $_." -> ".param($_);
            $args{$1} = param($_) if (/^var_(.*)$/);
        }
        if (ref($function))
        {
            print header(-Content_type=>"text/plain");
            &$function(\%args);
        }
        else
        {
            print header;
            print start_html("Processing command");
            $args{"requests"} = $function;
            default_function(\%args);
            print end_html;
        }
    }
    else
    {
#       print param();
        if (not ref($function))
        {
            foreach (split(/ *, */, $function))
            {
                $vars .= $requests{$_};
            }
        }
        if ($vars =~ m/\$[a-zA-Z0-9]+/)
        {
            append_log("html: sending html form\n");
            print header;
            print start_html("Fill in the form");
            print start_form("POST", "./ezdb.pl?menu=".(1+$menu_id));
            ask_variables_html(\%args, $vars);
            if ($function =~ /update|insert/)
#           if ($function =~ /((?:xupdate)|(?:xinsert +into)) +([^ ,]+)/im)
            {
                print checkbox('confirmation','','OFF',"I'm sure I want to proceed"),"<br>\n";
            }
            print hidden("answered",1);
            print submit;
            print end_form;
            print end_html;
        }
        else
        {
            print header;
            print start_html("Redirection");
            print "<META http-equiv=\"refresh\" content=\"0; Url=./ezdb.pl?answered=1&menu=".(1+$menu_id)."\">\n";
            print end_html;
        }
    }
}


# ------------------------------------------------------------

#                            main

# ------------------------------------------------------------


$| = 1;

my $choice;
my $tty;


$display_sql = 0 unless $display_sql=$ENV{"EZDB_DISPLAY_SQL"};

#if (system("stty"))
#{
#    append_log("html: started\n");
#    $interface = "html";
#    $runlevel=6;
#    if ($choice = url_param("menu"))
#    {
#       if ($choice<1 or $choice>($#menus+1))
#       {
#           die("Bad choice");
#       }
#       else
#       {
#           do_menu_html($choice-1);
#       }
#    }
#    else
#    {
#       show_menu_html();
#    }
#}
#else
{
    #text mode

    append_log("text: started\n");
    $tty = `tty`;
    $tty =~ s/^\/dev\///;
    $_ = `w | grep \"$tty'[^0-9]\+'\"`;
    /^([^ ]+ +[^ ]+ +[^ ]+) +/;
    s/^([^ ]+) +([^ ]+) +([^ ]+) +.*/$1 on $2 from $3/;
    $comming_from = $_;
    chomp ($comming_from);
    $username=$ENV{"LOGNAME"};
    $primary_group = `groups | cut -f 1 -d " "`;
    chomp($primary_group);
    $runlevel = $runlevels{$primary_group} or $runlevel=0;

    if ( ($username eq "output") or ($username eq "production1") )
    {
#       warn("Sorry, you cannot use $ARGV[0] under $username login...");
#       exit (1);
        $runlevel=$LEVEL_SUPPORT
    }

    print "\n\nSwitch DB Script (FR DB <-> UK4 DB):\n";
    print "------------------------------------\n\n";
    print "Script: sudo -u production1 /opt/HUB/scripts/switch_db_fr.sh\n";
    print "Log: /opt/HUB/log/switch_db_fr.log\n\n\n";

    print "Hello $username!\nYour group is \"$primary_group\", runlevel=$runlevel\n";

    append_log("text: username is $username.\n");
    print "$comming_from\n";
    print "EZDB v$version, running as level $runlevel\n\n";
    while (1)
    {
        $extract_counter = 1;
        show_menu_txt();
        print "Your choice: ";
        $choice = read_answer();
        if ($choice<1 or $choice>($#menus+1))
        {
            print "Try again...\n";
            sleep(1);
        }
        else
        {
            do_menu($choice-1);
        }
        print "Press any key to continue... ";
        read_answer;
        print "\n\n\n";
    }
}
