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

=item * really

Used for critical functions like createdb. Provide a true value or, in
case of L</createdb>, the DSN of the database that you are about to
(re-)create.

=item * backend

There are potentially multiple different backend stores. Currently
only backend C<tapper> is supported which means an SQL database
accessed with C<Tapper::Benchmark|Tapper::Benchmark>.

=item * verbose

Print out progress messages.

=item * debug

Pass through debug option to used modules, like
L<Tapper::Benchmark|Tapper::Benchmark>.

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

Internal function.

Reads the config file; either from given file name, or env variable
C<BENCHMARKANYTHING_CONFIGFILE> or C<$home/.benchmarkanything.cfg>.

Returns the object to allow chained method calls.

=cut

sub _read_config
{
        my ($self) = @_;

        require File::Slurp;
        require YAML::Any;

        my $configfile     = $self->{cfgfile} || $ENV{BENCHMARKANYTHING_CONFIGFILE} || File::HomeDir->my_home . "/.benchmarkanything.cfg";
        my $configyaml     = File::Slurp::read_file($configfile);
        $self->{config}    = YAML::Any::Load($configyaml);
        $self->{backend} ||= 'tapper';
        return $self;
}

=head2 connect

Connects to the database according to the DB handle from config.

Returns the object to allow chained method calls.

=cut

sub connect
{
        my ($self) = @_;

        if ($self->{backend} eq 'tapper')
        {
                require DBI;
                require Tapper::Benchmark;
                no warnings 'once'; # avoid 'Name "DBI::errstr" used only once'

                # connect
                print "Connect db...\n" if $self->{verbose};
                my $dsn      = $self->{config}{benchmarkanything}{backends}{tapper}{benchmark}{dsn};
                my $user     = $self->{config}{benchmarkanything}{backends}{tapper}{benchmark}{user};
                my $password = $self->{config}{benchmarkanything}{backends}{tapper}{benchmark}{password};
                my $dbh      = DBI->connect($dsn, $user, $password, {'RaiseError' => 1})
                 or die "benchmarkanything: can not connect: ".$DBI::errstr;

                # remember
                $self->{dbh}              = $dbh;
                $self->{tapper_benchmark} = Tapper::Benchmark->new({dbh => $dbh, debug => $self->{debug} });
        }
        else
        {
                die "benchmarkanything: backend ".$self->{backend}." not yet implemented.\nAvailable backends are: 'tapper'\n";
        }
        return $self;
}

=head2 _are_you_sure

Internal method.

Find out if you are really sure. Usually used in L</createdb>. You
need to have provided an option C<really> which matches the DSN of the
database that your are about to (re-)create.

If the DSN does not match it asks interactively on STDIN - have this
in mind on non-interactive backend programs, like a web application.

=cut

sub _are_you_sure
{
        my ($self) = @_;

        # DSN
        my $dsn = $self->{config}{benchmarkanything}{backends}{tapper}{benchmark}{dsn};

        # option --really
        if ($self->{really})
        {
                if ($self->{really} eq $dsn)
                {
                        return 1;
                }
                else
                {
                        print STDERR "DSN does not match - asking interactive.\n";
                }
        }

        # ask on stdin
        print "REALLY DELETE AND RE-CREATE DATABASE [$dsn] (y/N): ";
        read STDIN, my $answer, 1;
        return 1 if $answer && $answer =~ /^y(es)?$/i;

        # default: NO
        return 0;
}

=head2 createdb

Initializes the DB, as configured by C<backend> and C<dsn>.  On
backend C<tapper> this means executing the DROP TABLE and CREATE TABLE
statements that come with
L<Tapper::Benchmark|Tapper::Benchmark>. Because that is a severe
operation it verifies an "are you sure" test, by comparing the
parameter C<really> against the DSN from the config, or if that
doesn't match, asking interactively on STDIN.

=cut

