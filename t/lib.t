#! /usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More 0.88;

require BenchmarkAnything::Storage::Frontend::Lib;

# my $cfgfile   = "t/benchmarkanything-tapper-mysql.cfg";
# my $dsn       = 'DBI:mysql:database=benchmarkanythingtest';
my $cfgfile   = "t/benchmarkanything-tapper.cfg";
my $dsn       = 'dbi:SQLite:t/benchmarkanything.sqlite';

my $balib  = BenchmarkAnything::Storage::Frontend::Lib->new(cfgfile => $cfgfile);
is ($balib->{config}{benchmarkanything}{backends}{tapper}{benchmark}{dsn}, $dsn, "config - dsn");

# Finish
done_testing;
