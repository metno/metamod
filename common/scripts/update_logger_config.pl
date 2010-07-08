#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;

# Basing lib on $FindBin::Bin works since this script is never copied to target
use lib "$FindBin::Bin/..lib";

use Data::Dumper;
use FindBin;
use File::Copy;
use File::Spec;
use Getopt::Long;
use Pod::Usage;

use Metamod::Config;
use Metamod::LoggerConfigParser;

my @config_files       = ();
my $use_default_config = 1;
my $move_to_target     = 0;
my $verbose            = 0;
my $metamod_config;
my $dryrun       = 0;
my $perl_outfile = 'log4perl_config.ini';
my $php_outfile  = 'log4php_config.ini';

GetOptions(
    'help|?'    => \&print_usage,
    'config_file=s'      => \@config_files,
    'use_default_config!' => \$use_default_config,
    'move_to_target'     => \$move_to_target,
    'verbose|v'            => \$verbose,
    'metamod_config=s'   => \$metamod_config,
    'dry-run'            => \$dryrun,
    'perl_logger_config' => \$perl_outfile,
    'php_logger_config'  => \$php_outfile,
    ''
) or print_usage();

if( $use_default_config ){
    unshift @config_files,  "$FindBin::Bin/../logger-config.ini";
}

if ( !$metamod_config && $move_to_target ) {
    print "Cannot move files to target without specifying options 'metamod_config' also\n";
    exit 1;
}

my $lcp = Metamod::LoggerConfigParser->new( { verbose => $verbose } );

my $config_string = $lcp->read_meta_files(@config_files);

my $perl_config = $lcp->create_perl_config($config_string);
if ( !$dryrun ) {
    open my $CONFIG_FILE, '>', $perl_outfile or die "Could not open '$perl_outfile': $!";
    print $CONFIG_FILE $perl_config;
}

my $php_config = $lcp->create_php_config($config_string);
if ( !$dryrun ) {
    open my $CONFIG_FILE, '>', $php_outfile or die "Could not open '$php_outfile': $!";
    print $CONFIG_FILE $php_config;
}

if ($move_to_target) {

    my $mm_config  = Metamod::Config->new($metamod_config);

    my $perl_config_path = $mm_config->get("LOG4PERL_CONFIG");

    print "Moving the Perl logger configuration to '$perl_config_path'" if $verbose;
    if ( !$dryrun ) {
        move( $perl_outfile, $perl_config_path );
    }

    my $php_config_path = $mm_config->get("LOG4PHP_CONFIG");

    print "Moving the PHP logger configuration to '$php_config_path'" if $verbose;
    if ( !$dryrun ) {
        move( $php_outfile, $php_config_path );
    }

}


sub print_usage {
    pod2usage(1);
}

=head1 NAME

update_logger_config.pl - Script for updating the log4php and log4perl configuration files

=head1 SYNOPSIS

update_logger_config.pl [options]

 Options:
    -? --help                 Print this message and exit
    --config_file=F           Read additional configurations from F. Multiple uses of this parameter is allowed
    --nouse_default_config    Turn off the use of the default configuration file.
    --move_to_target          Move generated files to target specified in master_config.txt. Overwrites existing files
    -v --verbose              Turn on and off output
    --metamod_config=F        Path to the METAMOD master_config.txt
    --dry-run                 Don't create or move any files
    --perl_logger_config=F    Name of the Perl logger config file. Default is 'log4perl_config.ini'
    --php_logger_config=F     Name of the PHP logger config file. Default is 'log4php_config.ini'

=head1 DESCRIPTION

The C<update_logger_config.pl> script is used to take one or more "meta" log4p configuration files
and create specific configuration files for log4perl and log4php.

The script can also move the generated files to a target installation if that is wanted.

=cut
