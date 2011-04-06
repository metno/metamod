#!/usr/bin/env perl

=head1 NAME

B<find_used_conf_vars.pl> - Search program files to determine which configuration variables are actually used.

=head1 DESCRIPTION

Search through a list of directories and look for patterns that resemble the
use of METAMOD configuration variables.

=head1 USAGE

    find_used_conf_vars [options] dir1 dir2 .. dirN

=head2 OPTIONS

=over

=item short

Give a short report that only lists the found variables, not the file and line number where it was found.

=item as-config

Print the result in a format that is compatible with a METAMOD master_config.txt file. Useful for comparing
a master_config file with a what variables are actually used.

=back

=cut

use strict;
use warnings;


use File::Find;
use Getopt::Long;
use Pod::Usage;

my $short_report = 0;
my $as_config = 0;

GetOptions("short" => \$short_report, "as-config" => \$as_config ) or pod2usage(1);

if( 0 == @ARGV ){
    pod2usage(1);
}

my %config_vars = ();

find({ wanted => \&wanted, no_chdir => 1 }, @ARGV);
print_report();

sub wanted {

    my $variable_pattern;
    if( /\.(pm|pl|t|tt)$/ ) {
        $variable_pattern = qr/get\( \s* ["'] ([ABCDEFGHIJKLMNOPQRSTUVWXYZ_]*?) ["'] \s* \)/x;
    } elsif( /(\.sh)|(catalyst-myapp)|(metamod-catalyst)$/ ) {
        $variable_pattern = qr/.*\[==(.*)==\].*/;
    } elsif( $File::Find::name =~ /pmh/ && $_ =~ /\.(php)|(inc)$/ ) {
        $variable_pattern = qr/getVar\( \s* ["'] ([ABCDEFGHIJKLMNOPQRSTUVWXYZ_]*?) ["'] \s* \)/x;
    } else {
        return;
    }

    open my $FILE, '<', $File::Find::name or die $!;

    my $line_num = 1;
    while( my $line = <$FILE> ){

        # allow the use of more than one config variable per line
        while( $line =~ /$variable_pattern/g ){
            add_variable_use($1, $File::Find::name, $line_num)
        }

        $line_num++;
    }
}


sub print_report {

    print "Found the following variables:\n" if !$as_config;
    my @sorted_variables = sort { lc($a) cmp lc($b) } keys %config_vars;
    foreach my $variable ( @sorted_variables ){
        my $usages = $config_vars{$variable};

        if( $as_config ){
            print "$variable = \n";
        } else {
            print "$variable\n";
        }


        if( !$short_report && !$as_config ){
            foreach my $usage (@$usages){
                print "    $usage->[0]: $usage->[1]\n";
            }
        }
    }

}


sub add_variable_use {
    my ($variable, $filename, $line_num) = @_;

    if( !exists $config_vars{$variable}){
        $config_vars{$variable} = [];
    }

    push @{ $config_vars{$variable} }, [ $filename, $line_num ];

}

=head1 LICENSE

Copyright (C) 2011 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
