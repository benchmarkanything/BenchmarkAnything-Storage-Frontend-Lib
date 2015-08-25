#! /usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More 0.88;
use JSON;

require BenchmarkAnything::Storage::Frontend::Lib;

# my $cfgfile   = "t/benchmarkanything-tapper-mysql.cfg";
# my $dsn       = 'DBI:mysql:database=benchmarkanythingtest';
my $cfgfile   = "t/benchmarkanything-tapper.cfg";
my $dsn       = 'dbi:SQLite:t/benchmarkanything.sqlite';

# test config
my $balib = BenchmarkAnything::Storage::Frontend::Lib->new(cfgfile => $cfgfile,
                                                           really  => $dsn
                                                          );
$balib->connect;
is ($balib->{config}{benchmarkanything}{backends}{tapper}{benchmark}{dsn}, $dsn, "config - dsn");

my$input_json = File::Slurp::read_file('t/valid-benchmark-anything-data-01.json');
my $input     = JSON::decode_json($input_json);
# Create and fill test DB
$balib->createdb;
#$balib->add($input);

# Finish
done_testing;
