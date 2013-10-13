#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::Login;
use strict;
use warnings;
use Zone;
use base qw(Zone);
use DBI;
my $dbh_phone = $Zone::dbh_phone;

sub main {
my $tries=0;
GETID:
my $id = prompt_digits(sound_filename("login", "enter id"), "1234567890", 4);
my $phonepin = prompt_digits(sound_filename("login", "enter pin"), "1234567890", 4);
my $sth = $dbh_phone->prepare("select count(*) from users where id = ? and phonepin = ? and phonepin != 0");
$sth->execute($id, $phonepin);
my $login_success = $sth->fetchrow_array();
$tries+=1;
if ($login_success == 0) {
play_sound("login", "invalid");
if ($tries > 3) {
return 0;
}
goto GETID;
}
$sth = $dbh_phone->prepare("select count(*) from current_calls where user_id = ?");
$sth->execute($id);
my $duplicate_login = $sth->fetchrow_array();
if ($duplicate_login >= 1) {
play_sound("login", "duplicate");
return(0);
}
$sth = $dbh_phone->prepare("update current_calls set user_id = ? where agi_uniqueid = ?");
$sth->execute($id, get_uniqueid());
my $lastlogin_dt = DateTime->now->ymd . " " . DateTime->now->hms;
$sth = $dbh_phone->prepare("update users set lastlogin_dt = ? where id = ?");
$sth->execute($lastlogin_dt, $id);
return $id;
}
1;
