#!/bin/bash
#
# Re-initialize the User database. NOTE: All existing data will be lost!
#

cd `dirname $0`
SCRIPT_PATH=`pwd`
# the problem with this is that relative path arguments (e.g. "prepare_runtime_env.sh .") no longer work
# so we must make sure to change back afterwards
cd -

if [ $# -eq 1 ]; then
    CONFIG=`readlink -f $1`
elif [ ! -z "$METAMOD_MASTER_CONFIG" ]; then
    CONFIG=`readlink -f $METAMOD_MASTER_CONFIG`
    if [ -f $CONFIG ]; then
        # get parent dir
        CONFIG=`dirname $CONFIG`
    fi
else
    echo "Usage: $0 Path_to_config_directory\n"
    exit
fi
#cd $CONFIG # why?

SHELL_CONF=/tmp/metamod_tmp_bash_config.sh
PERLCONF="$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl"
echo Running $PERLCONF
perl $PERLCONF ${CONFIG:+"--config"} $CONFIG > $SHELL_CONF
source $SHELL_CONF
rm $SHELL_CONF

# we should better let jenkins take care of the logs so they will be stored for each build

# put log in webrun since test/applic could be non-writeable
OUTPUT="$WEBRUN_DIRECTORY/run_createuserdb.out"
echo "Writing output to $OUTPUT"
exec >$OUTPUT 2>&1

echo "------------ Reinitialize the user database:"
# createuserdb.sh must be run and not sourced otherwise paths will be screwed up
$SCRIPT_PATH/createuserdb.sh $CONFIG

if [ $? -ne 0 ]; then
    # doesn't seem to work...
    echo "createuserdb error $?"
    exit $?
fi
