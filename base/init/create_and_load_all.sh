#!/bin/sh
PSQL=psql
CREATEDB=createdb
DROPDB=dropdb
#
# Re-initialize the data base, and load all static search data and datasets
#
exec >create_and_load_all.out 2>&1
echo "------------ Reinitialize the database, create dynamic tables:"
source createdb.sh
echo ""
echo "------------ Run cload scripts:"
cd ../staticdata
../scripts/import_searchdata.pl searchdata.xml
cat >t_1 <<EOF
[==IMPORTDIRS==]
EOF
for dir in `cat t_1`; do
   for fil in `ls -1 $dir/*.xm[ld]`; do
      ../scripts/import_dataset.pl $fil
   done
done
# for fil in `ls -1 datasets/*.xml`; do
#    ../scripts/import_dataset.pl $fil
# done
