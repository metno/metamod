#!/bin/bash
#
# Re-initialize the User database. NOTE: All existing data will be lost!
#
cd `dirname $0`
SCRIPT_PATH=`pwd`

if [ $# -eq 1 ]; then
    CONFIG=`readlink -f $1`
elif [ ! -z "$METAMOD_MASTER_CONFIG" ]; then
    CONFIG=`readlink -f $METAMOD_MASTER_CONFIG`
    CONFIG=`dirname $CONFIG`
else
    echo "Usage: $0 Path_to_config_directory\n"
    exit
fi
cd $CONFIG

exec >run_createuserdb.out 2>&1
echo "------------ Reinitialize the user database:"
. $SCRIPT_PATH/createuserdb.sh $CONFIG
