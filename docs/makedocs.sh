#!/bin/bash

podchecker *.pod
if [ $? != 0 ]
then
    echo "Error(s) in POD files: fix before regenerating HTML."
    exit $?
fi

mkdir -p html/upgrade
for f in *.pod upgrade/*.pod
do
    g=`echo $f|sed 's/\.pod//'`
    # update if pod file has been changed
    [ "$f" -nt "html/$g.html" ] && ./pod2html.pl $f > html/$g.html
done

cp ../CHANGES ../README ../LICENCE *.txt *.css html/
