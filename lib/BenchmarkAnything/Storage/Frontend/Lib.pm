use strict;
use warnings;
package BenchmarkAnything::Storage::Frontend::Lib;
# ABSTRACT: Basic functions to access a BenchmarkAnything store

=head2 new

Instantiate a new object.

=over 4

=item * cfgfile

Path to config file. If not provided it uses env variable
C<BENCHMARKANYTHING_CONFIGFILE> or C<$home/.benchmarkanything.cfg>.

=back

=cut

sub new
{
        my $class = shift;
        my $self  = bless { @_ }, $class;
        $self->_read_config;
        return $self;
}

=head2 _read_config

Reads the config file; either from given file name, or env variable
C<BENCHMARKANYTHING_CONFIGFILE> or C<$home/.benchmarkanything.cfg>.

=cut

sub _read_config
{
        my ($self) = @_;

        require File::Slurp;
        require YAML::Any;

        my $configfile  = $self->{cfgfile} || $ENV{BENCHMARKANYTHING_CONFIGFILE} || File::HomeDir->my_home . "/.benchmarkanything.cfg";
        my $configyaml  = File::Slurp::read_file($configfile);
        $self->{config} = YAML::Any::Load($configyaml);
        return $self;
}

sub connect
{
        my ($self) = @_;

        require DBI;
        no warnings 'once'; # avoid 'Name "DBI::errstr" used only once'

        # connect
        my $dsn      = $self->{config}{benchmarkanything}{backends}{tapper}{benchmark}{dsn};
        my $user     = $self->{config}{benchmarkanything}{backends}{tapper}{benchmark}{user};
        my $password = $self->{config}{benchmarkanything}{backends}{tapper}{benchmark}{password};
        $self->{dbh} = DBI->connect($dsn, $user, $password, {'RaiseError' => 1})
         or die "benchmarkanything: can not connect: ".$DBI::errstr;

        return $self;
}

1;
