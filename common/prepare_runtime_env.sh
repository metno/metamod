#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"
CONFIG=$1
SHELL_CONF=/tmp/metamod_tmp_bash_config.sh
perl "$SCRIPT_PATH/scripts/gen_bash_conf.pl" ${CONFIG:+"--config"} $CONFIG > $SHELL_CONF
source $SHELL_CONF
rm $SHELL_CONF

#
#  Initialise webrun directory:
#
if [ -z "$WEBRUN_DIRECTORY" ]; then
   echo "ERROR: WEBRUN_DIRECTORY must be defined in the configuration file"
   #echo "exit prepare_runtime_env.sh" # what's this for?
   #echo ""
   exit 1
fi

mkdir -p $WEBRUN_DIRECTORY

if [ ! -w "$WEBRUN_DIRECTORY" ]; then
    echo "$WEBRUN_DIRECTORY not writable. Suggest you run this script via sudo"
    exit 1
fi

#
# Initialise the collection basket download directory
#
mkdir -p $WEBRUN_DIRECTORY/download


mkdir -p $WEBRUN_DIRECTORY/upl
mkdir -p $WEBRUN_DIRECTORY/upl/problemfiles
mkdir -p $WEBRUN_DIRECTORY/upl/uerr
mkdir -p $WEBRUN_DIRECTORY/upl/ftaf
mkdir -p $WEBRUN_DIRECTORY/upl/etaf
if [ ! -f $WEBRUN_DIRECTORY/ftp_events ]; then
    cat >$WEBRUN_DIRECTORY/ftp_events <<EOF
$FTP_EVENTS_INITIAL_CONTENT
EOF
fi

#
#  Initialise XML directory:
#
mkdir -p $WEBRUN_DIRECTORY/XML/$APPLICATION_ID
mkdir -p $WEBRUN_DIRECTORY/XML/history

#
#  Initialize upload and OPeNDAP directories:
#
if [ '$UPLOAD_DIRECTORY' != '' ]; then mkdir -p $UPLOAD_DIRECTORY; fi
if [ '$UPLOAD_FTP_DIRECTORY' != '' ]; then mkdir -p $UPLOAD_FTP_DIRECTORY; fi

# OpENDAP currently not accessible (missing from Apache config)
if [ '$OPENDAP_DIRECTORY' != '' ]; then
    mkdir -p $OPENDAP_DIRECTORY
    if [ -w $OPENDAP_DIRECTORY -a ! -f $OPENDAP_DIRECTORY/.htaccess ]; then
        cat >$OPENDAP_DIRECTORY/.htaccess <<EOF
Order Deny,Allow
Deny from all
EOF
    fi
fi

# make sure webrun dir is writable by the application
if [ ! -z "$APPLICATION_USER" ]; then
    sudo chown -R "$APPLICATION_USER" $WEBRUN_DIRECTORY
fi
