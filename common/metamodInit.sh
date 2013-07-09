#!/bin/bash

SCRIPT_PATH="`dirname \"$0\"`"
COMMAND=$1
CONFIG=$2

# config must be set in $METAMOD_MASTER_CONFIG envvar if not given as command line param
SHELL_CONF=/tmp/metamod_tmp_bash_config.sh
if perl "$SCRIPT_PATH/scripts/gen_bash_conf.pl" ${CONFIG:+"--config"} $CONFIG > $SHELL_CONF
then
    source $SHELL_CONF
    rm $SHELL_CONF
else
    rm $SHELL_CONF
    echo "Missing config for $0" >2
    exit 1
fi

webrun_directory="$WEBRUN_DIRECTORY"
system_log="$LOG4ALL_SYSTEM_LOG"

#echo "METAMOD_MASTER_CONFIG=$METAMOD_MASTER_CONFIG"
#echo "CONFIG=$CONFIG"
#echo "system_log = $system_log"

COMMON_LIB=$SCRIPT_PATH/lib
export PERL5LIB="$PERL5LIB:$CATALYST_LIB:$COMMON_LIB"

# PIDfiles should be moved to /var/run ASAP - FIXME
upload_monitor_pid=$webrun_directory/upload_monitor.pid
upload_monitor_script=$SCRIPT_PATH/../upload/scripts/upload_monitor.pl
ftp_monitor_pid=$webrun_directory/ftp_monitor.pid
ftp_monitor_script=$SCRIPT_PATH/../upload/scripts/ftp_monitor.pl
prepare_download_pid=$webrun_directory/prepare_download.pid
prepare_download_script=$SCRIPT_PATH/scripts/prepare_download.pl
harvester_pid=$webrun_directory/harvester.pid
harvester_script=$SCRIPT_PATH/../harvest/scripts/harvester.pl
create_thredds_catalogs_pid=$webrun_directory/create_thredds_catalogs.pid
create_thredds_catalogs_script=$SCRIPT_PATH/../thredds/scripts/create_thredds_catalogs.pl

. /lib/lsb/init-functions

running() {
   local pidfile
   pidfile="$@"
    # No pidfile, probably no daemon present
    #
    if [ ! -f $pidfile ]
    then
        return 1
    fi

    pid=`cat $pidfile`

    # No pid, probably no daemon present
    #
    if [ -z "$pid" ]
    then
        return 1
    fi

    if [ ! -d /proc/$pid ]
    then
        return 1
    fi

    return 0
}

start() {

   ## deprecated? FIXME
   #if [ ! -f $PHPLOGFILE ]; then
   #   # create world writeable logfile (i.e. by nobody)
   #   > $PHPLOGFILE
   #   chmod 666 $PHPLOGFILE
   #fi
   #
   ## deprecated? FIXME
   #if [ ! -f $WEBRUN_DIRECTORY/userlog ]; then
   #   # create world writeable logfile
   #   > $WEBRUN_DIRECTORY/userlog
   #   chmod 666 $WEBRUN_DIRECTORY/userlog
   #fi

   if [ ! -f $system_log ]; then
      # create world writeable logfile
      touch $system_log
      chmod 666 $system_log
   fi

   if [ "$METAMODUPLOAD_DIRECTORY" != "" -a "$EXTERNAL_REPOSITORY" != "true" -a -r $upload_monitor_script ]; then
      if ! running $upload_monitor_pid; then
         work_directory=$webrun_directory/upl/work
         work_expand=$work_directory/expand
         work_flat=$work_directory/flat
         path_to_shell_error=$webrun_directory/upl/shell_command_error
         rm -rf $work_expand
         rm -rf $work_flat
         rm -f $path_to_shell_error
         # actually start the daemon
         start_daemon -n 10 -p $upload_monitor_pid $upload_monitor_script -l $system_log -p $upload_monitor_pid  ${CONFIG:+"--config"} $CONFIG
         if [ $? -ne 0 ]; then
            echo "upload_monitor failed: $?"
            return $?;
         fi
      else
         echo "upload_monitor already running"
      fi
   fi
   if [ "$METAMODUPLOAD_DIRECTORY" != "" -a "$EXTERNAL_REPOSITORY" != "true" -a -r $ftp_monitor_script ]; then
      if ! running $ftp_monitor_pid; then
         work_directory=$webrun_directory/upl/work
         work_expand=$work_directory/expand
         work_flat=$work_directory/flat
         path_to_shell_error=$webrun_directory/upl/shell_command_error
         rm -rf $work_expand
         rm -rf $work_flat
         rm -f $path_to_shell_error
         # actually start the daemon
         start_daemon -n 10 -p $ftp_monitor_pid $ftp_monitor_script -l $system_log -p $ftp_monitor_pid ${CONFIG:+"--config"} $CONFIG
         if [ $? -ne 0 ]; then
            echo "ftp_monitor failed: $?"
            return $?;
         fi
      else
         echo "ftp_monitor already running"
      fi
   fi
   if [ "$METAMODBASE_DIRECTORY" != "" -a -r $prepare_download_script ]; then
      if ! running $prepare_download_pid; then
         #start_daemon -n 10 -p $prepare_download_pid $prepare_download_script -log $system_log -pid $prepare_download_pid $2/master_config.txt
         start_daemon -n 10 -p $prepare_download_pid $prepare_download_script -l $system_log -p $prepare_download_pid ${CONFIG:+"--config"} $CONFIG
         if [ $? -ne 0 ]; then
            echo "prepare_download failed: $?"
            return $?;
         fi
      else
         echo "prepare_download already running"
      fi
   fi
   if [ "$METAMODHARVEST_DIRECTORY" != "" -a -r $harvester_script ]; then
      if ! running $harvester_pid; then
         start_daemon -n 10 -p $harvester_pid $harvester_script -l $system_log -p $harvester_pid ${CONFIG:+"--config"} $CONFIG
         if [ $? -ne 0 ]; then
            echo "harvester failed: $?"
            return $?;
         fi
      else
         echo "harvester already running"
      fi
   fi
   if [ "$METAMODTHREDDS_DIRECTORY" != "" -a -r $create_thredds_catalogs_script ]; then
      if ! running $create_thredds_catalogs_pid; then
         start_daemon -n 10 -p $create_thredds_catalogs_pid $create_thredds_catalogs_script -l $system_log -p $create_thredds_catalogs_pid ${CONFIG:+"--config"} $CONFIG
         if [ $? -ne 0 ]; then
            echo "create_thredds_catalogs failed: $?"
            return $?;
         fi
      else
         echo "create_thredds_catalogs already running"
      fi
   fi
}