sub createdb
{
        my ($self) = @_;

        if ($self->{backend} eq 'tapper')
        {
                if ($self->_are_you_sure)
                {
                        no warnings 'once'; # avoid 'Name "DBI::errstr" used only once'

                        require DBI;
                        require File::Slurp;
                        require File::ShareDir;
                        use DBIx::MultiStatementDo;

                        my $batch            = DBIx::MultiStatementDo->new(dbh => $self->{dbh});

                        # get schema SQL according to driver
                        my $dsn      = $self->{config}{benchmarkanything}{backends}{tapper}{benchmark}{dsn};
                        my ($scheme, $driver, $attr_string, $attr_hash, $driver_dsn) = DBI->parse_dsn($dsn)
                         or die "benchmarkanything: can not parse DBI DSN '$dsn'";
                        my ($dbname) = $driver_dsn =~ m/database=(\w+)/g;
                        my $sql_file = File::ShareDir::dist_file('Tapper-Benchmark', "tapper-benchmark-create-schema.$driver");
                        my $sql      = File::Slurp::read_file($sql_file);
                        $sql         =~ s/^use `testrundb`;/use `$dbname`;/m if $dbname; # replace Tapper::Benchmark's default

                        # execute schema SQL
                        my @results = $batch->do($sql);
                        if (not @results)
                        {
                                die "benchmarkanything: error while creating BenchmarkAnything DB: ".$batch->dbh->errstr;
                        }

                }
        }
        else
        {
                die "benchmarkanything: backend ".$self->{backend}." not yet implemented.\nAvailable backends are: 'tapper'\n";
        }

        return;
}

=head2 add ($data)

Adds all data points of a BenchmarkAnything structure to the backend
store.

=cut

sub add
{
        my ($self, $data) = @_;

        # --- validate ---
        if (not $data)
        {
                die "benchmarkanything: no input data provided.\n";
        }

        require BenchmarkAnything::Schema;
        print "Verify schema...\n" if $self->{verbose};
        if (not my $result = BenchmarkAnything::Schema::valid_json_schema($data))
        {
                die "benchmarkanything: add: invalid input: ".join("; ", $result->errors)."\n";
        }


        # --- add to storage ---

        if ($self->{backend} eq 'tapper')
        {
                # add data
                print "Add data...\n" if $self->{verbose};
                foreach my $chunk (@{$data->{BenchmarkAnythingData}}) { # ensure order, because T::Benchmark optimizes multi-chunk entries
                        my $success = $self->{tapper_benchmark}->add_multi_benchmark([$chunk]);
                        if (not $success)
                        {
                                die "benchmarkanything: error while adding data to backend '".$self->{backend}."': ".$@;
                        }
                }
                print "Done.\n" if $self->{verbose};
        }
        else
        {
                die "benchmarkanything: backend ".$self->{backend}." not yet implemented, available backends are: 'tapper'\n";
        }

        return $self;
}

=head2 search ($query)

Execute a search query against the backend store, currently
L<Tapper::Benchmark|Tapper::Benchmark>, and returns the list of found
data points, as configured by the search query.

=cut

sub search
{
        my ($self, $query) = @_;

        # --- validate ---
        if (not $query)
        {
                die "benchmarkanything: no query data provided.\n";
        }

        if ($self->{backend} eq 'tapper')
        {
                return $self->{tapper_benchmark}->search_array($query);
        }
        else
        {
                die "benchmarkanything: backend '.$self->{backend}.' not yet implemented, available backends are: 'tapper'\n";
        }
}

=head2 listnames ($pattern)

Returns an array ref with all metric NAMEs. Optionally allows to
restrict the search by a SQL LIKE search pattern, allowing C<%> as
wildcard.

=cut

sub listnames
{
        my ($self, $pattern) = @_;

        if ($self->{backend} eq "tapper")
        {
                return $self->{tapper_benchmark}->list_benchmark_names(defined($pattern) ? ($pattern) : ());
        }
        else
        {
                die "benchmarkanything: backend '.$self->{backend}.' not yet implemented, available backends are: 'tapper'\n";
        }
}

=head2 getpoint ($value_id)

Returns a single benchmark point with B<all> its key/value pairs.

=cut

sub getpoint
{
        my ($self, $value_id) = @_;

        if ($self->{backend} eq 'tapper')
        {
                require DBI;
                require Tapper::Benchmark;

                # query
                die "benchmarkanything: please provide a benchmark value_id'\n"
                 unless $value_id;
                my $point = $self->{tapper_benchmark}->get_single_benchmark_point($value_id);

                # output
                return $point;
        }
        else
        {
                die "benchmarkanything: backend '.$self->{backend}.' not yet implemented, available backends are: 'tapper'\n";
        }
}

1;
