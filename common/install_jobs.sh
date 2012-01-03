#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"
CONFIG=$1
# config must be set in $METAMOD_MASTER_CONFIG envvar if not given as command line param
SHELL_CONF=/tmp/metamod_tmp_bash_config.sh
perl "$SCRIPT_PATH/scripts/gen_bash_conf.pl" ${CONFIG:+"--config"} $CONFIG > $SHELL_CONF
source $SHELL_CONF
rm $SHELL_CONF

CATALYST_APP="catalyst-$APPLICATION_ID"

# don't overwrite existing text files in /etc (only symlinks are ok)
ordie () {
    if [ $? != 0 ]
    then
        echo "Please remove target file(s) before trying automatic install:"
        echo "sudo rm /etc/default/$CATALYST_APP /etc/init.d/$CATALYST_APP /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S92$CATALYST_APP /etc/rc2.d/S99metamodServices-$APPLICATION_ID /etc/apache2/conf.d/$APPLICATION_ID"
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
    sudo chmod +x /etc/init.d/metamodServices-$APPLICATION_ID; ordie
    sudo ln -s /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S99metamodServices-$APPLICATION_ID; ordie
fi
