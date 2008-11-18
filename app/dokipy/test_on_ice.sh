#!/bin/sh
cd ~/egil/m2/dokipy
rm -f master_config.txt
ln -s ice.master_config.txt master_config.txt
cd ~/egil/m2/trunk
./update_target.pl ~/egil/m2/dokipy
