DROP TABLE IF EXISTS `board_categories`;
CREATE TABLE `board_categories` (
  `category_id` integer NOT NULL AUTO_INCREMENT,
  `name` text,
  `creating_userid` integer DEFAULT NULL,
  PRIMARY KEY (`category_id`)
);

DROP TABLE IF EXISTS `board_posts`;
CREATE TABLE `board_posts` (
  `post_id` integer NOT NULL AUTO_INCREMENT,
  `user_id` integer DEFAULT NULL,
  `post_dt` datetime DEFAULT NULL,
  `is_deleted` integer NOT NULL DEFAULT '0',
  `topic_id` integer DEFAULT NULL,
  PRIMARY KEY (`post_id`)
);

DROP TABLE IF EXISTS `board_topics`;
CREATE TABLE `board_topics` (
  `topic_id` integer NOT NULL AUTO_INCREMENT,
  `user_id` integer DEFAULT NULL,
  `lastpost_dt` datetime DEFAULT NULL,
  `category_id` integer DEFAULT NULL,
  PRIMARY KEY (`topic_id`)
);

DROP TABLE IF EXISTS `capabilities`;
CREATE TABLE `capabilities` (
  `user_id` integer DEFAULT NULL,
  `capability` text
);

DROP TABLE IF EXISTS `conf_confs`;
CREATE TABLE `conf_confs` (
  `confno` integer NOT NULL,
  `size` integer NOT NULL DEFAULT '5',
  `locked` integer NOT NULL DEFAULT '0',
  `announce` integer NOT NULL DEFAULT '1',
  PRIMARY KEY (`confno`)
);

DROP TABLE IF EXISTS `conf_play`;
CREATE TABLE `conf_play` (
  `id` integer NOT NULL AUTO_INCREMENT,
  `confno` integer DEFAULT NULL,
  `file` text,
  PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `conf_playlock`;
CREATE TABLE `conf_playlock` (
  `confno` integer NOT NULL
);

DROP TABLE IF EXISTS `conf_users`;
CREATE TABLE `conf_users` (
  `id` integer NOT NULL AUTO_INCREMENT,
  `uniqueid` text,
  `confno` integer DEFAULT NULL,
  `joined` integer DEFAULT NULL,
  PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `current_calls`;
CREATE TABLE `current_calls` (
  `agi_uniqueid` text,
  `agi_channel` text,
  `agi_type` text,
  `agi_callerid` text,
  `agi_calleridname` text,
  `agi_callingpres` text,
  `agi_callingani2` text,
  `agi_callington` text,
  `agi_callingtns` text,
  `agi_dnid` text,
  `agi_rdnis` text,
  `user_id` integer DEFAULT NULL,
  `loc` text,
  `call_started` datetime DEFAULT NULL,
  `last_update` datetime DEFAULT NULL
);

DROP TABLE IF EXISTS `ignore`;
CREATE TABLE `ignore` (
  `id` integer NOT NULL AUTO_INCREMENT,
  `ignorer` integer DEFAULT NULL,
  `ignoring` integer DEFAULT NULL,
  `voicemail` integer NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `incoming_history`;
CREATE TABLE `incoming_history` (
  `id` integer NOT NULL AUTO_INCREMENT,
  `agi_uniqueid` text,
  `agi_channel` text,
  `agi_type` text,
  `agi_callerid` text,
  `agi_calleridname` text,
  `agi_callingpres` text,
  `agi_callingani2` text,
  `agi_callington` text,
  `agi_callingtns` text,
  `agi_dnid` text,
  `agi_rdnis` text,
  `user_id` integer DEFAULT NULL,
  `start_dt` datetime DEFAULT NULL,
  `end_dt` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `item`;
CREATE TABLE `item` (
  `id` integer NOT NULL AUTO_INCREMENT,
  `incoming_id` integer NOT NULL,
  `price` decimal(10,0) DEFAULT NULL,
  `start_dt` datetime DEFAULT NULL,
  `end_dt` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `item_message`;
CREATE TABLE `item_message` (
  `item_id` integer DEFAULT NULL,
  `incoming_id` integer NOT NULL,
  `recording_user` integer NOT NULL,
  `sent_dt` datetime DEFAULT NULL,
  `received_dt` datetime DEFAULT NULL,
  `is_saved` integer NOT NULL DEFAULT '0',
  `is_deleted` integer NOT NULL DEFAULT '0'
);

DROP TABLE IF EXISTS `item_view`;
CREATE TABLE `item_view` (
  `item_id` integer NOT NULL,
  `incoming_id` integer NOT NULL,
  `viewed_dt` datetime NOT NULL
);

DROP TABLE IF EXISTS `motd_users`;
CREATE TABLE `motd_users` (
  `user_id` integer NOT NULL,
  `latest_motd` integer DEFAULT NULL,
  PRIMARY KEY (`user_id`)
);

DROP TABLE IF EXISTS `privconf_confs`;
CREATE TABLE `privconf_confs` (
  `confno` integer NOT NULL,
  `pin` integer NOT NULL,
  `userid` integer DEFAULT NULL,
  PRIMARY KEY (`confno`)
);

DROP TABLE IF EXISTS `referrals`;
CREATE TABLE `referrals` (
  `referral_id` integer NOT NULL,
  `from_userid` integer DEFAULT NULL,
  `to_userid` integer DEFAULT NULL,
  PRIMARY KEY (`referral_id`)
);

DROP TABLE IF EXISTS `suggestion`;
CREATE TABLE `suggestion` (
  `id` integer NOT NULL AUTO_INCREMENT,
  `incoming_id` integer NOT NULL,
  `is_deleted` integer NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` integer NOT NULL AUTO_INCREMENT,
  `phonepin` integer NOT NULL,
  `register_dt` datetime DEFAULT NULL,
  `register_callerid` text,
  `lastlogin_dt` datetime DEFAULT NULL,
  `referring_userid` integer DEFAULT NULL,
  PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `vm_msg`;
CREATE TABLE `vm_msg` (
  `from_userid` integer DEFAULT NULL,
  `to_userid` integer DEFAULT NULL,
  `date_sent` datetime DEFAULT NULL,
  `date_received` datetime DEFAULT NULL,
  `msgfile_id` integer DEFAULT NULL,
  `is_saved` integer DEFAULT NULL,
  `is_deleted` integer DEFAULT NULL,
  `rowid` integer NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`rowid`)
);

DROP TABLE IF EXISTS `vm_msgfile`;
CREATE TABLE `vm_msgfile` (
  `callerid` text,
  `recording_userid` integer DEFAULT NULL,
  `id` integer NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
);

