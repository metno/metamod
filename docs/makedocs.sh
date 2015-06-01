#!/bin/bash

while getopts ":av" opt; do
  case $opt in
    a)
      echo "Rebuilding complete docs" >&2
      all=1
      ;;
    v)
      verbose="-v"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

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
    [ "$all" -o "$f" -nt "html/$g.html" ] && ./pod2html.pl $verbose $f > html/$g.html
done

cp ../CHANGES ../README ../LICENCE *.txt *.css html/
