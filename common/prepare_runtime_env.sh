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

#
#  Initialise webrun directory:
#
if [ '$WEBRUN_DIRECTORY' = '' ]; then
   echo "ERROR: WEBRUN_DIRECTORY must be defined in the configuration file"
   echo "exit prepare_runtime_env.sh"
   echo ""
   exit
fi
mkdir -p $WEBRUN_DIRECTORY

#
# Initialise the collection basket download directory
#
mkdir -p $WEBRUN_DIRECTORY/download

if [ "$METAMODUPLOAD_DIRECTORY" != "" ]; then
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
   if [ '$OPENDAP_DIRECTORY' != '' ]; then
      mkdir -p $OPENDAP_DIRECTORY
      if [ -w $OPENDAP_DIRECTORY -a ! -f $OPENDAP_DIRECTORY/.htaccess ]; then
         cat >$OPENDAP_DIRECTORY/.htaccess <<EOF
Order Deny,Allow
Deny from all
EOF
      fi
   fi
fi
