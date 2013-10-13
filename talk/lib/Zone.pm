package Zone;
use strict;
use warnings;
use File::Copy;
use Zone::Db;
use DateTime;
require Exporter;
our $VERSION = '1.0';
our @ISA = qw(Exporter);
our @EXPORT = qw(&get_datetime &play_datetime &set_location &tts_filename &play_file &error &play_sound &play_text &sound_filename &prompt_digits &record_file &debug &is_premium &is_cl &is_admin &get_uniqueid);

open STDERR, ">&STDOUT";

use MyAGI;
our $agi = new MyAGI;

use File::Basename;
use Digest::MD5 qw(md5_hex);
use FindBin;
use DBI;
use DBD::mysql;

our %config;
$config{basedir} = get_basedir();
$config{promptsdir} = $config{basedir} . "spool/prompts/";
$config{soundsdir} = $config{basedir} . 'sounds/';
$config{ttsdir} = $config{soundsdir} . "tts/";
$config{configdir} = $config{basedir} . "conf/";
$config{tz} = 'US/Eastern';

chdir($config{basedir})
or die("Can't chdir: $!\n");

our $dbh_phone = get_dbh_phone();

sub after_hangup {
my $uniqueid = shift || $agi->get_agi_var("uniqueid");
if (defined $uniqueid) {
my $sth = $dbh_phone->prepare("select user_id from current_calls where agi_uniqueid = ?");
$sth->execute($uniqueid);
my $id = $sth->fetchrow_array();
$sth = $dbh_phone->prepare("delete from current_calls where agi_uniqueid = ?");
$sth->execute($uniqueid);
# if user was in a conference, notify of departure
$sth = $dbh_phone->prepare("select confno from conf_users where uniqueid = ?");
$sth->execute($uniqueid);
my $confno = $sth->fetchrow_array();
if (defined($confno)) {
my $namefile = $config{basedir} . "spool/names/" . $id . ".wav";
my $joinfile = "/usr/share/asterisk/sounds/zone/conf-join.wav";
my $leavefile = "/usr/share/asterisk/sounds/zone/conf-leave.wav";
play_meetme($confno, 0, $namefile, $leavefile);
}
# remove from conference if necessary
$sth = $dbh_phone->prepare("delete from conf_users where uniqueid = ?");
$sth->execute($uniqueid);
}
}

sub version { $VERSION; }
sub DESTROY { }

sub set_location {
my $userid = shift;
my $loc = shift || "unknown";
my $last_update = DateTime->now->ymd . " " . DateTime->now->hms;
my $sth = $dbh_phone->prepare("update current_calls set loc = ?, last_update = ? where agi_uniqueid = ?");
$sth->execute($loc, $last_update, $agi->get_agi_var("uniqueid"));
}

sub play_file {
my $playfile = shift;
my $allow_interrupt = shift || 0;
$playfile = asterisk_filename($playfile);
if (defined($playfile)) {
debug("Playing file: $playfile");
if ($allow_interrupt == 0) {
$agi->stream_file($playfile);
}
else {
$agi->exec('background', $playfile);
}
}
}

sub error {
my $category = shift;
my $desc = shift;
debug("Error: $category: $desc");
}

