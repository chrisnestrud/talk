#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::Conference;
use strict;
use warnings;
use Zone;
use base qw(Zone);
our $dbh_phone = $Zone::dbh_phone;
my $sth_removeghosts = $dbh_phone->prepare("delete from conf_users where uniqueid not in (select agi_uniqueid from current_calls)");
my $sth_confnos = $dbh_phone->prepare("select confno from privconf_confs where pin = ?");
my $sth_bridgecount = $dbh_phone->prepare("select count(uniqueid) from conf_users where confno = ?");
my $sth_addbridge = $dbh_phone->prepare("insert into privconf_confs (confno, pin, userid) values (?, ?, ?)");
my $sth_removebridge = $dbh_phone->prepare("delete from privconf_confs where confno = ?");
my $sth_bridges = $dbh_phone->prepare("select confno from privconf_confs");
my $sth_confdefaults = $dbh_phone->prepare("update conf_confs set locked = 0, announce = 1 where confno = ?");
my $sth_hasconf = $dbh_phone->prepare("select count(*) from privconf_confs where userid = ?");
my $sth_confadmin = $dbh_phone->prepare("select userid from privconf_confs where confno = ?");

sub main {
my $userid = shift;
conf_cleanup();
my %conferences;
$conferences{1} = 1006;
$conferences{2} = 1007;
$conferences{3} = 1008;
$conferences{4} = 1009;
$conferences{5} = 1010;
my $resp = 99;
while ($resp != 0) {
$resp = prompt_digits(sound_filename("conference", "main menu"), "1234560", 1);
if (defined($conferences{$resp})) {
set_location($userid, 'conf' . $resp);
if (is_admin($userid)) {
conf_admin($userid, $conferences{$resp});
}
else {
Zone::join_meetme($userid, $conferences{$resp});
}
set_location($userid, "confmenu");
}
elsif ($resp == 6) {
set_location($userid, "privconf");
privconf($userid); # private conferencing
set_location($userid, "confmenu");
}
}
}

sub privconf {
my $userid = shift;
conf_cleanup();
my $pin = prompt_digits(sound_filename("conference", "enter pin"), "1234567890", 4);
return if ($pin == 0 || $pin eq "");
$sth_confnos->execute($pin);
my $confno = $sth_confnos->fetchrow_array;
if (!defined($confno)) {
# don't create unless user is premium
if (!is_premium($userid)) {
play_sound("conference", "premium for privconf");
return;
}
# don't create if user has another active conference
$sth_hasconf->execute($userid);
my $hasconf = $sth_hasconf->fetchrow_array;
if ($hasconf > 0) {
play_sound("conference", "only one conference");
return;
}
# try to allocate an unused bridge
my $valid = 0;
for(3011..3020) {
my $check = $_;
$sth_bridgecount->execute($check);
my $count = $sth_bridgecount->fetchrow_array;
if ($count == 0) {
$valid = $check;
last;
}
}
if ($valid > 0) {
$confno=$valid;
$sth_addbridge->execute($confno, $pin, $userid);
}
}
# $confno should now be defined with a conference number
if (defined($confno)) {
$sth_confadmin->execute($confno);
my $confadmin = $sth_confadmin->fetchrow_array;
if ($userid == $confadmin || is_admin($userid)) {
conf_admin($userid, $confno);
}
else {
# adding and removing of users is in join_meetme
Zone::join_meetme($userid, $confno);
}
}
else {
play_sound("conference", "private conferences full");
}
}

sub conf_cleanup {
# remove ghosts (nonexistent users)
$sth_removeghosts->execute;
# remove empty conferences
$sth_bridges->execute();
while(my($bridge) = $sth_bridges->fetchrow_array()) {
$sth_bridgecount->execute($bridge);
my $count = $sth_bridgecount->fetchrow_array();
if ($count == 0) {
$sth_removebridge->execute($bridge);
$sth_confdefaults->execute($bridge);
}
}
}

sub conf_admin {
my $userid = shift;
my $confno = shift;
my $sth_getlocked = $dbh_phone->prepare("select locked from conf_confs where confno = ?");
my $sth_setlocked = $dbh_phone->prepare("update conf_confs set locked = ? where confno = ?");
my $sth_getannounce = $dbh_phone->prepare("select announce from conf_confs where confno = ?");
my $sth_setannounce = $dbh_phone->prepare("update conf_confs set announce = ? where confno = ?");
while (my $resp = prompt_digits(sound_filename("conference", "confadmin menu"), "1230", 1)) {
if ($resp == 1) {
# adding and removing of users is in join_meetme
Zone::join_meetme($userid, $confno, 1);
}
if ($resp == 2) {
$sth_getlocked->execute($confno);
my $locked = $sth_getlocked->fetchrow_array();
if ($locked == 0) {
$sth_setlocked->execute(1, $confno);
play_sound("conference", "locked set");
}
else {
$sth_setlocked->execute(0, $confno);
play_sound("conference", "locked unset");
}
}
if ($resp == 3) {
$sth_getannounce->execute($confno);
my $announce = $sth_getannounce->fetchrow_array();
if ($announce == 0) {
$sth_setannounce->execute(1, $confno);
play_sound("conference", "announce set");
}
else {
$sth_setannounce->execute(0, $confno);
play_sound("conference", "announce unset");
}
}
if ($resp == 0) {
return;
}
}
}
1;
