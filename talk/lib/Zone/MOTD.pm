#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::MOTD;
use strict;
use warnings;
use Zone;
use base qw(Zone);

sub main {
my $userid = shift;
my $dbh = $Zone::dbh_phone;
my $motdfile = $Zone::config{configdir} . "latest_motd";
my $latest_id = -1; # no MOTD
if (-f $motdfile) {
open(my $fin, "<", $motdfile)
or die("Error: can't open $motdfile: $!\n");
chomp(my $line = <$fin>);
die("Error: line $line is not a MOTD ID\n") unless ($line =~ /^\d+$/);
close($fin);
$latest_id=$line;
}
my $sth = $dbh->prepare("select count(*) from motd_users where user_id = ?");
$sth->execute($userid);
my $count = $sth->fetchrow_array();
if ($count == 0) {
play_motd("first time", 1);
play_motd($latest_id) if ($latest_id > 0);
$sth = $dbh->prepare("insert into motd_users (user_id, latest_motd) values (?, ?)");
$sth->execute($userid, $latest_id);
}
else {
$sth = $dbh->prepare("select latest_motd from motd_users where user_id = ?");
$sth->execute($userid);
my $latest_listened = $sth->fetchrow_array();
if ($latest_id > 0 && $latest_listened < $latest_id) {
play_motd($latest_id, 0);
$sth = $dbh->prepare("update motd_users set latest_motd = ? where user_id=?");
$sth->execute($latest_id, $userid);
}
}
}

sub play_motd {
my $motd_id = shift;
my $interrupt = shift || 0;
PLAY:
play_sound("motd", $motd_id, $interrupt);
my $resp = prompt_digits(sound_filename("motd", "prompt"), "12", 1);
if ($resp == 1) { goto PLAY; }
}
1;