sub play_text {
# speak the given message
my $text = shift;
my $allow_interrupt = shift;
$allow_interrupt = 0 unless $allow_interrupt;
if ($text =~ /^\d+$/) {
if (length($text) < 4) {
$agi->say_number($text);
}
else {
my @a = split(//, $text);
foreach my $number(@a) { $agi->say_number($number); }
}
}
else {
my $filename = tts_filename($text);
play_file($filename, $allow_interrupt);
}
}

sub tts_filename {
# returns filename of given TTS string
my $text = shift;
debug("Text: $text");
if (!-d $config{ttsdir}) {
mkdir($config{ttsdir})
or die("Error: can't make directory " . $config{ttsdir} . ": $!\n");
}
my $hash = text_hash($text);
my $hashfile = $config{ttsdir} . $hash . ".txt" ;
my $wavefile = $config{ttsdir} . $hash . ".wav";
unless( -f $wavefile ) {
open( fileOUT, ">", $hashfile);
print fileOUT "$text";
close( fileOUT );
my $execf="/usr/bin/text2wave " . $hashfile . " -F 8000 -o " .  $wavefile;
system( $execf );
unlink($hashfile);
if (!-f $wavefile) {
error("tts_filename", "The wave file " . $wavefile . " was not created successfully. Must disconnect.");
$agi->hangup();
exit(1);
}
}
return $wavefile;
}

sub text_hash {
# returns hash of text, useful for filenames
my $text = shift;
my $hash = md5_hex($text);
return $hash;
}

sub prompt_digits {
my $prompt_filename = shift; # filename
$prompt_filename=asterisk_filename($prompt_filename);
my $allowed_digits_string = shift || "1234567890";
my $max = shift || 99;
my @allowed_digits = split(//, $allowed_digits_string);
my $resp="";
my $received=0;
my $file_played=0;
debug("getting digits. max is $max, allowed string is $allowed_digits_string.");
while ($received != $max) {
my $dtmf=0; # as if nothing entered while prompt is played
my $input="";
BEGIN:
if ($file_played == 0) {
$dtmf=$agi->stream_file($prompt_filename, "1234567890");
#debug("after prompt dtmf is $dtmf");
$file_played=1;
}
$dtmf = 0 unless defined($dtmf);
if ($dtmf == 0 || $dtmf == 1) { # nothing entered yet
my $count = 0;
while ($dtmf == 0) {
$dtmf = $agi->wait_for_digit(5000);
$dtmf = 0 unless defined $dtmf;
$count += 1;
if ($count >= 3) {
debug("no digits received after tries, returning");
return $resp;
}
if ($dtmf == 0) {
if ($received == 0) {
# nothing entered, go to beginning so prompt is replayed and digits are captured
$file_played=0; # force replay
goto BEGIN;
}
elsif ($received > 0) {
# at least 1 digit received but nothing entered this time
play_sound("zone", "press_pound_if_finished");
}
}
}
}
$input = chr($dtmf);
# check for unallowed digits
my $bad=1; # assume the worst
foreach my $digit (@allowed_digits) {
if ($input eq $digit) {
$bad=0; # match found
last;
}
}
if ($dtmf == 0 || $dtmf == -1) {
return $resp;
}
if ($input eq "*") {
play_sound("zone", "entry cleared.");
$resp = "";
$received=0;
}
elsif ($input eq "#" ) {
# pound received, assume string is finished
$received=$max;
}
# following is here so * and # will definitely be accepted
elsif ($bad == 1) {
play_sound("zone", "Digit ignored.");
}
else {
my $origresp = $resp;
$resp .= $input;
$received+=1;
}
}
return $resp;
}

sub record_file {
# record a file. returns 1 if user recorded file, 0 if user aborted
my $filename = shift;
my $recfile = shift;
my $rectime = shift || 10000;
my $allow_interrupt = shift || 0;
my $pause = shift || 2; # seconds
$filename = asterisk_filename($filename);
$recfile = asterisk_filename($recfile);
if (defined($recfile)) {
debug("Recording file: $recfile");
play_file($filename, 1) if $filename;
$agi->record_file($recfile, 'wav', '#', $rectime, 0, 1, $pause);
my $resp = "99";
while ($resp ne "0") {
$resp = prompt_digits(sound_filename("zone", "record options"), "1230", 1);
if ($resp eq "1") {
play_file($recfile, 1);
}
elsif ($resp eq "2") {
$agi->record_file($recfile, 'wav', '#', $rectime, 0, 1, $pause);
}
elsif ($resp eq "3") {
return 1;
}
elsif ($resp eq "0") {
return 0;
}
}
}
}

sub debug {
my $string = shift;
my $priority = shift || 2;
#say("Debug.");
#say($string);
$agi->verbose("Debug: " . $string, $priority);
}

sub asterisk_filename {
# converts filename to what asterisk needs for play or record
my $path = shift;
my @suffixes = (".wav", ".gsm", ".sln");
my ($filename, $directories, $suffix) = fileparse($path, @suffixes);
my $asterisk_filename = $directories . $filename; # asterisk doesn't need extension
return $asterisk_filename;
}

sub get_basedir {
my @needed_dirs = ("bin", "lib", "spool", "sounds");
my $dir = $FindBin::RealBin;
my @dirs = File::Spec->splitdir($dir);
for(my $i = $#dirs; $i >= 0; $i --) {
my $path = "";
for(my $j=0; $j <= $i; $j++) { $path .= $dirs[$j] . "/"; }
my $found=1; # be optimistic
foreach my $nd (@needed_dirs) {
if (!-d $path . $nd) {
$found=0; }
}
if ($found == 1) { return $path; }
}
die("Error: basedir was not found.\n");
}

sub join_meetme {
my $id = shift;
my $room = shift || 1000;
my $forcejoin = shift || 0;
my $dt = DateTime->now->set_time_zone($config{tz});
my $meetme_recordingfile = $Zone::config{basedir} . "spool/meetme/rec_" . $dt->ymd . "_" . $dt->hms . "_" . $id . "_" . $room;
$meetme_recordingfile =~ s/:/-/g;
my $namefile = $config{basedir} . "spool/names/" . $id . ".wav";
my $joinfile = "/usr/share/asterisk/sounds/zone/conf-join.wav";
my $leavefile = "/usr/share/asterisk/sounds/zone/conf-leave.wav";
my $sth_conf = $dbh_phone->prepare("select size, locked, announce from conf_confs where confno = ?");
my $sth_add = $dbh_phone->prepare("insert into conf_users (uniqueid, confno, joined) values (?, ?, ?)");
my $sth_remove = $dbh_phone->prepare("delete from conf_users where uniqueid = ?");
my $sth_count = $dbh_phone->prepare("select count(*) from conf_users where confno = ?");
$sth_conf->execute($room);
my ($size, $locked, $announce) = $sth_conf->fetchrow_array();
if (!defined($size) || !defined($locked) || !defined($announce)) {
play_sound("conference", "not in database");
return(1);
}
if ($locked == 1 && $forcejoin != 1) {
play_sound("conference", "locked");
return(1);
}
$sth_count->execute($room);
my $count = $sth_count->fetchrow_array();
if ($count >= $size && !is_cl($id) && !is_admin($id)) {
play_sound("conference", "full");
return(1);
}
$Zone::agi->set_variable('MEETME_RECORDINGFILE', $meetme_recordingfile);
if ($count > 0) {
play_text($count);
if ($announce == 1) {
play_meetme($room, $id, $namefile, $joinfile);
}
}
# add user to bridge
$sth_add->execute(get_uniqueid(), $room, time());
# send to meetme $room, pin $room
my $meetme_options;
# p (pound exits), r (record), s (star gives menu)
if ($room >= 3000 && $room < 4000) {
$meetme_options = $room.'|prs|'.$room;
}
else {
$meetme_options = $room.'|ps|'.$room;
}
my $ret = $agi->exec('meetme', $meetme_options);
# remove user from bridge
$sth_remove->execute(get_uniqueid());
$sth_count->execute($room);
$count = $sth_count->fetchrow_array();
if ($announce == 1 && $count > 0) {
play_meetme($room, $id, $namefile, $leavefile);
}
}

sub play_meetme {
# play files to given meetme
my $room = shift; # meetme room number
my $id = shift; # user ID
my @files = @_;
# announce control is in join_meetme
my $callfilename = "meetme_conf" . $room . "_user" . $id . ".call";
# set up files to play
my $sth = $dbh_phone->prepare("insert into conf_play (confno, file) values (?, ?)");
foreach my $file(@files) {
$sth->execute($room, $file);
}
# make the call file
my $callfile = 'Channel: Local/1' . $room . '@confplay' . "\n";
$callfile .= "Context: confplay\n";
$callfile .= "Extension: 2" . $room . "\n";
$callfile .= "Priority: 1\n";
# write the callfile
open(FOUT, ">", "/var/spool/asterisk/" . $callfilename);
print FOUT $callfile;
close FOUT;
move("/var/spool/asterisk/" . $callfilename, "/var/spool/asterisk/outgoing/" . $callfilename);
}

sub user_has_capability {
my $userid = shift;
my $capability = shift;
if (!defined($userid) || !defined($capability)) {
return 0;
}
my $sth = $dbh_phone->prepare("select count(*) from capabilities where user_id = ? and capability = ?");
$sth->execute($userid, $capability);
return $sth->fetchrow_array();
}

sub is_premium {
my $userid = shift;
return 0 if (!defined($userid));
return user_has_capability($userid, "premium");
}

sub is_cl {
my $userid = shift;
return 0 if (!defined($userid));
return user_has_capability($userid, "cl");
}

sub is_admin {
my $userid = shift;
return 0 if (!defined($userid));
return user_has_capability($userid, "admin");
}

sub get_uniqueid {
return $Zone::agi->get_agi_var("uniqueid");
}

sub play_sound {
my $category = shift;
my $sound = shift;
my $interrupt = shift || 1;
my $fullpath = sound_filename($category, $sound);
play_file($fullpath, $interrupt);
}

sub sound_filename {
my $category = shift;
my $sound = shift;
$category=text_to_filename($category);
$sound = text_to_filename($sound);
my $dir = $config{soundsdir} . $category . "/";
my $fullpath = $dir . $sound;
if (!-d $config{soundsdir}) {
mkdir($config{soundsdir})
or die("Error: can't make directory " . $config{soundsdir} . ": $!\n");
}
if (!-d $dir) {
mkdir($dir)
or die("Error: can't make directory $dir: $!\n");
}
if ((!-f $fullpath . ".wav") && (!-f $fullpath . ".gsm")) {
my $ttsfile = tts_filename($category . "/" . $sound);
move($ttsfile, $fullpath . ".wav");
}
return $fullpath;
}

sub text_to_filename {
my $text = shift;
# remove anything other than letters, numbers, space, underline, and dash
$text =~ s/[^a-zA-Z0-9-_ ]//gis;
# turn dash or space into underline
$text =~ s/[- ]/_/gis;
# lowercase string
$text = lc($text);
return $text;
}
sub start_call {
# add info to current_calls
my $call_started = DateTime->now->ymd . " " . DateTime->now->hms;
my $sth = $dbh_phone->prepare("insert into current_calls (call_started, agi_channel, agi_type, agi_uniqueid, agi_callerid, agi_calleridname, agi_callingpres, agi_callingani2, agi_callington, agi_callingtns, agi_dnid, agi_rdnis) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
$sth->execute($call_started, $Zone::agi->get_agi_var("channel"), $Zone::agi->get_agi_var("type"), $Zone::agi->get_agi_var("uniqueid"), $Zone::agi->get_agi_var("callerid"), $Zone::agi->get_agi_var("calleridname"), $Zone::agi->get_agi_var("callingpres"), $Zone::agi->get_agi_var("callingani2"), $Zone::agi->get_agi_var("callington"), $Zone::agi->get_agi_var("callingtns"), $Zone::agi->get_agi_var("dnid"), $Zone::agi->get_agi_var("rdnis"));
}

sub play_datetime {
my $dt = shift;
if (!defined($dt)) {
error("datetime", "passed date is not defined");
return 0;
}
debug("say_datetime: received DT is " . $dt->ymd . " " . $dt->hms, 2);
# apparently asterisk converts to local time or something
# the dt object shows the correct time. the epoch is correct for the dt.
# that is, if you make a new dt based on the epoch, it will match the
# old dt
my $e = ($dt->epoch)+3600;
if ($dt->ymd ne DateTime->now->set_time_zone($config{tz})->ymd) {
$agi->execute("SAY DATE $e \"\"");
}
$agi->execute("SAY TIME $e \"\"");
}

sub get_datetime {
my $post_dt = shift;
if (!defined($post_dt)) { return DateTime->now; }
my ($dt_ymd, $dt_hms) = split(/ /, $post_dt);
my ($dt_y, $dt_mon, $dt_d) = split(/-/, $dt_ymd);
my ($dt_h, $dt_min, $dt_s) = split(/:/, $dt_hms);
my $dt = DateTime->new(year => $dt_y, month => $dt_mon, day => $dt_d, hour => $dt_h, minute => $dt_min, second => $dt_s, time_zone => "UTC");
return $dt;
}
1;