stop() {
   if [ "$METAMODUPLOAD_DIRECTORY" != "" -a -r $upload_monitor_script ]; then
      killproc -p $upload_monitor_pid $upload_monitor_script SIGTERM
   fi
   if [ "$METAMODUPLOAD_DIRECTORY" != "" -a -r $ftp_monitor_script ]; then
      killproc -p $ftp_monitor_pid $ftp_monitor_script SIGTERM
   fi
   if [ "$METAMODBASE_DIRECTORY" != "" -a -r $prepare_download_script ]; then
      killproc -p $prepare_download_pid $prepare_download_script SIGTERM
   fi
   if [ "$METAMODHARVEST_DIRECTORY" != "" -a -r $harvester_script ]; then
      killproc -p $harvester_pid $harvester_script SIGTERM
   fi
   if [ "$METAMODTHREDDS_DIRECTORY" != "" -a -r $create_thredds_catalogs_script ]; then
      killproc -p $create_thredds_catalogs_pid $create_thredds_catalogs_script SIGTERM
   fi
}

restart() {
   stop;
   start;
}

status() {
   retval=0
   if [ "$METAMODUPLOAD_DIRECTORY" != "" -a -r $upload_monitor_script ]; then
      if running $upload_monitor_pid; then
         echo "upload_monitor is running (pid `cat $upload_monitor_pid`)"
      else
         echo "upload_monitor not running"
         let retval+=1
      fi
   fi
   if [ "$METAMODUPLOAD_DIRECTORY" != "" -a -r $ftp_monitor_script ]; then
      if running $ftp_monitor_pid; then
         echo "ftp_monitor is running (pid `cat $ftp_monitor_pid`)"
      else
         echo "ftp_monitor not running"
         let retval+=2
      fi
   fi
   if [ "$METAMODBASE_DIRECTORY" != "" -a -r $prepare_download_script ]; then
      if running $prepare_download_pid; then
         echo "prepare_download is running (pid `cat $prepare_download_pid`)"
      else
         echo "prepare_download not running"
         let retval+=4
      fi
   fi
   if [ "$METAMODHARVEST_DIRECTORY" != "" -a -r $harvester_script ]; then
      if running $harvester_pid; then
         echo "harvester is running (pid `cat $harvester_pid`)"
      else
         echo "harvester not running"
         let retval+=8
      fi
   fi
   if [ "$METAMODTHREDDS_DIRECTORY" != "" -a -r $create_thredds_catalogs_script ]; then
      if running $create_thredds_catalogs_pid; then
         echo "create_thredds_catalogs is running (pid `cat $create_thredds_catalogs_pid`)"
      else
         echo "create_thredds_catalogs not running"
         let retval+=16
      fi
   fi
   if [ $retval -ne 0 ]; then
      exit 3
   fi
}

case "$COMMAND" in
    start)
        start;
        ;;
    stop)
        stop;
        ;;
    restart)
        restart
        ;;
    force-reload | reload)
        restart
        ;;
    status)
        status $VERSION
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|force-reload|status} [ <configpath> ]"
        exit 1
        ;;
esac

exit 0
