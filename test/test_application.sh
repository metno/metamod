#!/bin/sh
#
# Script for testing one METAMOD2 application. Another incarnation
# of this script is intended to be run (possibly on another machine)
# concurrently with this scripts. The two applications will exchange
# metadata through the OAI-PMH protocol.
#
# Invocation:
#
#    ./test_application.sh -i basedirectory
#    ./test_application.sh basedirectory
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
# J. Postprocessing: If the compare directory is not empty, output files
#    (logs etc.) in the webrun directory are compared with the set of
#    corresponding files in the compare directory. Any discrepancies are
#    reported by E-mail.
#
#    If the compare directory is empty, then the log files currently residing
#    on the webrun directory are copied to the compare directory. While copying,
#    dates and timestamps (YYYY-MM-DD and YYYY-MM-DD HH:MM) are substituted
#    with strings '_DATE_' and '_TIMESTAMP_' respectively. This action prepares
#    the system for repeated normal runs where the produced logfiles are
#    compared with those now residing in the compare directory.
#
#    If changes are made in the METAMOD2 software that result in changes in
#    the log files, then the compare directory should be emptied so that
#    the new log file structure can be initialized.
#
#------------------------------------------------------------------------
WEBUSER=www-data

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
   echo "Comma-separated list of E-mail addresses for recievers"
   echo -n "of unnormal test results: "
   read developeremail
   echo "Enter the ownertag and source URL for the OAI-PMH server to be harvested."
   echo "If harvesting only on a set, also enter the set name."
   echo -n "Two or three items separated by space: "
   read oaiharvesttag oaiharvestsource oaiharvestset
   echo -n "Absolute path to file containing all nc/cdl files to upload: "
   read filestoupload
   cat >testrc <<EOF
