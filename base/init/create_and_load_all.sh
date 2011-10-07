#!/bin/bash

IMP=import
SCRIPT_PATH="`dirname \"$0\"`"
if [ $# -eq 1 ]
then
	CONFIG=$1
elif [ $# -eq 2 ]
then
    CONFIG=$1
    IMP=$2
else
    # assume that config is set in environment
    CONFIG=''
fi

SHELL_CONF=/tmp/metamod_tmp_bash_config.sh
perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" ${CONFIG:+"--config"} $CONFIG > $SHELL_CONF
source $SHELL_CONF
rm $SHELL_CONF

PSQL=psql
CREATEDB=createdb
DROPDB=dropdb

#
# Re-initialize the data base, and load all static search data and datasets
#
exec >create_and_load_all.out 2>&1
echo "------------ Reinitialize the database, create dynamic tables:"
. $SCRIPT_PATH/createdb.sh $CONFIG
echo ""
echo "------------ Importing searchdata:"
PERL5LIB=$PERL5LIB:/opt/metno-perl-webdev-ver1/lib/perl5

$SCRIPT_PATH/import_searchdata.pl ${CONFIG:+"--config"} $CONFIG

echo "------------ Importing datasets:"
cat >t_1 <<EOF
$IMPORTDIRS
EOF
if [ $IMP != "noimport" ]; then
    for dir in `cat t_1`; do
        $SCRIPT_PATH/../scripts/import_dataset.pl ${CONFIG:+"--config"} $CONFIG $dir
    done
fi
rm t_1
