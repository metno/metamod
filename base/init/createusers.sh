#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"
if [ $# != 1 ]
then
    # assume config set in env
    source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl")
else
    source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" "--config" $1)
fi

createuser --adduser --createdb $PG_ADMIN_USER
createuser --no-adduser --no-createdb $PG_WEB_USER
