#!/bin/sh

# Script for upgrading metabase from METAMOD 2.8 to 2.9.

COMMON="[==TARGET_DIRECTORY==]/init/common.sh"

if [ -e  $COMMON ]
then
    . "$COMMON"
else
    echo "Library $COMMON not found."
    exit 1
fi

METABASE_NAME=[==METABASE_NAME==]
check "METABASE_NAME"

$PSQL -a -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] -d $METABASE_NAME <<'EOF'

-- remove all the Quadtree related tables.
DROP TABLE ga_contains_gd;

DROP TABLE ga_describes_ds;

DROP TABLE geographicalarea;

-- remove the session table since it is no longer in use
DROP TABLE sessions;

\q
EOF
