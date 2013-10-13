#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::Voicemail;
use strict;
use warnings;
use Zone;
use DateTime;
use DateTime::Format::Strptime;
use DateTime::Format::Epoch;
my $dt_parser = DateTime::Format::Strptime->new(
pattern => '%y-%m-%d %H:%M:%S',
time_zone => 'UTC'
);
my $tz = $Zone::config{tz};
use base qw(Zone);
my $vmdir = $Zone::config{basedir} . "spool/voicemail/";
my $namedir = $Zone::config{basedir} . "spool/names/";
my $dbh_phone = $Zone::dbh_phone;
my $agi = $Zone::agi;

sub main {
my $userid = shift;
my $resp = 99;
while ($resp != 0) {
$resp = prompt_digits(sound_filename("voicemail", "main menu"), "12370", 1);
if ($resp == 1) {
send_message($userid);
}
elsif ($resp == 2) {
if (has_box($userid)) {
box($userid);
}
else {
play_sound("voicemail", "no box");
}
}
elsif ($resp == 3) {
play_sound("voicemail", "instructions", 1);
}
elsif ($resp == 0) {
return;
}
}
}

sub box {
my $userid = shift;
# the user's voicemail box
say_message_status($userid);
my $resp = 99;
while ($resp != 0) {
$resp = prompt_digits(sound_filename("voicemail", "box menu"), "120", 1);
if ($resp == 1) {
browse_messages($userid, 1);
}
elsif ($resp == 2) {
browse_messages($userid, 2);
}
elsif ($resp == 0) {
return;
}
}
}

sub browse_messages {
my $userid = shift;
my $browse_type = shift; # 1 new, 2 saved
debug("Browsing messages for user ID $userid, type $browse_type", 1);
my $sth = $dbh_phone->prepare("select count(*) from vm_msg where to_userid = ? and is_deleted = 0 and is_saved = ?");
if ($browse_type == 1) { $sth->execute($userid, 0); }
elsif ($browse_type == 2) { $sth->execute($userid, 1); }
my $count = $sth->fetchrow_array;
debug("There are $count messages in the browse list.", 2);
return(0) if ($count == 0);
$sth = $dbh_phone->prepare("select rowid, from_userid, to_userid, date_sent, date_received, msgfile_id from vm_msg where to_userid = ? and is_deleted = 0 and is_saved = ?");
if ($browse_type == 1) { $sth->execute($userid, 0); }
elsif ($browse_type == 2) { $sth->execute($userid, 1); }
my $sth2 = $dbh_phone->prepare("select id, callerid, recording_userid from vm_msgfile where id = ?");
my $counter=0;
while (my @msg_array = $sth->fetchrow_array) {
my %msg;
($msg{rowid}, $msg{from_userid}, $msg{to_userid}, $msg{date_sent}, $msg{date_received}, $msg{msgfile_id}) = (@msg_array);
debug("sent date is " . $msg{date_sent}, 2);
if (!defined($msg{date_received}) || $msg{date_received} eq "") {
my $dt_received = DateTime->now;
my $received = $dt_received->ymd . " " . $dt_received->hms;
$msg{date_received} = $received; # used later in message details
debug("updating received date to $received", 2);
my $sthrec = $dbh_phone->prepare("update vm_msg set date_received = ?  where rowid = ?");
$sthrec->execute($received, $msg{rowid});
}
$counter+=1;
debug("playing message $counter", 2);
play_sound("voicemail", "message");
play_text($counter);
play_sound("voicemail", "from");
play_file($namedir . $msg{from_userid}, 1);
debug("Getting msg file information using ID " . $msg{msgfile_id}, 1);
$sth2->execute($msg{msgfile_id});
my @msg2_array = $sth2->fetchrow_array;
my %msg2;
($msg2{id}, $msg2{callerid}, $msg2{recording_userid}) = (@msg2_array);
PLAY:
play_file($vmdir . $msg2{id}, 1);
# if new, mark as saved since message has been played
$msg{is_saved} = 0 unless defined($msg{is_saved});
if ($msg{is_saved} == 0) {
my $sthsave = $dbh_phone->prepare("update vm_msg set is_saved = 1 where rowid = ?");
$sthsave->execute($msg{rowid});
}
my $resp = 99;
MENU:
$resp = prompt_digits(sound_filename("voicemail", "message menu"), "1234560", 1);
if ($resp == 1) { goto PLAY; }
elsif ($resp == 2) {
my $sthdel = $dbh_phone->prepare("update vm_msg set is_deleted=1 where rowid = ?");
$sthdel->execute($msg{rowid});
play_sound("voicemail", "Message deleted");
}
# if 3, execution will simply continue
elsif ($resp == 4) {
send_message($userid, $msg{from_userid});
goto MENU;
}
elsif ($resp == 5) {
my $sthnew = $dbh_phone->prepare("update vm_msg set is_saved=0, is_deleted=0 where rowid = ?");
$sthnew->execute($msg{rowid});
play_sound("voicemail", "marked as new");
}
elsif ($resp == 6) {
play_sound("voicemail", "user id");
play_text($msg{from_userid});
play_sound("voicemail", "sent");
say_datetime($dt_parser->parse_datetime($msg{date_sent}));
play_sound("voicemail", "received");
say_datetime($dt_parser->parse_datetime($msg{date_received}));
goto MENU;
}
elsif ($resp == 0) { return; }
}
}

