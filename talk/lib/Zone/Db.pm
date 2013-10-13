#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::RealBin/..";
package Zone::Db;
use strict;
use warnings;
use DBI;
require Exporter;
our $VERSION = '1.0';
our @ISA = qw(Exporter);
our @EXPORT = qw(&get_dbh_phone);

sub get_dbh_phone {
my %config;
$config{db_database} = "talk";
$config{db_host} = ":/var/run/mysqld/mysqld.sock";
$config{db_username} = "talk";
$config{db_password} = "";
my $dsn_phone = 'DBI:mysql:database=' . $config{db_database} . ';host=' .  $config{db_host} . ';';
my $dbh_phone = DBI->connect($dsn_phone, $config{db_username}, $config{db_password}, {AutoCommit=>0, RaiseError => 1})
or die("Error: can't connect to database\n");
return $dbh_phone;
}
1;
