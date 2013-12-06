#!/usr/bin/perl

=head1 NAME

run_automatic_tests.pl - Run the automatic tests in the t/ directories

=head1 SYNOPSIS

run_automatic_tests.pl [options]

  Options:
    --smolder Send the test result to our Smolder server
    --verbose Run the tests with verbose output
    --coverage Turn on coverage reporting with Devel::Cover
    --perf Turn on performance testing
    --pod Turn on POD testing (default). Use --no-pod to turn of

=cut

use App::Prove;
use FindBin;
use Getopt::Long;
use Pod::Usage;

my $send_to_smolder = '';
my $send_to_jenkins = '';
my $verbose         = '';
my $coverage        = 1;
my $performance     = '';
my $pod             = 1;

GetOptions(
    'smolder'     => \$send_to_smolder,
    'jenkins'     => \$send_to_jenkins,
    'verbose'     => \$verbose,
    'coverage'    => \$coverage,
    'performance' => \$performance,
    'pod!'        => \$pod,
) or pod2usage(2);

if( !$pod ){
    $ENV{NO_TEST_POD} = 1;
}

if( !$performance ){
    $ENV{NO_PERF_TESTS} = 1;
}

my $output_file = $send_to_jenkins ? 'test_results' : 'auto_test_result.tar.gz';
mkdir $output_file if $send_to_jenkins && ! -d $output_file;

# run Devel::Cover to get some information about the test coverage
if ($coverage) {

    eval { require Devel::Cover; };

    if ($@) {
        print "Could not load Devel::Cover. Cannot run tests with coverage statistics\n";
        print "$@";
        exit 1;
    }

    $ENV{HARNESS_PERL_SWITCHES} = '-MDevel::Cover=-select,Metamod.*\.pm,Metno.*\.pm,+ignore,.*';
}

my $prove = App::Prove->new();

# setting lib using $prove->lib() does not work for some reason
$prove->process_args('-Ilocal/lib/perl5');

if ($verbose) {
    $prove->verbose(1);
}

$prove->recurse(1);
$prove->archive($output_file);
$prove->argv( [ "$FindBin::Bin/common/lib/t", "$FindBin::Bin/catalyst/t" ] );
my $result = $prove->run();

if ($send_to_smolder) { # should be configurable... FIXME
    system "$FindBin::Bin/test/smolder_smoke_signal.pl", '--server', 'dev-vm081', '--port', '8080', '--username',
        'admin', '--password',
        'qa_rocks', '--project', 'metamod', '--platform', $^O, '--file', $output_file;
}

exit( $result ? 0 : 1 );
