#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"
CONFIG=$1
# config must be set in $METAMOD_MASTER_CONFIG envvar if not given as command line param
source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" ${CONFIG:+"--config"} $CONFIG)

COMMON="$SCRIPT_PATH/common.sh"

if [ -e  $COMMON ]
then
    . "$COMMON"
else
        echo "Library $COMMON not found."
        exit 1
fi

check "PG_ADMIN_USER"
check "PG_WEB_USER"

echo "Creating admin user $PG_ADMIN_USER"
createuser --adduser --createdb $PG_ADMIN_USER
echo "Creating web user $PG_WEB_USER"
createuser --no-adduser --no-createdb $PG_WEB_USER
