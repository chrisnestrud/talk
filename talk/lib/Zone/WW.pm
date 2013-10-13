#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::WW;
use strict;
use warnings;
use Zone;
use Zone::Voicemail;
use base qw(Zone);

my $namedir = $Zone::config{basedir} . "spool/names/";

sub main {
my $calling_userid = shift;
my $dbh = $Zone::dbh_phone;
play_sound("ww", "intro");
my $sth = $dbh->prepare("select user_id, loc from current_calls order by call_started desc");
$sth->execute();
my $users = $sth->fetchall_hashref('user_id');
my @userids = keys(%$users);
my $highest_subscript = $#userids;
my $current_subscript=0;
my $resp=-1;
while ($resp != 0) {
my $userid = $userids[$current_subscript];
my $loc = $users->{$userid}->{loc};
my $namefile;
if (-f $namedir . $userid . ".wav") {
$namefile = $namedir . $userid;
}
else {
$namefile = tts_filename($userid);
}
PLAY:
$resp = prompt_digits($namefile, "12345690", 1);
if ($resp == 1) {
play_sound("ww", $loc);
}
if ($resp == 2) {
play_text($userid);
}
if ($resp == 3) {
Zone::Voicemail::send_message($calling_userid, $userid);
}
if ($resp == 4) {
$current_subscript-=1;
if ($current_subscript < 0) {
$current_subscript = $highest_subscript;
play_sound("ww", "end list");
}
}
if ($resp == 5) {
goto PLAY;
}
if ($resp == 6) {
$current_subscript+=1;
if ($current_subscript > $highest_subscript) {
$current_subscript=0;
play_sound("ww", "begin list");
}
}
if ($resp == 9) {
play_sound("ww", "instructions");
}
}
play_sound("ww", "end");
}
1;
