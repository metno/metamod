#!/bin/bash

IMP=import
if [ $# -eq 1 ]
then
	CONFIG_DIR=$1
elif [ $# -eq 2 ]
then
    CONFIG_DIR=$1
    IMP=$2
else
    echo "usage $0 <config dir> [import|no-import]"
    exit 1
fi
PSQL=psql
CREATEDB=createdb
DROPDB=dropdb

# Load the configuration dynamically
SCRIPT_PATH="`dirname \"$0\"`"
source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" "$1/master_config.txt")

#
# Re-initialize the data base, and load all static search data and datasets
#
exec >create_and_load_all.out 2>&1
echo "------------ Reinitialize the database, create dynamic tables:"
. ./createdb.sh $CONFIG_DIR
echo ""
echo "------------ Importing searchdata:"
PERL5LIB=$PERL5LIB:/opt/metno-perl-webdev-ver1/lib/perl5
./import_searchdata.pl $CONFIG_DIR

echo "------------ Importing datasets:"
cat >t_1 <<EOF
$IMPORTDIRS
EOF
if [ $IMP != "noimport" ]; then
   for dir in `cat t_1`; do
      ../scripts/import_dataset.pl $CONFIG_DIR $dir
   done
fi
rm t_1
