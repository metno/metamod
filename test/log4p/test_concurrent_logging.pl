#!/usr/bin/env perl

use strict;
use warnings;

=head1

Script for testing that several different Perl and PHP process that all acccess the same
log file using Log::Log4perl and log4php will not write garble each others output.

=cut

if( @ARGV != 2 ){
    print "Wrong number of arguments.\n";
    print "usage: test_concurrent_log.pl <num processes> <number of iterations per process>\n";
    exit 1;
}

my $num_processes = shift @ARGV;
my $num_iterations = shift @ARGV;

print "Starting subprocesses\n";

foreach ( 1 .. $num_processes ){

    my $pid = fork();
    if( 0 == $pid ){
        exec( './test_logger.pl', "Perl $_", $num_iterations ) or exit;
    }

    $pid = fork();
    if( 0 == $pid ){
        exec( './test_logger.php', "PHP $_", $num_iterations ) or exit;
    }

}

print "Done $$\n";