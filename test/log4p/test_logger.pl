#!/usr/bin/env perl

use strict;
use warnings;

=pod

Script used for testing writing to log file using Log::Log4perl. This script is used by
test_concurrent_logging.pl

=cut

use Log::Log4perl qw( get_logger );
use Time::HiRes qw( sleep );

Log::Log4perl->init( 'log4perl-test-config.ini' );

if( 2 != @ARGV ){
    print "Received wrong number of arguments\n";
    exit 1;
}

my $process_name = shift @ARGV;
my $num_iterations = shift @ARGV;

my $logger = get_logger( 'test' );

print "Starting process $process_name\n";
$logger->info( "Staring process $process_name" );

foreach ( 1 .. $num_iterations ){
    $logger->info( "Now at interation $_ in process $process_name" );
    sleep( rand() );
}

$logger->info( "Ending process $process_name" );
print "Ending process $process_name\n";

exit;