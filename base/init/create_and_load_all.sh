#!/bin/bash

IMP=import
#echo Changing to `dirname $0`
cd `dirname $0`
SCRIPT_PATH=`pwd`
#echo SCRIPT_PATH=\"$SCRIPT_PATH\"
# the problem with this is that relative path arguments (e.g. "prepare_runtime_env.sh .") no longer work
# so we must make sure to change back afterwards
cd -

if [ $# -eq 1 ]
then
    CONFIG=$1
elif [ $# -eq 2 ]
then
    CONFIG=$1
    IMP=$2
elif [ ! -z "$METAMOD_MASTER_CONFIG" ]
then
    CONFIG=`readlink -f $METAMOD_MASTER_CONFIG`
    if [ -f $CONFIG ]; then
        # get parent dir
        CONFIG=`dirname $CONFIG`
    fi
else
    echo ""
    echo "Usage: $0 Path_to_config_directory                         or"
    echo "       $0 Path_to_config_directory noimport"
    echo ""
    exit
fi

cd $CONFIG

SHELL_CONF=/tmp/metamod_tmp_bash_config.sh
PERLCONF="$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl"
echo Running $PERLCONF
perl $PERLCONF ${CONFIG:+"--config"} $CONFIG > $SHELL_CONF
source $SHELL_CONF
rm $SHELL_CONF

# why are these redefined here when they are already set in master_config? FIXME
#PSQL=psql
#CREATEDB=createdb
#DROPDB=dropdb

#
# Re-initialize the data base, and load all static search data and datasets
#

# we should better let jenkins take care of the logs so they will be stored for each build
OUTPUT="$WEBRUN_DIRECTORY/create_and_load_all.out"
echo "Writing output to $OUTPUT"
exec 3>&1 4>&2 >$OUTPUT 2>&1
echo "------------ Reinitialize the database, create dynamic tables:"
# createdb must be run and not sourced otherwise paths will be screwed up
if $SCRIPT_PATH/createdb.sh $CONFIG
then
    echo "createdb OK - exit $?" >&4
else
    # doesn't seem to work...
    echo "createdb failed! Check log for details" >&4
    exit 1
fi

echo ""
echo "------------ Importing searchdata:"
#PERL5LIB=$PERL5LIB:/opt/metno-perl-webdev-ver1/lib/perl5

if ! $SCRIPT_PATH/import_searchdata.pl ${CONFIG:+"--config"} $CONFIG
then
    echo "import_searchdata failed! Check log for details" >&4
    exit 1
fi

echo "------------ Importing datasets:"
cat >t_1 <<EOF
$IMPORTDIRS
EOF
if [ $IMP != "noimport" ]; then
    for dir in `cat t_1`; do
        echo " Importing $dir"
        $SCRIPT_PATH/../scripts/import_dataset.pl --verbose ${CONFIG:+"--config"} $CONFIG $dir
    done
fi
rm t_1
