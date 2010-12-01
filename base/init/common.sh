#!/bin/sh

# called by database creation scripts

check () {
    # call this to check required config variables
    # if 2nd param, also use as file name and test for existenz
    eval val=$`echo $1`
    #echo "$1 = $val, $2"
    if [ -z "$val" ]
    then
        echo "Missing config variable $1"
        exit 1
    #else
    #    echo "Config variable $1 ok"
    fi
    if [ -n "$2" ] # also check if file exists
    then
        if [ ! -f "$val" ]
        then
            echo "Missing file $val"
            exit 1
        #else
        #    echo "File $val exists"
        fi
    fi
}

# init required config variables
DBNAME=[==DATABASE_NAME==]
PSQL=[==PSQL==]
CREATEDB=[==CREATEDB==]
DROPDB=[==DROPDB==]
PG_ADMIN_USER=[==PG_ADMIN_USER==]
PG_WEB_USER=[==PG_WEB_USER==]
PG_CONNECTSTRING_SHELL="[==PG_CONNECTSTRING_SHELL==]"
SRID_ID_COLUMNS="[==SRID_ID_COLUMNS==]"

check "DBNAME"
check "PSQL"
check "CREATEDB"
check "DROPDB"
check "PG_ADMIN_USER"
check "PG_WEB_USER"
check "SRID_ID_COLUMNS"
