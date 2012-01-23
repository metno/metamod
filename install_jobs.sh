#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`/common"

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

ordie () {
    if [ $? != 0 ]
    then
        echo "$*"
        exit 1
    fi
}

# make sure perl scripts can find dependencies
export PERL5LIB="$CATALYST_LIB:$PERL5LIB"

# write Apache conf and init.d scripts to applic dir

mkdir -p "$CONFIG_DIR/etc"

if [ ! -w "$CONFIG_DIR/etc" ]
then
    echo "Cannot write to $CONFIG_DIR/etc directory" 1>&2
    exit 1
fi

PERL5LIB="$CATALYST_LIB:$PERL5LIB" perl "$SCRIPT_PATH/scripts/gen_httpd_conf.pl" ${CONFIG:+"--config"} $CONFIG
ordie "Can't generate httpd config"

PERL5LIB="$CATALYST_LIB:$PERL5LIB" perl "$SCRIPT_PATH/scripts/gen_initd_script.pl" ${CONFIG:+"--config"} $CONFIG
ordie "Can't generate init.d scripts"

# link files to /etc

#LINKERRMSG=$(cat <<EOT
#Please remove target file(s) before trying automatic install:
#sudo rm /etc/default/$CATALYST_APP /etc/init.d/$CATALYST_APP /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S92$CATALYST_APP /etc/rc2.d/S99metamodServices-$APPLICATION_ID /etc/apache2/conf.d/$APPLICATION_ID
#EOT
#)

LINKERRMSG=$(cat <<EOT
Looks like you have manual configuration in /etc. Please the following non-symlinked files:
/etc/default/$CATALYST_APP
/etc/init.d/$CATALYST_APP
/etc/init.d/metamodServices-$APPLICATION_ID
/etc/rc2.d/S92$CATALYST_APP
/etc/rc2.d/S99metamodServices-$APPLICATION_ID
/etc/apache2/conf.d/$APPLICATION_ID
EOT
)

# remove symlinks to avoid conflict when overwriting
for f in /etc/default/$CATALYST_APP /etc/init.d/$CATALYST_APP /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S92$CATALYST_APP /etc/rc2.d/S99metamodServices-$APPLICATION_ID /etc/apache2/conf.d/$APPLICATION_ID
do
    if [ -L $f ]
    then
        sudo rm $f
    fi
done

echo "Linking Apache config"
if [ -z "$VIRTUAL_HOST" ]; then
    sudo ln -s $CONFIG_DIR/etc/httpd.conf  /etc/apache2/conf.d/$APPLICATION_ID; ordie "$LINKERRMSG"
else
    sudo ln -s $CONFIG_DIR/etc/httpd.conf  /etc/apache/sites-available/$VIRTUAL_HOST; ordie "$LINKERRMSG"
    ${VIRTUAL_HOST:+"sudo a2ensite"} $VIRTUAL_HOST
fi

# install catalyst job
echo "Linking init.d scripts"
sudo ln -s $CONFIG_DIR/etc/default/$CATALYST_APP /etc/default/$CATALYST_APP; ordie "$LINKERRMSG"
sudo ln -s $CONFIG_DIR/etc/init.d/$CATALYST_APP /etc/init.d/$CATALYST_APP; ordie "$LINKERRMSG"
# start Catalyst at boot
sudo ln -s /etc/init.d/$CATALYST_APP /etc/rc2.d/S92$CATALYST_APP; ordie "$LINKERRMSG"

# install metamodInit.sh job [code copied from Egil]
if [ $APPLICATION_USER ]; then
	cat > /tmp/metamodServices-$APPLICATION_ID <<- EOT
		#! /bin/sh
		su -c "export PERL5LIB=$PERL5LIB:$CATALYST_LIB:$COMMON_LIB; $INSTALLATION_DIR/common/metamodInit.sh \$1 $CONFIG" -s /bin/sh $APPLICATION_USER
	EOT
	# make sure the tabs above are not replaced with spaces (or the script will break)
    sudo mv /tmp/metamodServices-$APPLICATION_ID /etc/init.d/; ordie "$LINKERRMSG"
    sudo chmod +x /etc/init.d/metamodServices-$APPLICATION_ID; ordie "$LINKERRMSG"
    sudo ln -s /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S99metamodServices-$APPLICATION_ID; ordie "$LINKERRMSG"
fi

# TODO: include prepare_runtime_env.sh ??
