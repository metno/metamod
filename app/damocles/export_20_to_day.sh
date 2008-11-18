#!/bin/sh
cd ~/egil/m2
rm -f metamod2.tar
rm -rf metamod2
mkdir metamod2
cd metamod2
ln -s ../2.0/base
ln -s ../2.0/quest
ln -s ../2.0/README
ln -s ../2.0/search
ln -s ../2.0/update_target.pl
ln -s ../2.0/upload
mkdir app
cd app
ln -s ../../damocles
cd ~/egil/m2
tar cvfh metamod2.tar metamod2
rm -rf metamod2
scp metamod2.tar damocles@damocles.oslo.dnmi.no:~/metamod2.tar
rm -f metamod2.tar
echo "On damocles@damocles.oslo.dnmi.no, do the following:"
echo " "
echo "rm -rf metamod2"
echo "tar xvf metamod2.tar"
echo "cd metamod2"
echo "./app/damocles/install.sh"
