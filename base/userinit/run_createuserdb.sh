#!/bin/bash
#
# Re-initialize the User database. NOTE: All existing data will be lost!
#

if [ $# != 1 ]
then
    echo "You must supply the master config file as a parameter"
    exit 1
fi

if [ ! -r $1 ]
then
    echo "Cannot read the file "$1
    exit 1
fi

exec >run_createuserdb.out 2>&1
echo "------------ Reinitialize the user database:"
. ./createuserdb.sh $1
