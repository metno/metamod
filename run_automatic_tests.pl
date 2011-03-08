#!/usr/bin/perl

=head1 NAME

run_automatic_tests.pl - Run the automatic tests in the t/ directories

=head1 SYNOPSIS

run_automatic_tests.pl [options]

  Options:
    --smolder Send the test result to our Smolder server
    --verbose Run the tests with verbose output
    --coverage Turn on coverage reporting with Devel::Cover

=cut

use App::Prove;
use FindBin;
use Getopt::Long;
use Pod::Usage;

my $send_to_smolder = '';
my $verbose = '';
my $coverage = '';

GetOptions('smolder' => \$send_to_smolder, 'verbose' => \$verbose, 'coverage' => \$coverage ) or pod2usage(1);

# we want to test post as well.
$ENV{TEST_POD} = 1;

my $output_file = 'auto_test_result.tar.gz';

# run Devel::Cover to get some information about the test coverage
if($coverage){

    eval { require Devel::Cover; };

    if($@){
        print "Could not load Devel::Cover. Cannot run tests with coverage statistics\n";
        print "$@";
        exit 1;
    }

    $ENV{HARNESS_PERL_SWITCHES} = '-MDevel::Cover=-select,Metamod.*\.pm,Metno.*\.pm,+ignore,.*';
}

my $prove = App::Prove->new();

# setting lib using $prove->lib() does not work for some reason
$prove->process_args('-I/opt/metno-perl-webdev-ver1/lib/perl5');

if($verbose){
    $prove->verbose(1);
}

$prove->recurse(1);
$prove->archive($output_file);
$prove->argv( [ "$FindBin::Bin/common/lib/t", "$FindBin::Bin/catalyst/t" ] );
$prove->run();

if( $send_to_smolder ){
    system 'smolder_smoke_signal', '--server', 'dev-vm081', '--port', '8080', '--username', 'admin', '--password',
        'qa_rocks', '--project', 'metamod', '--platform', $^O, '--file', $output_file;
}
