#!/bin/sh
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
echo "------------ Run cload scripts:"
cd ../staticdata
../scripts/import_searchdata.pl searchdata.xml
cat >t_1 <<EOF
[==IMPORTDIRS==]
EOF
for dir in `cat t_1`; do
   ../scripts/import_dataset.pl $dir
done
rm t_1
