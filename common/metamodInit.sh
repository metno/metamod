#!/bin/bash

if [ $# != 2 ]
then
    echo "You must supply the config dir as a parameter"
    exit 1
fi

if [ ! -r $2 ]
then
    echo "Cannot read the file "$2
    exit 1
fi

# Load the configuration dynamically
SCRIPT_PATH="`dirname \"$0\"`"
source <(perl "$SCRIPT_PATH/scripts/gen_bash_conf.pl" "$2/master_config.txt")

webrun_directory="$WEBRUN_DIRECTORY"
target_directory="$TARGET_DIRECTORY"
system_log="$LOG4ALL_SYSTEM_LOG"

COMMON_LIB=$SCRIPT_PATH/lib
export PERL5LIB="$PERL5LIB:$CATALYST_LIB:$COMMON_LIB"

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
   if [ ! -f $PHPLOGFILE ]; then
      # create world writeable logfile (i.e. by nobody)
      > $PHPLOGFILE
      chmod 666 $PHPLOGFILE
   fi
   if [ ! -f $WEBRUN_DIRECTORY/userlog ]; then
      # create world writeable logfile
      > $WEBRUN_DIRECTORY/userlog
      chmod 666 $WEBRUN_DIRECTORY/userlog
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
         start_daemon -n 10 -p $upload_monitor_pid $upload_monitor_script $system_log $upload_monitor_pid
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
         start_daemon -n 10 -p $ftp_monitor_pid $ftp_monitor_script $system_log $ftp_monitor_pid
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
         start_daemon -n 10 -p $prepare_download_pid $prepare_download_script -log $system_log -pid $prepare_download_pid $2/master_config.txt
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
         start_daemon -n 10 -p $harvester_pid $harvester_script -log $system_log -pid $harvester_pid
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
         start_daemon -n 10 -p $create_thredds_catalogs_pid $create_thredds_catalogs_script $system_log $create_thredds_catalogs_pid
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
         echo "upload_monitor running";
      else
         echo "upload_monitor not running";
         retval=1
      fi
   fi
   if [ "$METAMODUPLOAD_DIRECTORY" != "" -a -r $ftp_monitor_script ]; then
      if running $ftp_monitor_pid; then
         echo "ftp_monitor running";
      else
         echo "ftp_monitor not running";
         retval=1
      fi
   fi
   if [ "$METAMODBASE_DIRECTORY" != "" -a -r $prepare_download_script ]; then
      if running $prepare_download_pid; then
         echo "prepare_download running"
      else
         echo "prepare_download not running"
         retval=2
      fi
   fi
   if [ "$METAMODHARVEST_DIRECTORY" != "" -a -r $harvester_script ]; then
      if running $harvester_pid; then
         echo "harvester running"
      else
         echo "harvester not running"
         retval=3
      fi
   fi
   if [ "$METAMODTHREDDS_DIRECTORY" != "" -a -r $create_thredds_catalogs_script ]; then
      if running $create_thredds_catalogs_pid; then
         echo "create_thredds_catalogs running"
      else
         echo "create_thredds_catalogs not running"
         retval=4
      fi
   fi
   if [ $retval -ne 0 ]; then
      exit 3;
   fi
}

case "$1" in
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
        echo "Usage: $0 {start|stop|restart|reload|force-reload|status} <path to config>"
        exit 1
        ;;
esac

exit 0
