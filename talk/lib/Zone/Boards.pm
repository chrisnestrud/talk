#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::Boards;
use strict;
use warnings;
use File::Copy;
use Zone;
use Zone::Voicemail;
use base qw(Zone);
my $dbh = $Zone::dbh_phone;
my $namedir = $Zone::config{basedir} . "spool/names/";

sub main {
my $userid = shift;
my $category_id = -1;
play_sound("boards", "intro");
while($category_id != 0) {
$category_id = pick_category($userid);
}
}

sub pick_category {
my $userid = shift;
my $sth = $dbh->prepare("select * from board_categories order by category_id");
$sth->execute();
my $categories = $sth->fetchall_hashref('category_id');
my @categoryids = sort {$a cmp $b } keys(%$categories);
my $highest_subscript = $#categoryids;
if ($highest_subscript < 0) {
play_sound("boards", "no categories");
return(0);
}
my $current_subscript=0;
my $resp=-1;
while ($resp != 0) {
my $category_id = $categoryids[$current_subscript];
my $creating_userid = $categories->{$category_id}->{creating_userid};
my $name = $categories->{$category_id}->{name};
my $namefile;
if (-f $namedir . $creating_userid . ".wav") {
$namefile = $namedir . $creating_userid;
}
else {
$namefile = tts_filename($creating_userid);
}
PLAY:
$resp = prompt_digits(sound_filename("board_categories", $name), "1245690", 1);
if ($resp == 1) {
pick_topic($userid, $category_id);
}
if ($resp == 2) {
play_file($namefile);
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
play_sound("boards", "pick_category");
}
}
}

sub pick_topic {
my $userid = shift;
my $category_id = shift;
QUERY:
my $sth = $dbh->prepare("select * from board_topics where category_id = ? order by lastpost_dt");
$sth->execute($category_id);
my $topics = $sth->fetchall_hashref('topic_id');
my @topicids = sort {DateTime->compare_ignore_floating(get_datetime($topics->{$b}->{topic_dt}), get_datetime($topics->{$a}->{topic_dt})) } keys(%$topics);
my $highest_subscript = $#topicids;
my $current_subscript=0;
if ($highest_subscript < 0) {
play_sound("boards", "no topics");
if (create_topic($userid, $category_id) == 0) { return 0; }
$sth->finish;
goto QUERY;
}
my $resp=-1;
while ($resp != 0) {
my $topic_id = $topicids[$current_subscript];
my $creating_userid = $topics->{$topic_id}->{user_id};
my $lastpost_dt = $topics->{$topic_id}->{lastpost_dt};
my $namefile;
my $topicfile = $Zone::config{basedir} . "spool/board_topics/" . $topic_id . ".wav";
if (-f $topicfile) {
$namefile = $topicfile;
}
else {
$namefile = tts_filename("topic " . $topic_id);
}
PLAY:
$resp = prompt_digits($namefile, "123456790", 1);
if ($resp == 1) {
browse_topic($userid, $topic_id);
}
if ($resp == 2) {
play_file($Zone::config{basedir} . "spool/names/" . $creating_userid . ".wav");
}
if ($resp == 3) {
play_sound("boards", "last post made");
play_datetime(get_datetime($lastpost_dt));
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
if ($resp == 7) {
my $topic_id = create_topic($userid, $category_id);
browse_topic($userid, $topic_id);
$sth->finish;
goto QUERY;
}
if ($resp == 9) {
play_sound("boards", "pick_topic");
}
}
}

sub browse_topic {
my $userid = shift;
my $topic_id = shift;
QUERY:
my $sth = $dbh->prepare("select * from board_posts where topic_id = ?");
$sth->execute($topic_id);
my $posts = $sth->fetchall_hashref('post_id');
my @postids = sort {DateTime->compare_ignore_floating(get_datetime($posts->{$b}->{post_dt}), get_datetime($posts->{$a}->{post_dt})) } keys(%$posts);
my $highest_subscript = $#postids;
my $current_subscript=0;
if ($highest_subscript < 0) {
play_sound("boards", "no posts");
post_topic($userid, $topic_id);
$sth->finish;
goto QUERY;
}
my $resp=-1;
while ($resp != 0) {
my $post_id = $postids[$current_subscript];
my $creating_userid = $posts->{$post_id}->{user_id};
my $post_dt = $posts->{$post_id}->{post_dt};
my $is_deleted = $posts->{$post_id}->{is_deleted};
my $postfile = $Zone::config{basedir} . "spool/board_posts/" . $post_id . ".wav";
if (!-f $postfile) { $postfile = tts_filename("post $post_id"); }
if ($is_deleted == 1) { $postfile = sound_filename("boards", "post deleted"); }
PLAY:
$resp = prompt_digits($postfile, "123456790", 1);
if ($resp == 1) {
play_sound("boards", "posted");
play_datetime(get_datetime($post_dt));
}
if ($resp == 2) {
play_file($Zone::config{basedir} . "spool/names/" . $creating_userid . ".wav");
}
if ($resp == 3) {
Zone::Voicemail::send_message($userid, $creating_userid);
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
if ($resp == 7) {
post_topic($userid, $topic_id);
$sth->finish;
goto QUERY;
}
if ($resp == 9) {
play_sound("boards", "browse_topic");
}
}
}

sub post_topic {
my $userid = shift;
my $topic_id = shift;
my $recfile = "/tmp/post_" . $userid . "_" . time() . ".wav";
if (!record_file(sound_filename("boards", "post topic"), $recfile, 30000)) { return(0); }
my $sth = $dbh->prepare("insert into board_posts (topic_id, user_id, post_dt) values (?, ?, ?)");
my $post_dt = DateTime->now->ymd . " " . DateTime->now->hms;
$sth->execute($topic_id, $userid, $post_dt);
my $post_id = $dbh->last_insert_id(undef, undef, qw(boards_posts post_id));
my $postfile = $Zone::config{basedir} . "spool/board_posts/" . $post_id . ".wav";
debug("moving $recfile to $postfile");
move($recfile, $postfile);
if (!-f $postfile) {
play_sound("boards", "post error");
return(0);
}
$sth = $dbh->prepare("update board_topics set lastpost_dt = ? where topic_id = ?");
my $lastpost_dt = DateTime->now->ymd . " " . DateTime->now->hms;
$sth->execute($lastpost_dt, $topic_id);
play_sound("boards", "post successful");
return(1);
}

sub create_topic {
my $userid = shift;
my $category_id = shift;
my $recfile = "/tmp/topic_" . $userid . "_" . time() . ".wav";
if (!record_file(sound_filename("boards", "create topic"), $recfile, 10000)) { return(0); }
my $sth = $dbh->prepare("insert into board_topics(category_id, user_id) values (?, ?)");
$sth->execute($category_id, $userid);
my $topic_id = $dbh->last_insert_id(undef, undef, qw(board_topics topic_id));
my $topicfile = $Zone::config{basedir} . "spool/board_topics/" . $topic_id . ".wav";
debug("moving $recfile to $topicfile");
move($recfile, $topicfile);
if (!-f $topicfile) {
play_sound("boards", "topic create error");
return(0);
}
play_sound("boards", "create topic successful");
post_topic($userid, $topic_id);
return $topic_id;
}
1;
