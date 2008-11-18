#!/bin/sh
cd ~/egil/m2/damocles
rm -f master_config.txt
ln -s ice20.master_config.txt master_config.txt
cd ~/egil/m2/2.0
./update_target.pl ~/egil/m2/damocles
