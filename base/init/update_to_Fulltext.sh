#!/bin/sh
exec >update_to_Fulltext.out 2>&1
DBNAME=[==DATABASE_NAME==]
PSQL=[==PSQL==]
$PSQL -a -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] -d $DBNAME < [==PG_TSEARCH2_SCRIPT==]
$PSQL -a -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] -d $DBNAME < [==INSTALLATION_DIR==]/base/init/update2.2To2.3.sql

# this is presumably not in use since not in svn?
#[==INSTALLATION_DIR==]/base/scripts/makeDatabaseFulltextAware_2.2-2.3.pl
