#!/bin/bash

mkdir -p html/upgrade
for f in *.pod upgrade/*.pod
do
    g=`echo $f|sed 's/\.pod//'`
    # update if pod file has been changed
    ls -l "$f"
    ls -l "html/$g.html"
    [ "$f" -nt "html/$g.html" ] && ./pod2html.pl $f > html/$g.html
done

cp ../CHANGES ../README ../LICENCE *.txt *.css html/
