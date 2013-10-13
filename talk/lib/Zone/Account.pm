#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::Account;
use strict;
use warnings;
use Zone;
use Zone::Recname;
use base qw(Zone);
my $dbh = $Zone::dbh_phone;

sub main {
my $userid = shift;
my $resp = -1;
while ($resp != 0) {
$resp = prompt_digits(sound_filename("account", "menu"), "1230", 1);
if ($resp == 1) {
Zone::Recname::record_name($userid);
}
if ($resp == 2) {
change_phonepin($userid);
}
if ($resp == 3) {
referral_menu($userid);
}
}
}

sub change_phonepin {
my $userid = shift;
my $phonepin = -1;
while ($phonepin < 1000) {
$phonepin = prompt_digits(sound_filename("account", "change phonepin"), "1234567890", 4);
if ($phonepin == 0) {
play_sound("account", "phonepin not changed");
return(0);
}
}
my $sth = $dbh->prepare("update users set phonepin = ? where id = ?");
$sth->execute($phonepin, $userid);
play_sound("account", "your phonepin is now");
play_text($phonepin);
return(1);
}

sub referral_menu {
my $userid = shift;
my $resp = -1;
while ($resp != 0) {
my $sth = $dbh->prepare("select count(*) from referrals where from_userid = ?");
$sth->execute($userid);
my $referral_count = $sth->fetchrow_array();
$resp = prompt_digits(sound_filename("account", "referral menu"), "120", 1);
if ($resp == 1) {
if ($referral_count >= 5) {
play_sound("account", "max 5 referrals");
}
else {
my $referral_id=0;
while ($referral_id == 0) {
$referral_id = int rand(800000)+100000;
$sth = $dbh->prepare("select count(*) from referrals where referral_id = ?");
$sth->execute($referral_id);
my $exists = $sth->fetchrow_array();
if ($exists > 0) {
$referral_id=0;
}
}
$sth = $dbh->prepare("insert into referrals (referral_id, from_userid) values (?, ?)");
$sth->execute($referral_id, $userid);
play_sound("account", "your referral id is");
play_text($referral_id);
}
}
if ($resp == 2) {
if ($referral_count == 0) {
play_sound("account", "no referrals");
}
else {
play_sound("account", "unused referral codes");
$sth = $dbh->prepare("select referral_id from referrals where from_userid = ? and to_userid is null");
$sth->execute($userid);
my $total=0;
while(my($rc) = $sth->fetchrow_array()) {
$total+=1;
play_sound("account", "referral code");
play_text($total);
play_sound("account", "is");
play_text($rc);
}
}
}
}
}

1;