sub send_message {
my $from_userid = shift;
my $to_userid = shift || 0;
if ($to_userid == 0) {
while ($to_userid == 0) {
my $resp = prompt_digits(sound_filename("voicemail", "enter id of recipient"), "1234567890", 4);
if ($resp eq "") { return; }
my $exists = has_box($resp);
if ($exists == 1) { $to_userid=$resp; }
else {
play_sound("voicemail", "user does not exist");
}
}
}
if (voicemail_ignore($from_userid, $to_userid) == 1) {
play_sound("voicemail", "user ignoring");
return(1);
}
play_sound("voicemail", "message will be sent to");
play_file($namedir . $to_userid, 1);
my $prompt_filename = sound_filename("voicemail", "please record message");
my $recfile = "/tmp/vm_" . $to_userid . "_" . time();
my $rectime = 300000; # 5 minutes
# allow interrupt, 30-second pause before forced end
my $resp = record_file($prompt_filename, $recfile, $rectime, 1, 30);
if ($resp == 0) { return 0; }
my $sth = $dbh_phone->prepare("insert into vm_msgfile (callerid, recording_userid) values (?, ?)");
$sth->execute($agi->get_agi_var("callerid"), $from_userid);
my $msgfile = $dbh_phone->{'mysql_insertid'};
my $cmd = "mv " . $recfile . ".wav " . $vmdir . $msgfile . ".wav";
system($cmd);
if (!-f $vmdir . $msgfile . ".wav") {
error("voicemail", "message " . $msgfile . " not copied successfully.");
play_sound("voicemail", "copy error");
return 0;
}
$sth = $dbh_phone->prepare("insert into vm_msg (from_userid, to_userid, date_sent, msgfile_id, is_saved, is_deleted) values (?, ?, ?, ?, 0, 0)");
my $dt_sent = DateTime->now;
my $sent = $dt_sent->ymd . " " . $dt_sent->hms;
$sth->execute($from_userid, $to_userid, $sent, $msgfile);
play_sound("voicemail", "message sent success");
return 1;
}

sub say_datetime {
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
if ($dt->ymd ne DateTime->now->set_time_zone($tz)->ymd) {
$agi->execute("SAY DATE $e \"\"");
}
$agi->execute("SAY TIME $e \"\"");
}

sub new_msg_count {
my $userid = shift;
# returns count of new messages for $userid
my $sth = $dbh_phone->prepare("select count(*) from vm_msg where to_userid = ? and is_deleted = 0 and is_saved = 0");
$sth->execute($userid);
my $count = $sth->fetchrow_array;
$count = 0 unless defined $count;
return $count;
}

sub saved_msg_count {
my $userid = shift;
# returns count of saved messages for $userid
my $sth = $dbh_phone->prepare("select count(*) from vm_msg where to_userid = ? and is_deleted = 0 and is_saved = 1");
$sth->execute($userid);
my $count = $sth->fetchrow_array;
$count = 0 unless defined $count;
return $count;
}

sub say_message_status {
my $userid = shift;
my $new_messages = new_msg_count($userid);
my $saved_messages = saved_msg_count($userid);
play_sound("voicemail", "You have");
play_text($new_messages);
if ($new_messages == 1) { play_sound("voicemail", "new message"); }
else { play_sound("voicemail", "new messages"); }
play_sound("voicemail", "and");
play_text($saved_messages);
if ($saved_messages == 1) { play_sound("voicemail", "saved message"); }
else { play_sound("voicemail", "saved messages"); }
}

sub has_box {
# does $userid have a box? 1 yes, 0 no
my $userid = shift;
my $sth = $dbh_phone->prepare("select count(*) from users where phonepin != 0 and id = ?");
$sth->execute($userid);
my $ret = $sth->fetchrow_array;
return $ret;
}

sub voicemail_ignore {
# is $to ignoring voicemail from $userid
my $userid = shift;
my $to = shift;
my $sth = $dbh_phone->prepare("select count(*) from `ignore` where ignorer = ? and ignoring = ? and voicemail = 1");
$sth->execute($to, $userid);
return $sth->fetchrow_array;
}

sub announce_if_new{
my $userid = shift;
my $sth = $dbh_phone->prepare("select count(*) from vm_msg where to_userid = ? and is_saved=0 and is_deleted=0");
$sth->execute($userid);
my $newvoicemail = $sth->fetchrow_array;
if ($newvoicemail > 0) {
play_sound("login", "new voicemail");
}
}
1;
