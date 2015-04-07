#!/bin/bash

usage()
{
    cat << EOF
usage: $0 [-u] <config>

This script will install the necessary services for a METAMOD application.

It should not be run as sudo as is already calling sudo on relevant commands and
root user usually does not have sudo privileges. Also, running sudo on /opt/*
is disallowed at met.no production servers.

OPTIONS:
  -h    show this message
  -u    unprivileged (scripts will be owned by your login user, not root)
EOF
}

ordie () {
    if [ $? != 0 ]
    then
        echo "$*"
        exit 1
    fi
}

psudo () { # hack to allow both sudo and non-sudo running of perl scripts
    if [ "$PERLSUDO" ]
    then
        sudo PERL5LIB="$CATALYST_LIB" ${*}
    else
        PERL5LIB="$CATALYST_LIB" $*
    fi
}

###########

# unset this later in the script for users with restricted sudo privileges
PERLSUDO=sudo

#
# parse command line options
#

while getopts “hu” OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        u)
            PERLSUDO=
            echo "Installing scripts as $USER instead of root"
            ;;
        ?)
            usage
            exit
            ;;
    esac
    shift $((OPTIND-1)); OPTIND=1
done

#
# calculate master_config path
#

if [ ! -z "$1" ]
then
    CONFIG=`readlink -f "$1"`
else
    # config must be set in $METAMOD_MASTER_CONFIG envvar if not given as command line param
    if [ ! -z "$METAMOD_MASTER_CONFIG" ]
    then
        CONFIG=$METAMOD_MASTER_CONFIG
    else
        echo "No master configuration specified (param or envvar)" 1>&2
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

#
# read configuration and store in env
#

SCRIPT_PATH="`dirname \"$0\"`/common" # INSTALLATION_DIR not available yet
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

#
# start installation
#

CATALYST_APP="catalyst-$APPLICATION_ID"
COMMON_LIB=`readlink -f $SCRIPT_PATH/lib` # make path absolute before using in PERL5LIB

# make sure perl scripts can find dependencies
# [ should this really be here? FIXME ]
#export PERL5LIB="$CATALYST_LIB:$PERL5LIB"

# write Apache conf and init.d scripts to applic dir

# disabled creation of etc dir since we don't know who is the correct owner
# this is instead now done by gen_httpd_conf.pl
#mkdir -p "$CONFIG_DIR/etc"
#
#if [ ! -w "$CONFIG_DIR/etc" ]
#then
#    echo "Cannot write to $CONFIG_DIR/etc directory" 1>&2
#    exit 1
#fi

psudo perl "$SCRIPT_PATH/scripts/gen_httpd_conf.pl" ${CONFIG:+"--config"} $CONFIG
ordie "Can't generate httpd config - use -u option if insufficient sudo rights"

psudo perl "$SCRIPT_PATH/scripts/gen_initd_script.pl" ${CONFIG:+"--config"} $CONFIG
ordie "Can't generate init.d scripts - use -u option if insufficient sudo rights"

# link files to /etc

#LINKERRMSG=$(cat <<EOT
#Please remove target file(s) before trying automatic install:
#sudo rm /etc/default/$CATALYST_APP /etc/init.d/$CATALYST_APP /etc/init.d/metamodServices-$APPLICATION_ID /etc/rc2.d/S92$CATALYST_APP /etc/rc2.d/S99metamodServices-$APPLICATION_ID /etc/apache2/conf.d/$APPLICATION_ID
#EOT
#)

LINKERRMSG=$(cat <<EOT
Looks like you have manual configuration in /etc. Please fix the following non-symlinked files:
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
    echo Disabling site "default" in Apache config
    sudo a2dissite default
    #echo "WARNING: Static files will not work unless you remove all links in /etc/apache2/sites-enabled!"
else
    sudo ln -s $CONFIG_DIR/etc/httpd.conf  /etc/apache2/sites-available/$VIRTUAL_HOST; ordie "$LINKERRMSG"
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
