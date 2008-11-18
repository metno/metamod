#!/bin/sh
if [ -d [==TARGET_DIRECTORY==]/htdocs/adm ]; then
#
#  Set up .htaccess files:
#
   if [ ! -f [==TARGET_DIRECTORY==]/htdocs/adm/.htaccess ]; then
      if [ '[==ADMIN_WEBUSER==]' != '' ]; then
         cat >[==TARGET_DIRECTORY==]/htdocs/adm/.htaccess <<EOF
AuthType Basic
AuthName "Password Required"
AuthUserFile [==AUTH_USERFILE==]
Require user [==ADMIN_WEBUSER==]
Order Deny,Allow
Deny from all
Allow from [==ADMIN_DOMAIN==]
Satisfy all
EOF
      else
         cat >[==TARGET_DIRECTORY==]/htdocs/adm/.htaccess <<EOF
AuthType Basic
AuthName "Domain required"
Order Deny,Allow
Deny from all
Allow from [==ADMIN_DOMAIN==]
EOF
      fi
   fi
fi
#
#  Initialise webrun directory:
#
mkdir -p [==WEBRUN_DIRECTORY==]
if [ -d [==TARGET_DIRECTORY==]/htdocs/upl ]; then
   mkdir -p [==WEBRUN_DIRECTORY==]/u0
   mkdir -p [==WEBRUN_DIRECTORY==]/u1
   mkdir -p [==WEBRUN_DIRECTORY==]/u2
   mkdir -p [==WEBRUN_DIRECTORY==]/upl
   mkdir -p [==WEBRUN_DIRECTORY==]/upl/problemfiles
   mkdir -p [==WEBRUN_DIRECTORY==]/upl/uerr
   cd [==TARGET_DIRECTORY==]/htdocs/upl
   rm -f uerr
   ln -s [==WEBRUN_DIRECTORY==]/upl/uerr
   if [ ! -f [==WEBRUN_DIRECTORY==]/ftp_events ]; then
      cat >[==WEBRUN_DIRECTORY==]/ftp_events <<EOF
[==FTP_EVENTS_INITIAL_CONTENT==]
EOF
   fi
fi
if [ -d [==TARGET_DIRECTORY==]/htdocs/sch ]; then
#
#  Initialise maps directory:
#
   rm -rf [==WEBRUN_DIRECTORY==]/maps
   mkdir [==WEBRUN_DIRECTORY==]/maps
   cp [==TARGET_DIRECTORY==]/htdocs/img/orig.png [==WEBRUN_DIRECTORY==]/maps
fi
if [ -d [==TARGET_DIRECTORY==]/htdocs/upl -o -d [==TARGET_DIRECTORY==]/htdocs/qst ]; then
#
#  Initialise XML directory:
#
   mkdir -p [==WEBRUN_DIRECTORY==]/XML/[==APPLICATION_ID==]
   mkdir -p [==WEBRUN_DIRECTORY==]/XML/history
fi
#
if [ -d [==TARGET_DIRECTORY==]/htdocs/upl ]; then
#
#  Initialize upload and OPeNDAP directories:
#
   mkdir -p [==UPLOAD_DIRECTORY==]
   mkdir -p [==UPLOAD_FTP_DIRECTORY==]
   mkdir -p [==OPENDAP_DIRECTORY==]
   if [ ! -f [==OPENDAP_DIRECTORY==]/.htaccess ]; then
      cat >[==OPENDAP_DIRECTORY==]/.htaccess <<EOF
Order Deny,Allow
Deny from all
EOF
   fi
fi
