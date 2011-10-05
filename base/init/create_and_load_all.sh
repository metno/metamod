#!/bin/bash

IMP=import
SCRIPT_PATH="`dirname \"$0\"`"
if [ $# -eq 1 ]
then
	CONFIG=$1
	source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" "--config" $CONFIG)
elif [ $# -eq 2 ]
then
    CONFIG=$1
    IMP=$2
    source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" "--config" $CONFIG)
else
    # assume that config is set in environment
    source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl")
    CONFIG=''
fi
PSQL=psql
CREATEDB=createdb
DROPDB=dropdb

#
# Re-initialize the data base, and load all static search data and datasets
#
#exec >create_and_load_all.out 2>&1
echo "------------ Reinitialize the database, create dynamic tables:"
. ./createdb.sh $CONFIG
echo ""
echo "------------ Importing searchdata:"
PERL5LIB=$PERL5LIB:/opt/metno-perl-webdev-ver1/lib/perl5

if [ $CONFIG ]; then
    ./import_searchdata.pl --config $CONFIG
else
    ./import_searchdata.pl
fi
echo "------------ Importing datasets:"
cat >t_1 <<EOF
$IMPORTDIRS
EOF
if [ $IMP != "noimport" ]; then
   for dir in `cat t_1`; do
   	  if [ $CONFIG ]; then
        ../scripts/import_dataset.pl --config $CONFIG $dir
   	  else
   	    ../scripts/import_dataset.pl $dir
      fi
   done
fi
rm t_1
