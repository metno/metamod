#!/bin/sh
#
#  Remove old installation:
#
rm -rf /metno/damocles/r2
rm  -f /metno/damocles/htdocs/r2
#
#  Correct links:
#
cd app/damocles
rm -f master_config.txt
ln -s ext_r2.master_config.txt master_config.txt
cd ../..
#
#  Copy files to target:
#
./update_target.pl app/damocles
#
#  Link the application into the official htdocs tree:
#
ln -s /metno/damocles/r2/htdocs /metno/damocles/htdocs/r2
#
#  Set up .htaccess files:
#
cat >/metno/damocles/r2/htdocs/adm/.htaccess <<EOF
AuthType Basic
AuthName "Password Required"
AuthUserFile /metno/damocles/damoclespw
Require user damocles
Order Deny,Allow
Deny from all
Allow from dnmi.no
Satisfy all
EOF
#
#  Initialise webrun directory:
#
mkdir -p /metno/damocles/webrun_r2
if [ -d /metno/damocles/r2/htdocs/sch ]; then
#
#  Initialise maps directory:
#
   rm -rf /metno/damocles/webrun_r2/maps
   mkdir /metno/damocles/webrun_r2/maps
   cp /metno/damocles/r2/htdocs/img/orig.png /metno/damocles/webrun_r2/maps
fi
