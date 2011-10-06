#!/bin/bash
#
# Re-initialize the User database. NOTE: All existing data will be lost!
#
SCRIPT_PATH="`dirname \"$0\"`"

exec >run_createuserdb.out 2>&1
echo "------------ Reinitialize the user database:"
. $SCRIPT_PATH/createuserdb.sh $1
