#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Metamod::Config;

my $config_file = shift @ARGV;

if( !Metamod::Config->config_found($config_file)){
    print "Path to config must either be supplied on the commandline or given in the environment.";
    print "usage: $0 [config file]\n";
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
    mkdir File::Spec->catfile($config->get('CONFIG_DIR'), 'etc', 'init.d');
}

open my $NEW_INITD, '>', $initd_output or die $!;
print $NEW_INITD $generated_initd;
close $NEW_INITD;

if( ! -e File::Spec->catfile($config->get('CONFIG_DIR'), 'etc', 'default' ) ){
    mkdir File::Spec->catfile($config->get('CONFIG_DIR'), 'etc', 'default');
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
