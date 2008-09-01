#!/bin/sh
set -e
sed '1,$s/\r$//' $1 >t_1
rm $1
mv t_1 $1
