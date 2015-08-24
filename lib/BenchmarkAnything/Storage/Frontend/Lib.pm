use strict;
use warnings;
package BenchmarkAnything::Storage::Frontend::Lib;
# ABSTRACT: Basic functions to access a BenchmarkAnything store

=head2 get_config

Reads a config file; either from given file name, or env variable
C<BENCHMARKANYTHING_CONFIGFILE> or C<$home/.benchmarkanything.cfg>.

=cut

sub get_config
{
        my ($cfgfile) = @_;

        require File::Slurp;
        require YAML::Any;

        my $configfile = $cfgfile || $ENV{BENCHMARKANYTHING_CONFIGFILE} || File::HomeDir->my_home . "/.benchmarkanything.cfg";
        my $configyaml = File::Slurp::read_file($configfile);
        my $config     = YAML::Any::Load($configyaml);
        return $config;
}

1;
