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
cd $CONFIG

# put log somewhere writable since test/applic might be locked
exec > $WEBRUN_DIRECTORY/run_createuserdb.out 2>&1
echo "------------ Reinitialize the user database:"
#. $SCRIPT_PATH/createuserdb.sh $CONFIG # why is this file sourced instead of run normally?
$SCRIPT_PATH/createuserdb.sh $CONFIG
