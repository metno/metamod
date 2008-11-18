#!/bin/sh
#
#  Remove old installation:
#
rm -rf /metno/damocles/r1
rm  -f /metno/damocles/htdocs/r1
#
#  Correct links:
#
cd app/damocles
rm -f master_config.txt
ln -s ext.master_config.txt master_config.txt
cd ../..
#
#  Copy files to target:
#
./update_target.pl app/damocles
#
#  Link the application into the official htdocs tree:
#
ln -s /metno/damocles/r1/htdocs /metno/damocles/htdocs/r1
#
#  Set up .htaccess files:
#
cat >/metno/damocles/r1/htdocs/adm/.htaccess <<EOF
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
#  Initialise maps directory:
#
rm -rf /metno/damocles/webrun/maps
mkdir /metno/damocles/webrun/maps
cp /metno/damocles/r1/htdocs/img/orig.png /metno/damocles/webrun/maps
#
#  Set up link from the upl directory to the user error directory under webrun:
#
cd /metno/damocles/r1/htdocs/upl
ln -s /metno/damocles/webrun/upl/uerr
