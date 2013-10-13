#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::Register;
use strict;
use warnings;
use Zone;
use base qw(Zone);
my $dbh_phone = $Zone::dbh_phone;
my $regfiles = $Zone::config{basedir} . 'spool/regfiles/';

sub main {
play_sound("register", "intro");
my $resp = -1;
while ($resp != 1) {
$resp = prompt_digits(sound_filename("register", "continue"), "10", 1);
if ($resp == 0) { return(0); }
}
my $referral_id = -1;
my $referring_userid = 0;
while ($referral_id < 100000) {
$referral_id = prompt_digits(sound_filename("register", "enter referral id"), "1234567890", 6);
if ($referral_id == 0) { return(0); }
my $sth = $dbh_phone->prepare("select count(*) from referrals where to_userid is null and referral_id = ?");
$sth->execute($referral_id);
my $exists = $sth->fetchrow_array();
if ($exists == 0) {
play_sound("register", "referral id not found");
$referral_id = -1;
}
else {
$sth = $dbh_phone->prepare("select from_userid from referrals where referral_id = ?");
$sth->execute($referral_id);
$sth->execute($referral_id);
$referring_userid = $sth->fetchrow_array();
play_sound("register", "you have been referred by");
play_file($Zone::config{basedir} . "spool/names/" . $referring_userid . ".wav");
}
}
my $phonepin=-1;
while ($phonepin < 1000) {
$phonepin = prompt_digits(sound_filename("register", "enter pin"), "1234567890", 4);
if ($phonepin == 0) { return(0); }
}
my $sth = $dbh_phone->prepare("insert into users (phonepin, register_dt, register_callerid, referring_userid) values (?, ?, ?, ?)");
my $register_dt = DateTime->now->ymd . " " . DateTime->now->hms;
my $register_callerid = $Zone::agi->get_agi_var("callerid");
$sth->execute($phonepin, $register_dt, $register_callerid, $referring_userid);
my $userid = $dbh_phone->last_insert_id(undef, undef, qw(users id));
if (!defined($userid)) {
play_sound("register", "registration error");
return(0);
}
$sth = $dbh_phone->prepare("update referrals set to_userid = ? where referral_id = ?");
$sth->execute($userid, $referral_id);
PLAY:
play_sound("register", "your id is");
play_text($userid);
play_sound("register", "and your pin is");
play_text($phonepin);
$resp=-1;
while($resp != 1) {
$resp = prompt_digits(sound_filename("register", "repeat"), "1234567890", 1);
if ($resp != 1) { goto PLAY; }
}
$resp = record_file(sound_filename("register", "username"), $regfiles . $userid . "-username", 10000, 1);
play_sound("register", "thank you");
return($userid);
}
1;
