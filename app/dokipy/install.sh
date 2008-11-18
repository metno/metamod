#!/bin/sh
#
#  Remove old installation:
#
rm -rf /metno/dokipy/r1
rm  -f /metno/dokipy/htdocs/r1
#
#  Correct links:
#
cd app/dokipy
rm -f master_config.txt
ln -s ext.master_config.txt master_config.txt
cd ../..
#
#  Copy files to target:
#
./update_target.pl app/dokipy
#
#  Link the application into the official htdocs tree:
#
ln -s /metno/dokipy/r1/htdocs /metno/dokipy/htdocs/r1
#
#  Initialize webrun directory:
#
cd /metno/dokipy
if [ ! -d webrun ]; then
   mkdir webrun
   chmod 777 webrun
fi
cd /metno/dokipy/webrun
for fil in damocleslogg dbg_log phplog testlog userlog; do
   if [ ! -f $fil ]; then
      >$fil
      chmod 666 $fil
   fi
done
#
#  Initialise maps directory:
#
rm -rf /metno/dokipy/webrun/maps
mkdir /metno/dokipy/webrun/maps
chmod 777 /metno/dokipy/webrun/maps
cd /metno/dokipy/r1/htdocs/sch
rm -rf maps
ln -s /metno/dokipy/webrun/maps
cp /metno/dokipy/r1/htdocs/img/orig.png /metno/dokipy/webrun/maps
