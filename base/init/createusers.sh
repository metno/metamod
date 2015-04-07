#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"
CONFIG=$1
# config must be set in $METAMOD_MASTER_CONFIG envvar if not given as command line param
SHELL_CONF=/tmp/metamod_tmp_bash_config.sh
perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" ${CONFIG:+"--config"} $CONFIG > $SHELL_CONF
source $SHELL_CONF
rm $SHELL_CONF

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

# must not die on fail as happens when user already exists

echo "Creating admin user $PG_ADMIN_USER"
createuser -e --username=postgres --adduser --createrole --createdb --superuser $PG_ADMIN_USER
#ordie "Couldn't create user $PG_ADMIN_USER"

# also find a way to set passwd
# postgres=# alter user admin with password 'admin';

echo "Creating web user $PG_WEB_USER"
createuser -e --username=postgres --no-adduser --no-createrole --no-createdb $PG_WEB_USER
#ordie "Couldn't create user $PG_WEB_USER"
