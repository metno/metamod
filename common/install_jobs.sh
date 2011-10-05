#!/bin/bash

if [ $# != 1 ]
then
    echo "You must supply the config dir as a parameter"
    exit 1
fi

if [ ! -r $1 ]
then
    echo "Cannot read the file "$1
    exit 1
fi

# Load the configuration dynamically
SCRIPT_PATH="`dirname \"$0\"`"
source <(perl "$SCRIPT_PATH/scripts/gen_bash_conf.pl" "$1/master_config.txt")

CATALYST_APP="catalyst-$APPLICATION_ID"

# don't overwrite existing text files in /etc (only symlinks are ok)
ordie () {
    if [ $? != 0 ]
    then
        echo "Please remove target file(s) before trying automatic install:"
        echo "sudo rm /etc/default/$CATALYST_APP /etc/init.d/$CATALYST_APP /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S92$CATALYST_APP /etc/apache2/conf.d/$APPLICATION_ID"
        exit 1
    fi
}


if [ "$VIRTUAL_HOST" = "" ]; then
    sudo ln -s $CONFIG_DIR/etc/httpd.conf  /etc/apache2/conf.d/$APPLICATION_ID; ordie
else
    sudo ln -s $CONFIG_DIR/etc/httpd.conf  /etc/apache/sites-available/$VIRTUAL_HOST; ordie
    ${VIRTUAL_HOST:+"sudo a2ensite"} $VIRTUAL_HOST
fi

# install catalyst job
sudo ln -s $CONFIG_DIR/etc/default/$CATALYST_APP /etc/default/$CATALYST_APP; ordie
sudo ln -s $CONFIG_DIR/etc/init.d/$CATALYST_APP /etc/init.d/$CATALYST_APP; ordie
# start Catalyst at boot
sudo ln -s /etc/init.d/$CATALYST_APP /etc/rc2.d/S92$CATALYST_APP; ordie


# install metamodInit.sh job [code copied from Egil]
if [ $APPLICATION_USER ]; then
	cat > /tmp/metamodServices-$APPLICATION_ID <<- EOT
		#! /bin/sh
		su -c "$INSTALLATION_DIR/common/metamodInit.sh \$*" -s /bin/sh $APPLICATION_USER
	EOT
	# make sure the tabs above are not replaced with spaces (or the script will break)
    sudo mv /tmp/metamodServices-$APPLICATION_ID /etc/init.d/; ordie
    sudo ln -s /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S99metamodServices-$APPLICATION_ID; ordie
fi
