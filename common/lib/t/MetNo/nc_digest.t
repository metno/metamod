#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use FindBin;

use lib "$FindBin::Bin/../../";

my $num_tests = 0; 
use File::Path qw( make_path );
use Test::More;
use Test::Files;

use MetNo::NcDigest qw( digest );


my $out_dir = "$FindBin::Bin/xml_output/xml_output";
my $baseline_dir = "$FindBin::Bin/../data/MetNo"; # dir with the correct xml files

if( !( -e $out_dir ) ){
    make_path( $out_dir ) or die $!;
}
 
my $digest_file = "$FindBin::Bin/../data/MetNo/nc_files_to_digest.txt";

{
    my $file_to_test = "ecmwf_atmo0_5_2010-08-09_00.xml";
    my $baseline_file = "$baseline_dir/$file_to_test";
    my $out_file = "$out_dir/$file_to_test";

    #remove any previous version of the out file since the order of some values will be 
    # different in the second run
    unlink $out_file; 
    digest( "$FindBin::Bin/..", $digest_file, 'DAM', $out_file );        
    
    compare_ok( $baseline_file, $out_file, 'Parsing NC file' );               

    BEGIN { $num_tests += 1 }
}

BEGIN { plan tests => $num_tests };

