#!/bin/sh
#
# Re-initialize the User database. NOTE: All existing data will be lost!
#
exec >run_createuserdb.out 2>&1
echo "------------ Reinitialize the user database:"
. ./createuserdb.sh