sourceurl = $sourceurl
idstring = $idstring
apacheport = $apacheport
opendapurl = $opendapurl
operatoremail = $operatoremail
developeremail = $developeremail
oaiharvest = $oaiharvesttag $oaiharvestsource $oaiharvestset
filestoupload = $filestoupload
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
   read dummy1 dummy2 developeremail
   read dummy1 dummy2 oaiharvesttag oaiharvestsource oaiharvestset
   read dummy1 dummy2 filestoupload
   if [ -z $filestoupload ]; then
      filestoupload=$basedir/source/test/ncinput/files
   fi
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
exec >test_application.out 2>&1
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
/^USERBASE_NAME *=/s|=.*$|= '$idstring-userbase'|
/^APPLICATION_ID *=/s|=.*$|= '$idstring'|
/^BASE_PART_OF_EXTERNAL_URL *=/s|=.*$|= http://'$servername$appendport'|
/^LOCAL_URL *=/s|=.*$|= /'$basedirbasename'|
/^PMH_PORT_NUMBER *=/s|=.*$|= '$pmhport'|
/^PMH_REPOSITORY_IDENTIFIER *=/s|=.*$|= '$idstring.met.no'|
/^PMH_EXPORT_TAGS *=/s|=.*$|= '"'$idstring'"'|
/^OAI_HARVEST_SOURCES *=/s|=.*$|= '$oaiharvesttag' '$oaiharvestsource' '$oaiharvestset'|
/^UPLOAD_DIRECTORY *=/s|=.*$|= '$basedir/webupload'|
/^UPLOAD_FTP_DIRECTORY *=/s|=.*$|= '$basedir/ftpupload'|
/^OPENDAP_DIRECTORY *=/s|=.*$|= '$basedir/[==OPENDAP_BASEDIR==]'|
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
# stop metamod if it is still running
target/metamodInit.sh stop
rm -rf target/*
rm -rf webrun/*
rm -rf webupload/*
rm -rf ftpupload/*
rm -rf data/*

# and add some needed projects
mkdir -p webupload/TUN/osisaf
mkdir -p webupload/TUN/ice


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
cd $basedir/data
for dir in `cat $basedir/source/test/directories`; do
   mkdir -p $dir
done
#
# F. The database is initialized and filled with static data.
# ===========================================================
#
# disable tomcat (SRU2jdbc) connection to database
# this is a hack, TODO: make configurable
/root/apache-tomcat-6.0.16/bin/catalina.sh stop
#
cp -r $basedir/source/test/xmlinput/* $basedir/webrun/XML/$idstring/
find $basedir/webrun/XML/$idstring -name '*.xmd' | xargs perl -pi -e "s/name=\"DAMOC/name=\"$idstring/g; s/ownertag=\"DAM/ownertag=\"$idstring/"
cd $basedir/target/init
./create_and_load_all.sh
#
# G. The services defined for the application is started.
# =======================================================
#
chown -R $WEBUSER $basedir/webrun
chown -R $WEBUSER $basedir/webupload
chown -R $WEBUSER $basedir/ftpupload
chown -R $WEBUSER $basedir/data
cd $basedir/target
su $WEBUSER -c "$basedir/target/metamodInit.sh start"

#
# H. Uploads to the system is simulated.
# ======================================
#
#    by copying files to the ftp- and web-upload areas. Input files
#    are taken from the list of files found in the file having abs. path $filestoupload.
#
cd $basedir
rm -rf t_dir
mkdir t_dir
chown $WEBUSER t_dir
cd $basedir/source/test/ncinput
for fil in `cat $filestoupload`; do su $WEBUSER -c "cp $fil $basedir/t_dir"; su $WEBUSER -c "mv $basedir/t_dir/* $basedir/ftpupload"; sleep 10; done
#
# I. After sleeping some time the services is stopped.
# ====================================================
#
cd $basedir/target
sleep 300
su $WEBUSER -c "$basedir/target/metamodInit.sh stop"
sleep 100
#
# J. Postprocessing:
# ==================
#
cd $basedir
# split INFO and WARN/ERROR log
grep '\[INFO\]' webrun/metamod.log > webrun/metamod.log_info
grep -v '\[INFO\]' webrun/metamod.log | grep -v '\[DEBUG\]' > webrun/metamod.log_warnerror
# 
# compare info logs
logfiles='syserrors metamod.log_info'
if [ -z "`ls compare`" ]; then
   for fil in $logfiles; do
      if [ -r webrun/$fil ]; then
         # remove line-number and time/date
         perl -pe 's/on\s+line:\s+\d+/_LINENO_/g; s/\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(:\d{2},\d+)?/_TIMESTAMP_/g; s/\d{4}-\d{2}-\d{2}/_DATE_/g' webrun/$fil >compare/$fil
      else
         echo "Missing file: webrun/$fil"
      fi
   done
elif [ 1 -eq 1 ]; then
   echo "`whoami`@`uname -n`:`pwd`" >t_result
   count=1
   echo "========== metamod.log warnings:" >>t_result
   cat webrun/metamod.log_warnerror >> t_result
   count=`expr $count + 1`
   for fil in $logfiles; do
      if [ -r webrun/$fil ]; then
         # remove line-number and time/date
         perl -pe 's/on\s+line:\s+\d+/_LINENO_/g; s/\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(:\d{2},\d+)?/_TIMESTAMP_/g; s/\d{4}-\d{2}-\d{2}/_DATE_/g' webrun/$fil | sort | uniq >t_log2 
         echo "========== diff for $fil (new vs. old):" >>t_result
         sort compare/$fil | uniq >t_log3
         diff t_log2 t_log3 >>t_result
         count=`expr $count + 1`
      else
         echo "========== Missing file: webrun/$fil" >>t_result
      fi
   done
   lines=`wc -l t_result | sed 's/ t_result//'`
   if [ $lines -ne $count ]; then
      mail -s "METAMOD2 $idstring test gives unexpected output" $developeremail <t_result
   fi
else
   echo "`whoami`@`uname -n`:`pwd`" >t_result
   echo "======= syserrors:" >>t_result
   cat webrun/syserrors >>t_result
   echo "======= databaselog:" >>t_result
   cat webrun/databaselog >>t_result
   echo "======= upload_monitor.out:" >>t_result
   cat webrun/upload_monitor.out >>t_result
   mail -s "METAMOD2 output from $idstring test" $developeremail <t_result
fi

# keep it running after testing
su $WEBUSER -c "$basedir/target/metamodInit.sh start"

# enable tomcat (SRU2jdbc) connection to database
# this is a hack, TODO: make configurable
/root/apache-tomcat-6.0.16/bin/catalina.sh start
