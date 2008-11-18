#!/bin/sh
cd ~/egil/m2
rm -f metamod2_r2.tar
rm -rf metamod2_r2
mkdir metamod2_r2
cd metamod2_r2
ln -s ../trunk/base
ln -s ../trunk/quest
ln -s ../trunk/README
ln -s ../trunk/search
ln -s ../trunk/update_target.pl
ln -s ../trunk/upload
ln -s ../trunk/pmh
mkdir app
cd app
ln -s ../../damocles
cd ~/egil/m2
tar cvfh metamod2_r2.tar metamod2_r2
rm -rf metamod2_r2
scp metamod2_r2.tar damocles@damocles.oslo.dnmi.no:~/metamod2_r2.tar
rm -f metamod2_r2.tar
echo "On damocles@damocles.oslo.dnmi.no, do the following:"
echo " "
echo "rm -rf metamod2_r2"
echo "tar xvf metamod2_r2.tar"
echo "cd metamod2_r2"
echo "./app/damocles/install_r2.sh"
