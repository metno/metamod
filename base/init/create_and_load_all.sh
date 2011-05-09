#!/bin/sh

IMP=import
if [ $# -eq 1 ]; then
   IMP=$1
fi
PSQL=psql
CREATEDB=createdb
DROPDB=dropdb

#
# Re-initialize the data base, and load all static search data and datasets
#
exec >create_and_load_all.out 2>&1
echo "------------ Reinitialize the database, create dynamic tables:"
. ./createdb.sh
echo ""
echo "------------ Importing searchdata:"
./import_searchdata.pl ../staticdata/searchdata.xml
echo "------------ Importing datasets:"
cat >t_1 <<EOF
[==IMPORTDIRS==]
EOF
if [ $IMP != "noimport" ]; then
   for dir in `cat t_1`; do
      ../scripts/import_dataset.pl $dir
   done
fi
rm t_1
