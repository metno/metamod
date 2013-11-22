#!/bin/sh

# die on command failure
set -e

ok () {
    if [ $? != 0 ]
    then
        echo "FAIL - $*" 1>&2
        exit $?
    else
        echo "OK - $* passed"
    fi
}

cd `dirname $0`
SCRIPT_PATH=`pwd` # ./test catalog
cd -

export METAMOD_MASTER_CONFIG=`readlink -f $SCRIPT_PATH/applic`
echo "config is $METAMOD_MASTER_CONFIG"

#

echo Setting up test environment...

./common/prepare_runtime_env.sh
ok "prepare_runtime_env"

./base/init/createusers.sh
ok "createusers"

./base/init/create_and_load_all.sh
ok "create_and_load_all"

./base/userinit/run_createuserdb.sh
ok "run_createuserdb"

./upload/scripts/userbase_add_datasets.pl --operator <./test/directories
ok "userbase_add_datasets"

# Run the automatic test suite
# might add --smolder if we feel like continued use
perl ./run_automatic_tests.pl --no-pod --jenkins
ok "run_automatic_tests"


exit

# END - DOCUMENTATION FOLLOWS
: <<=cut

=pod

=head1 NAME

short_test_application.sh - METAMOD integration test designed to run under Jenkins (or similar)

=head1 SYNOPSIS

...

=head1 DESCRIPTION

...

=head1 CONFIGURATION

Jenkins must be set up with the following envvars:

    PERL5LIB=$WORKSPACE/metamod/local/lib/perl5
    METAMOD_MASTER_CONFIG=$WORKSPACE/metamod/test/applic

Make sure to avoid trailing slashes which may cause problems.

=head1 CAVEATS

This script is designed to run only with the test configuration in ./test/master_config.txt.

This script does not duplicate any functionality already in Jenkins or otherwise not needed
by such, including:

=over 4

=item Subversion checkout

=item copying of config files

=item installation of system services

Catalyst only runs on Starman/port 3000. Other daemons as needed (todo).

=item redirecting to multiple log files (todo)

We should collect all output to Jenkins so it is stored for each build

=item communication with external services

OAI-PMH harvesting/webservice is simulated.

=item reporting the test output logs



=head1 SEE ALSO

...

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

No rights Reserved

=cut
