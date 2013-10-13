#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::Recname;
use strict;
use warnings;
use Zone;
use base qw(Zone);
my $namedir = $Zone::config{basedir} . "spool/names/";

sub main {
my $userid = shift;
my $filename = $namedir . $userid . ".wav";
if (!-f $filename) {
record_name($userid);
}
play_sound("recname", "welcome back");
play_file($namedir . $userid, 0);
}

sub record_name {
my $userid = shift;
my $filename = $namedir . $userid . ".wav";
my $resp=0;
while ($resp != 1) {
$resp = record_file(sound_filename("recname", "record name"), $filename, 5000);
}
play_sound("recname", "name saved");
}
1;
