#! /usr/bin/perl

use strict;
use warnings;
use Test::More 0.88;

require BenchmarkAnything::Storage::Frontend::Lib;

my $cfg1 = BenchmarkAnything::Storage::Frontend::Lib->new;
is($cfg1->{config}{benchmarkanything}{storage}{backend}{sql}{dsn}, "dbi:SQLite:t/benchmarkanything.sqlite", "cfg 1");

$ENV{BENCHMARKANYTHING_CONFIGFILE} = "t/benchmarkanything-2.cfg";
my $cfg2 = BenchmarkAnything::Storage::Frontend::Lib->new;
is($cfg2->{config}{benchmarkanything}{storage}{backend}{sql}{dsn}, "dbi:SQLite:t/benchmarkanything-alternative.sqlite", "cfg 2");

my $cfg3 = BenchmarkAnything::Storage::Frontend::Lib->new(cfgfile => "t/benchmarkanything-3.cfg");
is($cfg3->{config}{benchmarkanything}{storage}{backend}{sql}{dsn}, "dbi:SQLite:t/benchmarkanything-yet-another-alternative.sqlite", "cfg 3");

# Finish
done_testing;
