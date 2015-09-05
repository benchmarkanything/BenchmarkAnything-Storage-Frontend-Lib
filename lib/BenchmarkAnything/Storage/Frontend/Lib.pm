use strict;
use warnings;
package BenchmarkAnything::Storage::Frontend::Lib;
# ABSTRACT: Basic functions to access a BenchmarkAnything store

use Scalar::Util 'reftype';

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

=item * skipvalidation

Disables schema validation checking, e.g., when you know your data is
correct and want to save execution time, ususally for C<add()>.

=item * verbose

Print out progress messages.

=item * debug

Pass through debug option to used modules, like
L<Tapper::Benchmark|Tapper::Benchmark>.

=item * separator

Used for output format I<flat>. Sub entry separator (default=;).

=item * fb

Used for output format I<flat>. If set it generates [brackets] around
outer arrays (default=0).

=item * fi

Used for output format I<flat>. If set it prefixes outer array lines
with index.

=back

=cut

sub new
{
        my $class = shift;
        my $self  = bless { @_ }, $class;
        $self->_read_config;
        return $self;
}

sub _format_flat_inner_scalar
{
    my ($self, $result, $opt) = @_;

    no warnings 'uninitialized';

    return "$result";
}

sub _format_flat_inner_array
{
        my ($self, $result, $opt) = @_;

        no warnings 'uninitialized';

        return
         join($opt->{separator},
              map {
                   # only SCALARS allowed (where reftype returns undef)
                   die "benchmarkanything: unsupported innermost nesting (".reftype($_).") for 'flat' output.\n" if defined reftype($_);
                   "".$_
                  } @$result);
}

sub _format_flat_inner_hash
{
        my ($self, $result, $opt) = @_;

        no warnings 'uninitialized';

        return
         join($opt->{separator},
              map { my $v = $result->{$_};
                    # only SCALARS allowed (where reftype returns undef)
                    die "benchmarkanything: unsupported innermost nesting (".reftype($v).") for 'flat' output.\n" if defined reftype($v);
                    "$_=".$v
                  } keys %$result);
}

sub _format_flat_outer
{
        my ($self, $result, $opt) = @_;

        no warnings 'uninitialized';

        my $output = "";
        die "benchmarkanything: can not flatten data structure (undef) - try other output format.\n" unless defined $result;

        my $A = ""; my $B = ""; if ($opt->{fb}) { $A = "["; $B = "]" }
        my $fi = $opt->{fi};

        if (!defined reftype $result) { # SCALAR
                $output .= $result."\n"; # stringify
        }
        elsif (reftype $result eq 'ARRAY') {
                for (my $i=0; $i<@$result; $i++) {
                        my $entry  = $result->[$i];
                        my $prefix = $fi ? "$i:" : "";
                        if (!defined reftype $entry) { # SCALAR
                                $output .= $prefix.$A.$self->_format_flat_inner_scalar($entry, $opt)."$B\n";
                        }
                        elsif (reftype $entry eq 'ARRAY') {
                                $output .= $prefix.$A.$self->_format_flat_inner_array($entry, $opt)."$B\n";
                        }
                        elsif (reftype $entry eq 'HASH') {
                                $output .= $prefix.$A.$self->_format_flat_inner_hash($entry, $opt)."$B\n";
                        }
                        else {
                                die "benchmarkanything: can not flatten data structure (".reftype($entry).").\n";
                        }
                }
        }
        elsif (reftype $result eq 'HASH') {
                my @keys = keys %$result;
                foreach my $key (@keys) {
                        my $entry = $result->{$key};
                        if (!defined reftype $entry) { # SCALAR
                                $output .= "$key:".$self->_format_flat_inner_scalar($entry, $opt)."\n";
                        }
                        elsif (reftype $entry eq 'ARRAY') {
                                $output .= "$key:".$self->_format_flat_inner_array($entry, $opt)."\n";
                        }
                        elsif (reftype $entry eq 'HASH') {
                                $output .= "$key:".$self->_format_flat_inner_hash($entry, $opt)."\n";
                        }
                        else {
                                die "benchmarkanything: can not flatten data structure (".reftype($entry).").\n";
                        }
                }
        }
        else {
                die "benchmarkanything: can not flatten data structure (".reftype($result).") - try other output format.\n";
        }

        return $output;
}

