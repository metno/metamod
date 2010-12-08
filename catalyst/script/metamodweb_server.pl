#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../common/lib";
use lib "$FindBin::Bin/../../lib";

use MetamodWeb::Utils::GenCatalystConf;

BEGIN {
    $ENV{CATALYST_SCRIPT_GEN} = 40;

    if( !exists $ENV{METAMOD_MASTER_CONFIG } ){
        $ENV{METAMOD_MASTER_CONFIG} = "$FindBin::Bin/../master_config.txt";
    }
    my $conffile = "$FindBin::Bin/../metamodweb.json";
    open CF, ">$conffile" or die "Can't open $conffile for output";
    print CF MetamodWeb::Utils::GenCatalystConf::catalyst_conf;
    close CF;
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('MetamodWeb', 'Server');

1;

=head1 NAME

metamod_server.pl - Catalyst Test Server

=head1 SYNOPSIS

metamod_server.pl [options]

   -d --debug           force debug mode
   -f --fork            handle each request in a new process
                        (defaults to false)
   -? --help            display this help and exits
   -h --host            host (defaults to all)
   -p --port            port (defaults to 3000)
   -k --keepalive       enable keep-alive connections
   -r --restart         restart when files get modified
                        (defaults to false)
   -rd --restart_delay  delay between file checks
                        (ignored if you have Linux::Inotify2 installed)
   -rr --restart_regex  regex match files that trigger
                        a restart when modified
                        (defaults to '\.yml$|\.yaml$|\.conf|\.pm$')
   --restart_directory  the directory to search for
                        modified files, can be set mulitple times
                        (defaults to '[SCRIPT_DIR]/..')
   --follow_symlinks    follow symlinks in search directories
                        (defaults to false. this is a no-op on Win32)
   --background         run the process in the background
   --pidfile            specify filename for pid file

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst Testserver for this application.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
