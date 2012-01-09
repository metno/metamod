#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

gen_initd_script.pl Generate instance specific Catalyst init.d scripts and default file.

=head1 DESCRIPTION

This script generates a instance specific Catalyst init.d file and default file
based on a template and the application configuration.

=head1 SYNOPSIS

gen_initd_script.pl [options]

  Options:
    --config Path to application directory or application config file.

=cut

use FindBin;
use lib "$FindBin::Bin/../lib";

use File::Path qw(make_path);
use Getopt::Long;
use Pod::Usage;

use Metamod::Config;

my $config_file;
GetOptions('config=s' => \$config_file) or pod2usage(1);

if( !Metamod::Config->config_found($config_file)){
    print "Path to config must either be supplied on the commandline or given in the environment.";
    print "usage: $0 [--config config file]\n";
}

my $config = Metamod::Config->new($config_file);

my $initd_file = File::Spec->catfile($config->get('INSTALLATION_DIR'), 'common', 'etc', 'init.d', 'metamod-catalyst' );
my $default_file = File::Spec->catfile($config->get('INSTALLATION_DIR'), 'common', 'etc', 'default', 'catalyst-myapp' );

open my $INITD, '<', $initd_file or die $!;
my $initd_content = do { local $/, <$INITD> };
my $generated_initd = replace_config_vars($initd_content);
close $INITD;

open my $DEFAULT, '<', $default_file or die $!;
my $default_content = do { local $/, <$DEFAULT> };
my $generated_default = replace_config_vars($default_content);
close $DEFAULT;

my $applicaiton_id = $config->get('APPLICATION_ID');
my $initd_output = File::Spec->catfile($config->get('CONFIG_DIR'), 'etc', 'init.d', "catalyst-$applicaiton_id" );
my $default_output = File::Spec->catfile($config->get('CONFIG_DIR') ,'etc', 'default', "catalyst-$applicaiton_id" );

if( ! -e File::Spec->catfile($config->get('CONFIG_DIR'), 'etc', 'init.d' ) ){
    make_path(File::Spec->catfile($config->get('CONFIG_DIR'), 'etc', 'init.d')) or die "Failed to create init.d directory";
}

open my $NEW_INITD, '>', $initd_output or die $!;
print $NEW_INITD $generated_initd;
close $NEW_INITD;

if( ! -e File::Spec->catfile($config->get('CONFIG_DIR'), 'etc', 'default' ) ){
    make_path(File::Spec->catfile($config->get('CONFIG_DIR'), 'etc', 'default')) or die "Failed to create default directory";
}

open my $NEW_DEFAULT, '>', $default_output or die $!;
print $NEW_DEFAULT $generated_default;
close $NEW_DEFAULT;

sub replace_config_vars {
    my ($file_content) = @_;

    my %used_variables = ();
    while( $file_content =~ /\[==([A-Z0-9_]+)==\]/g ){

        my $value = $config->get($1);

        die "No value found in config for '$1'" if !$value;

        $used_variables{$1} = $value;
    }

    my $generated_file = $file_content;
    while( my ($variable, $value) = each %used_variables ){
        $generated_file =~ s/\[==$variable==\]/$value/g;
    }

    return $generated_file;
}
