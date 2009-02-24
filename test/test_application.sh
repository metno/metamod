#!/bin/sh
#
# Script for testing one METAMOD2 application. Another incarnation
# of this script is intended to be run (possibly on another machine)
# concurrently with this scripts. The two applications will exchange
# metadata through the OAI-PMH protocol.
#
# Invocation:
#
#    ./test_application.sh [ -i ] basedirectory
#
#    where:
#
#    basedirectory  - Is the path to the top directory for the test.
#                     This directory has the following subdirectories:
#
#                     source    - The top directory for the METAMOD2
#                                 software (updated from the SVN source).
#                                 This directory must be initialized by
#                                 the command:
#                                 'svn checkout <URL to SVN source>'.
#                                 This must be done outside this script,
#                                 Before the script is run the first time.
#                               
#                        source/test/applic
#                               - The local files for the application,
#                                 including the master_config.txt file.
#
#                        source/test/u1input
#                               - A set of user files that are copied to
#                                 webrun/u1.
#
#                        source/test/ncinput
#                               - Directory containing netCDF and CDL
#                                 files for simulated uploading.
#
#                     target    - The target directory for the installed
#                                 application.
#
#                     webrun    - The webrun directory for the installed
#                                 application.
#
#                     ftpupload - Directory for ftp uploads.
#
#                     webupload - Top directory for web uploads.
#
#                     data      - Top directory for the data repository
#
#                     compare   - Output files (logs etc.) from another
#                                 run (deemed to be a normal problemfree
#                                 run).
#
# If the -i option is given, then the script will enter an interactive loop
# where some basic information is enquired from the user. This information
# is stored in the file [basedirectory]/testrc. An initial checkout of the
# METAMOD2 software is made. Then the script terminates.
#
# When the script is started without the -i option, the basic information
# gathered from the user in an earlier interactive run is taken from the
# testrc-file, and the script performs the following tasks:
#
# A. The source directory is updated. (svn update).
#
# B. The master_config.txt file in the app directory is 'doctored' 
#    by changing the value of some important variables.
#
# C. Purging of the directory structure: All content in the following
#    directories are deleted:
#    target, webrun, webupload, ftpupload, data
#
# D. The software is installed into the target directory.
#
# E. A set of upload users is installed in the webrun/u1 directory.
#    A corresponding directory structure is created for the webupload
#    and data directories.
#
# F. The database is initialized and filled with static data.
# 
# G. The services defined for the application is started.
#
# H. Uploads to the system is simulated by copying files to the ftp- and
#    web-upload areas. Input files are taken from the ncinput directory.
#
# I. After sleeping some time (to let the import script finish its tasks),
#    the services is stopped.
#
# J. Postprocessing: Output files (logs etc.) are compared with the set of
#    files in the compare directory. Any discrepancies are reported by E-mail.
#
#------------------------------------------------------------------------
if [ $# -eq 2 -a $1 = '-i' ]; then
   mkdir -p $2
   cd $2
   basedir=`pwd`
   mkdir -p source
   echo ""
   echo -n "Get the METAMOD source from the following subversion URL: "
   read sourceurl
   echo -n "Short string used for application id etc: "
   read idstring
   echo -n "Port number for Apache server: "
   read apacheport
   echo -n "URL of OPeNDAP server (any URL will do): "
   read opendapurl
   echo -n "Operator E-mail address: "
   read operatoremail
   echo "Enter the ownertag and source URL for the OAI-PMH server to be harvested."
   echo -n "Two items separated by space: "
   read oaiharvesttag oaiharvestsource
   cat >testrc <<EOF
sourceurl = $sourceurl
idstring = $idstring
apacheport = $apacheport
opendapurl = $opendapurl
operatoremail = $operatoremail
oaiharvest = $oaiharvesttag $oaiharvestsource
EOF
   echo ""
   echo "The entered items can any time be changed by editing the $basedir/testrc file."
   echo ""
   echo "Checking out the source from SVN:"
   svn checkout $sourceurl source
   echo ""
   echo "Leaving this script. The system has been initialised."
   echo "To start a simulation, run this script again without the '-i' option."
   echo ""
   exit
elif [ $# -eq 1 -a -d $1 -a -d $1/source -a -r $1/testrc ]; then
   cd $1
   basedir=`pwd`
   exec <testrc
   read dummy1 dummy2 sourceurl
   read dummy1 dummy2 idstring
   read dummy1 dummy2 apacheport
   read dummy1 dummy2 opendapurl
   read dummy1 dummy2 operatoremail
   read dummy1 dummy2 oaiharvesttag oaiharvestsource
else
   echo ""
   echo "Usage:       $0 -i basedirectory"
   echo "             $0 basedirectory"
   echo ""
   echo "The first time this script is used on a new basedirectory, the -i (interactive)"
   echo "option must be used. Then the directory structure is initialized and the user"
   echo "is prompted for some essential information."
   echo ""
   exit
fi
exec >test_application.out
set -x
cd $basedir
mkdir -p target
mkdir -p webrun
mkdir -p ftpupload
mkdir -p webupload
mkdir -p data
mkdir -p compare
#
# A. The source directory is updated. (svn update).
# =================================================
#
cd $basedir/source
svn update
#
# B. The master_config.txt file in the application directory is 'doctored'
# ========================================================================
#
cd $basedir/source/test/applic
importbasetime=\
`perl -e 'use DateTime; my $dt=DateTime->now; $dt->set(hour => 0, minute => 0, second => 0); print $dt->epoch;'` 
servername=`uname -n`
if [ $apacheport -ne 80 ]; then
   appendport=':'$apacheport
   pmhport=".':$apacheport'"
else
   appendport=''
   pmhport=''
fi
admindomain=`expr $servername : ".*\.\([^.]*\.[^.]*\)"`
datasettags=`expr $servername : ".*\.\([^.]*\.[^.]*\)"`
basedirbasename=`basename $basedir`
sed '/^SOURCE_DIRECTORY *=/s|=.*$|= '$basedir/source'|
/^TARGET_DIRECTORY *=/s|=.*$|= '$basedir/target'|
/^WEBRUN_DIRECTORY *=/s|=.*$|= '$basedir/webrun'|
/^ADMIN_DOMAIN *=/s|=.*$|= '$admindomain'|
/^DATABASE_NAME *=/s|=.*$|= '$idstring'|
/^APPLICATION_ID *=/s|=.*$|= '$idstring'|
/^BASE_PART_OF_EXTERNAL_URL *=/s|=.*$|= http//'$servername$appendport'|
/^LOCAL_URL *=/s|=.*$|= /'$basedirbasename'|
/^PMH_PORT_NUMBER *=/s|=.*$|= '$pmhport'|
/^PMH_REPOSITORY_IDENTIFIER *=/s|=.*$|= '$idstring'|
/^PMH_EXPORT_TAGS *=/s|=.*$|= '"'$idstring'"'|
/^OAI_HARVEST_SOURCES *=/s|=.*$|= '$oaiharvesttag' '$oaiharvestsource'|
/^UPLOAD_DIRECTORY *=/s|=.*$|= '$basedir/webupload'|
/^UPLOAD_FTP_DIRECTORY *=/s|=.*$|= '$basedir/ftpupload'|
/^OPENDAP_DIRECTORY *=/s|=.*$|= '$basedir/data'|
/^OPENDAP_URL *=/s|=.*$|= '$opendapurl'|
/^OPERATOR_EMAIL *=/s|=.*$|= '$operatoremail'|
/^DATASET_TAGS *=/s|=.*$|= '"'$idstring','$oaiharvesttag'"'|
/^UPLOAD_OWNERTAG *=/s|=.*$|= '$idstring'|
/^TEST_IMPORT_BASETIME *=/s|=.*$|= '$importbasetime'|' source.master_config.txt >master_config.txt
#
# C. Purging of the directory structure:
# ======================================
#
cd $basedir
rm -rf target/*
rm -rf webrun/*
rm -rf webupload/*
rm -rf ftpupload/*
rm -rf data/*
#
# D. The software is installed into the target directory:
# =======================================================
#
cd $basedir/source
./update_target.pl test/applic
cd $basedir/target
./prepare_runtime_env.sh
#
# E. A set of upload users is installed in the webrun/u1 directory:
# =================================================================
#
cd $basedir/webrun
rm -rf u1
mkdir u1
cp $basedir/source/test/u1input/* u1
#
# F. The database is initialized and filled with static data.
# ===========================================================
#
cd $basedir/target/init
./create_and_load_all.sh
#
# G. The services defined for the application is started.
# =======================================================
#
cd $basedir/target
./start_services.sh
#
# H. Uploads to the system is simulated.
# ======================================
#
#    by copying files to the ftp- and web-upload areas. Input files
#    are taken from the list of files found in ncinput/files.
#
cd $basedir
rm -rf t_dir
mkdir t_dir
cd $basedir/source/test/ncinput
for fil in `cat files`; do cp $fil $basedir/t_dir; mv $basedir/t_dir/* $basedir/ftpupload; sleep 10; done
#
# I. After sleeping some time the services is stopped.
# ====================================================
#
cd $basedir/target
sleep 20
./stop_services.sh
sleep 20
#
# J. Postprocessing:
# ==================
#