sub _format_flat
{
        my ($self, $result, $opt) = @_;

        # ensure array container
        # for consistent output in 'getpoint' and 'search'
        my $resultlist = reftype($result) eq 'ARRAY' ? $result : [$result];

        my $output = "";
        $opt->{separator} = ";" unless defined $opt->{separator};
        $output .= $self->_format_flat_outer($resultlist, $opt);
        return $output;
}

=head2 _output_format

This function converts a data structure into requested output format.

=head3 Output formats

The following B<output formats> are allowed:

 yaml   - YAML::Any
 json   - JSON (default)
 xml    - XML::Simple
 ini    - Config::INI::Serializer
 dumper - Data::Dumper (including the leading $VAR1 variable assignment)
 flat   - pragmatic flat output for typical unixish cmdline usage

=head3 The 'flat' output format

The C<flat> output format is meant to support typical unixish command
line uses. It is not a strong serialization format but works well for
simple values nested max 2 levels.

Output looks like this:

=head4 Plain values

 Affe
 Tiger
 Birne

=head4 Outer hashes

One outer key per line, key at the beginning of line with a colon
(C<:>), inner values separated by semicolon C<;>:

=head4 inner scalars:

 coolness:big
 size:average
 Eric:The flat one from the 90s

=head4 inner hashes:

Tuples of C<key=value> separated by semicolon C<;>:

 Affe:coolness=big;size=average
 Zomtec:coolness=bit anachronistic;size=average

=head4 inner arrays:

Values separated by semicolon C<;>:

 Birne:bissel;hinterher;manchmal

=head4 Outer arrays

One entry per line, entries separated by semicolon C<;>:

=head4 Outer arrays / inner scalars:

 single report string
 foo
 bar
 baz

=head4 Outer arrays / inner hashes:

Tuples of C<key=value> separated by semicolon C<;>:

 Affe=amazing moves in the jungle;Zomtec=slow talking speed;Birne=unexpected in many respects

=head4 Outer arrays / inner arrays:

Entries separated by semicolon C<;>:

 line A-1;line A-2;line A-3;line A-4;line A-5
 line B-1;line B-2;line B-3;line B-4
 line C-1;line C-2;line C-3

=head4 Additional markup for arrays:

 --fb            ... use [brackets] around outer arrays
 --fi            ... prefix outer array lines with index
 --separator=;   ... use given separator between array entries (defaults to ";")

Such additional markup lets outer arrays look like this:

 0:[line A-1;line A-2;line A-3;line A-4;line A-5]
 1:[line B-1;line B-2;line B-3;line B-4]
 2:[line C-1;line C-2;line C-3]
 3:[Affe=amazing moves in the jungle;Zomtec=slow talking speed;Birne=unexpected in many respects]
 4:[single report string]

=cut

