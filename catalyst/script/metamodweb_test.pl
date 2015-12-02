#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../common/lib";
use lib "$FindBin::Bin/../../lib";

use Getopt::Long qw(:config pass_through);
use Metamod::Config;

$ENV{CATALYST_SCRIPT_GEN} = 40;

my $config_file_or_dir;
GetOptions("config=s", \$config_file_or_dir);

if( !Metamod::Config->config_found($config_file_or_dir)){
    print "You must supply either the config parameter or set the METAMOD_MASTER_CONFIG environment variable\n";
    exit 1;
}


Metamod::Config->new($config_file_or_dir);

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('MetamodWeb', 'Test');

1;

=head1 NAME

metamodweb_test.pl - Catalyst Test

=head1 SYNOPSIS

metamodweb_test.pl [options] uri

 Options:
   --help    display this help and exits

 Examples:
   metamodweb_test.pl http://localhost/some_action
   metamodweb_test.pl /some_action

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst action from the command line.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
