#!/bin/sh
cd ~/egil/r1
rm -f metamod2.tar
tar cvf metamod2.tar metamod2
scp metamod2.tar dokipy@damocles.oslo.dnmi.no:~/metamod2.tar
rm -f metamod2.tar
echo "On dokipy@damocles.oslo.dnmi.no, do the following:"
echo " "
echo "rm -rf metamod2"
echo "tar xvf metamod2.tar"
echo "cd metamod2"
echo "./app/dokipy/install.sh"
