#! /usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More 0.88;
use JSON;

require BenchmarkAnything::Storage::Frontend::Lib;

my $cfgfile   = "t/benchmarkanything-tapper-mysql.cfg";
my $dsn       = 'DBI:mysql:database=benchmarkanythingtest';
# my $cfgfile   = "t/benchmarkanything-tapper.cfg";
# my $dsn       = 'dbi:SQLite:t/benchmarkanything.sqlite';
my $output_json;
my $output;

sub verify {
        my ($input, $output, $fields, $query_file) = @_;

        for (my $i=0; $i < @{$input->{BenchmarkAnythingData}}; $i++) {
                my $got      = $output->[$i];
                my $expected = $input->{BenchmarkAnythingData}[$i];
                foreach my $field (@$fields) {
                        is($got->{$field},  $expected->{$field},  "re-found [$i].$field = $expected->{$field}");
                        # diag "got = ".Dumper($got);
                }
        }
}

# Search for benchmarks, verify against expectation
sub query_and_verify {
        my ($balib, $query_file, $expectation_file, $fields) = @_;

        my $query    = JSON::decode_json("".File::Slurp::read_file($query_file));
        my $expected = JSON::decode_json("".File::Slurp::read_file($expectation_file));
        my $output   = $balib->search($query);
        verify($expected, $output, $fields, $query_file);
}


diag "\nUsing DSN: '$dsn'";

diag "\n========== Test lib config ==========";

my $balib = BenchmarkAnything::Storage::Frontend::Lib
 ->new(cfgfile => $cfgfile,
       really  => $dsn,
       backend => 'tapper',
       verbose => 1,
       debug   => 1,
      )
 ->connect;
is ($balib->{config}{benchmarkanything}{backends}{tapper}{benchmark}{dsn}, $dsn, "config - dsn");

diag "\n========== Test typical queries ==========";

# Create and fill test DB
$balib->createdb;
$balib->add (JSON::decode_json("".File::Slurp::read_file('t/valid-benchmark-anything-data-01.json')));

# Search for benchmarks, verify against expectation
query_and_verify($balib,
                 "t/query-benchmark-anything-01.json",
                 "t/query-benchmark-anything-01-expectedresult.json",
                 [qw(NAME VALUE)]
                );
query_and_verify($balib,
                 "t/query-benchmark-anything-02.json",
                 "t/query-benchmark-anything-02-expectedresult.json",
                 [qw(NAME VALUE comment compiler keyword)]
                );
query_and_verify($balib,
                 "t/query-benchmark-anything-03.json",
                 "t/query-benchmark-anything-03-expectedresult.json",
                 [qw(NAME VALUE comment compiler keyword)]
                );

# Finish
done_testing;
