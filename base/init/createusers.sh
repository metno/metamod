#!/bin/bash

if [ $# != 1 ]
then
    echo "You must supply the config directory as a parameter"
    exit 1
fi

if [ ! -d $1 ]
then
    echo "The commandline parameter should be a directory"
    exit 1
fi

# Load the configuration dynamically
SCRIPT_PATH="`dirname \"$0\"`"
source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" $1)

createuser --adduser --createdb $PG_ADMIN_USER
createuser --no-adduser --no-createdb $PG_WEB_USER
