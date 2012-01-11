#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"

# config must be set in $METAMOD_MASTER_CONFIG envvar if not given as command line param
if [ ! -z "$1" ]
then
    CONFIG=`readlink -f "$1"`
else
    if [ ! -z "$METAMOD_MASTER_CONFIG" ]
    then
        CONFIG=$METAMOD_MASTER_CONFIG
    else
        echo "No configuration specified (param or envvar)" 1>&2
        exit 1
    fi
fi

if [ -r $CONFIG ]
then
    echo "Using config file $CONFIG"
else
    echo "Config file $CONFIG not readable" 1>&2
    exit 1
fi

SHELL_CONF=/tmp/metamod_tmp_bash_config.sh
perl "$SCRIPT_PATH/scripts/gen_bash_conf.pl" ${CONFIG:+"--config"} $CONFIG > $SHELL_CONF

if [ -s "$SHELL_CONF" ]
then
    source $SHELL_CONF
    rm $SHELL_CONF
else
    echo "Configuration file is empty!" 1>&2
    exit 2
fi

if [ -z "$APPLICATION_ID" ]
then
    echo "Missing application id! Config not read?" 1>&2
    exit 1
fi

CATALYST_APP="catalyst-$APPLICATION_ID"
COMMON_LIB=$SCRIPT_PATH/lib

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
		su -c "export PERL5LIB=$PERL5LIB:$CATALYST_LIB:$COMMON_LIB; $INSTALLATION_DIR/common/metamodInit.sh \$1 $CONFIG" -s /bin/sh $APPLICATION_USER
	EOT
	# make sure the tabs above are not replaced with spaces (or the script will break)
    sudo mv /tmp/metamodServices-$APPLICATION_ID /etc/init.d/; ordie
    sudo chmod +x /etc/init.d/metamodServices-$APPLICATION_ID; ordie
    sudo ln -s /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S99metamodServices-$APPLICATION_ID; ordie
fi