sub _output_format
{
        my ($self, $data, $opt) = @_;

        my $output  = "";
        my $outtype = $opt->{outtype} || 'json';

        if ($outtype eq "yaml")
        {
                require YAML::Any;
                $output .= YAML::Any::Dump($data);
        }
        elsif ($outtype eq "json")
        {
                eval "use JSON -convert_blessed_universally";
                my $json = JSON->new->allow_nonref->pretty->allow_blessed->convert_blessed;
                $output .= $json->encode($data);
        }
        elsif ($outtype eq "ini") {
                require Config::INI::Serializer;
                my $ini = Config::INI::Serializer->new;
                $output .= $ini->serialize($data);
        }
        elsif ($outtype eq "dumper")
        {
                require Data::Dumper;
                $output .= Data::Dumper::Dumper($data);
        }
        elsif ($outtype eq "xml")
        {
                require XML::Simple;
                my $xs = new XML::Simple;
                $output .= $xs->XMLout($data, AttrIndent => 1, KeepRoot => 1);
        }
        elsif ($outtype eq "flat") {
                $output .= $self->_format_flat( $data, $opt );
        }
        else
        {
                die "benchmarkanything-storage: unrecognized output format: $outtype.";
        }
        return $output;
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

        require File::HomeDir;
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
        print "REALLY DROP AND RE-CREATE DATABASE TABLES [$dsn] (y/N): ";
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

        if (not $self->{skipvalidation}) {
            require BenchmarkAnything::Schema;
            print "Verify schema...\n" if $self->{verbose};
            if (not my $result = BenchmarkAnything::Schema::valid_json_schema($data))
            {
                die "benchmarkanything: add: invalid input: ".join("; ", $result->errors)."\n";
            }
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

sub _get_user_agent
{
        my ($self) = @_;

        require Mojo::UserAgent;

        # query
        my $ua    = Mojo::UserAgent->new;
        return $ua;
}

sub _get_base_url
{
        shift->{config}{benchmarkanything}{frontends}{http}{base_url};
}

=head2 search ($query)

Execute a search query against the backend store, currently
L<Tapper::Benchmark|Tapper::Benchmark>, and returns the list of found
data points, as configured by the search query.

=cut

sub search
{
        my ($self, $query, $value_id) = @_;

        # --- validate ---
        if (not $query and not $value_id)
        {
                die "benchmarkanything: no query or value_id provided.\n";
        }

        if ($self->{backend} eq 'tapper')
        {
                # single values
                return $self->{tapper_benchmark}->get_single_benchmark_point($value_id) if $value_id;
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

        return $self->search(undef, $value_id);
        die "benchmarkanything: please provide a benchmark value_id'\n" unless $value_id;
}

sub _multi_point_stats
{
        my ($self, $values) = @_;

        require PDL::Stats::Basic;
        require PDL::Ufunc;
        require PDL::Core;

        my $data = PDL::Core::pdl(@$values);
        my $avg  = PDL::Stats::Basic::average($data);
        return {
                avg         => PDL::Core::sclr($avg),
                stdv        => PDL::Stats::Basic::stdv($data),
                min         => PDL::Ufunc::min($data),
                max         => PDL::Ufunc::max($data),
                ci_95_lower => $avg - 1.96 * PDL::Stats::Basic::se($data),
                ci_95_upper => $avg + 1.96 * PDL::Stats::Basic::se($data),
               };
}

=head2 transform_chartlines ($chartlines, $options)

Gets an array of query results, each one from a different query
against the backend store, and returns a matrix for rendering those
chartlines, currently suited for the google charts api.

Multiple results for the same data X-axis are aggregated (default:
avg).

=over 4

=item INPUT:

  [ title: "dpath-T-n64",
    results: [
      {N:dpath, V:1000, version:2.0.13},
      {N:dpath, V:1170, version:2.0.14},
      {N:dpath,  V:660, version:2.0.15},
      {N:dpath, V:1030, version:2.0.16}
    ]
  ],
  [ title: "Mem-nT-n64",
    results: [
      {N:Mem,    V:400, version:2.0.13},
      {N:Mem,    V:460, version:2.0.14},
      {N:Mem,   V:1120, version:2.0.15},
      {N:Mem,    V:540, version:2.0.16}
    ]
  ],
  [ title: "Fib-T-64",
    results: [
      {N:Fib,    V:100, version:2.0.13},
      {N:Fib,    V:100, version:2.0.14},
      {N:Fib,    V:100, version:2.0.15},
      {N:Fib,    V:200, version:2.0.16}
    ]
  ]

=item OUTPUT:

   # multiple results for same version would become aggregated (avg), not show here
  ['version',   'dpath', 'Mem', 'Fib'],
  ['2.0.13',      1000,   400,   100],
  ['2.0.14',      1170,   460,   100],
  ['2.0.15',       660,  1120,   100],
  ['2.0.16',      1030,   540,   200]

=back

There are assumptions for the transformation:

=over 4

=item * there is only one NAME per chartline resultset

=item * titles are unique

=back

=cut

sub transform_chartlines
{
        my ($self, $chartlines, $options) = @_;

        my $x_key       = $options->{x_key};
        my $x_type      = $options->{x_type};
        my $y_key       = $options->{y_key};
        my $y_type      = $options->{y_type};
        my $aggregation = $options->{aggregation};
        my $verbose     = defined($options->{verbose}) ? $options->{verbose} : $self->{verbose};
        my $debug       = defined($options->{debug})   ? $options->{debug}   : $self->{debug};
        my $dropnull    = $options->{dropnull};

        # from all chartlines collect values into buckets for the dimensions we need
        #
        # chartline = title
        # x         = perlconfig_version
        # y         = VALUE
        my @titles;
        my %VALUES;
 CHARTLINE:
        foreach my $chartline (@$chartlines)
        {
                my $title     = $chartline->{title};
                my $results   = $chartline->{results};
                my $NAME      = $results->[0]{NAME};

                # skip typical empty results
                if (not @$results or (@$results == 1 and not $results->[0]{NAME}))
                {
                        say STDERR "benchmarkanything: transform_chartlines: ignore empty chartline '$title'" if $verbose;
                        next CHARTLINE;
                }
                push @titles, $title;

                say STDERR sprintf("* %-20s - %-40s", $title, $NAME) if $verbose;
                say STDERR "  VALUE_IDs: ".join(",", map {$_->{VALUE_ID}} @$results) if $debug;

        POINT:
                foreach my $point (@$results)
                {
                        my $x = $point->{$x_key};
                        my $y = $point->{$y_key};
                        if (not defined $x)
                        {
                                require Data::Dumper;
                                print STDERR "benchmarkanything: transform_chartlines: chartline '$title': ignore data point (missing key '$x_key'): ".Data::Dumper::Dumper($results) if $verbose;
                                next POINT;
                        }
                        push @{$VALUES{$title}{$x}{values}}, $y; # maybe multiple for same X - average them later
                }
        }

        # statistical aggregations of multi points
        foreach my $title (keys %VALUES)
        {
                foreach my $x (keys %{$VALUES{$title}})
                {
                        my $multi_point_values     = $VALUES{$title}{$x}{values};
                        $VALUES{$title}{$x}{stats} = $self->_multi_point_stats($multi_point_values);
                }
        }

        # find out all available x-values from all chartlines
        my %all_x;
        foreach my $title (keys %VALUES)
        {
                foreach my $x (keys %{$VALUES{$title}})
                {
                        $all_x{$x} = 1;
                }
        }
        my @all_x = keys %all_x;
        @all_x =
         $x_type eq 'version'    ? sort {version->parse($a) <=> version->parse($b)} @all_x
          : $x_type eq 'numeric' ? sort {$a <=> $b} @all_x
           : $x_type eq 'string' ? sort {$a cmp $b} @all_x
            : $x_type eq 'date'  ? sort { die "TODO: sort by date" ; $a cmp $b} @all_x
             : @all_x;

        # drop complete chartlines if it has gaps on versions that the other chartlines provide values
        my %clean_chartlines;
        if ($dropnull) {
                foreach my $title (keys %VALUES) {
                        my $ok = 1;
                        foreach my $x (@all_x) {
                                if (not @{$VALUES{$title}{$x}{values} || []}) {
                                        say STDERR "skip: $title (missing values for $x)" if $verbose;
                                        $ok = 0;
                                }
                        }
                        if ($ok) {
                                $clean_chartlines{$title} = 1;
                                say STDERR "okay: $title" if $verbose;
                        }
                }
        }

        # intermediate debug output
        foreach my $title (keys %VALUES)
        {
                foreach my $x (keys %{$VALUES{$title}})
                {
                        my $count = scalar @{$VALUES{$title}{$x}{values} || []} || 0;
                        next if not $count;
                        my $avg   = $VALUES{$title}{$x}{stats}{avg};
                        my $stdv  = $VALUES{$title}{$x}{stats}{stdv};
                        my $ci95l = $VALUES{$title}{$x}{stats}{ci_95_lower};
                        my $ci95u = $VALUES{$title}{$x}{stats}{ci_95_upper};
                        say STDERR sprintf("  %-20s . %-7s . (ci95l..avg..ci95u) = (%2.2f .. %2.2f .. %2.2f) +- stdv %5.2f (%3d points)", $title, $x, $ci95l, $avg, $ci95u, $stdv, $count) if $verbose;
                }
        }

        # result data structure, as needed per chart type
        my @RESULTMATRIX;

        @titles = grep { !$dropnull or $clean_chartlines{$_} } @titles; # dropnull

        for (my $i=0; $i<@all_x; $i++)          # rows
        {
                my $x = $all_x[$i];
                for (my $j=0; $j<@titles; $j++) # columns
                {
                        my $title = $titles[$j];
                        my $value = $VALUES{$title}{$x}{stats}{$aggregation};
                        # stringify to unbless from PDL, then numify for type-aware JSON
                        $value    = $value ? (0+sprintf("%6.2f", $value)) : undef;
                        $RESULTMATRIX[0]    [0]    = $x_key       if $i == 0 && $j == 0;
                        $RESULTMATRIX[0]    [$j+1] = $title       if $i == 0;
                        $RESULTMATRIX[$i+1] [0]    = $x           if            $j == 0;
                        $RESULTMATRIX[$i+1] [$j+1] = $value;
                }
        }
        return \@RESULTMATRIX;
}

1;
