#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"
CONFIG=$1
# config must be set in $METAMOD_MASTER_CONFIG envvar if not given as command line param
source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" ${CONFIG:+"--config"} $CONFIG)

createuser --adduser --createdb $PG_ADMIN_USER
createuser --no-adduser --no-createdb $PG_WEB_USER
