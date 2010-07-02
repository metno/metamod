#!/usr/bin/env perl

use strict;
use warnings;

=pod

Script for checking if a log file has be garbled or not.

=cut

open my $LOG_FILE, '<', 'test.log' or die $!;

my $num_errors = 0;
my $line_num = 1;
while( <$LOG_FILE> ){

    if( !/^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d,\d\d\d\s\[INFO\].*\d+$/ ){
        print "Error found on line $line_num: $_";
        $num_errors++;
    }

    $line_num++;
}

if( 0 == $num_errors ) {
    print "Found no lines that looked garbled. The test is successfull\n"
} else {
    print "Found $num_errors lines that looked garbled. The test failed.\n"
}