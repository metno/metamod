#!/bin/bash

mkdir -p html/upgrade
for f in *.pod upgrade/*.pod
do
    g=`echo $f|sed 's/\.pod//'`
    ./pod2html.pl $f > html/$g.html
done

cp ../CHANGES ../README ../LICENCE *.txt *.css html/
