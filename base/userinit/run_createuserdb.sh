#!/bin/sh
#
# Re-initialize the data base, and load all static search data and datasets
#
exec >run_createuserdb.out 2>&1
echo "------------ Reinitialize the user database:"
. ./createuserdb.sh
