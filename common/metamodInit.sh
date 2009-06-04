#!/bin/sh
webrun_directory="[==WEBRUN_DIRECTORY==]"
target_directory="[==TARGET_DIRECTORY==]"

upload_monitor_pid=$webrun_directory/upload_monitor.pid
import_dataset_pid=$webrun_directory/import_dataset.pid
harvester_pid=$webrun_directory/harvester.pid


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
   if [ ! -f [==PHPLOGFILE==] ]; then
      # create world writeable logfile (i.e. by nobody)
      > [==PHPLOGFILE==]
      chmod 666 [==PHPLOGFILE==]
   fi
   if [ ! -f [==WEBRUN_DIRECTORY==]/userlog ]; then
      # create world writeable logfile
      > [==WEBRUN_DIRECTORY==]/userlog
      chmod 666 [==PHPLOGFILE==]
   fi
   if [ "[==METAMODUPLOAD_DIRECTORY==]" != "" -a -r $target_directory/scripts/upload_monitor.pl ]; then
      if ! running $upload_monitor_pid; then
         work_directory=$webrun_directory/upl/work
         work_expand=$work_directory/expand
         work_flat=$work_directory/flat
         path_to_shell_error=$webrun_directory/upl/shell_command_error
         rm -f $work_directory/*
         rm -f $path_to_shell_error
      fi
      start_daemon -n 10 -p $upload_monitor_pid $target_directory/scripts/upload_monitor.pl $webrun_directory/upload_monitor.out $upload_monitor_pid
      if [ $? -ne 0 ]; then
         echo "upload_monitor failed: $?"
         return $?;
      fi
   fi
   if [ "[==METAMODBASE_DIRECTORY==]" != "" -a -r $target_directory/scripts/import_dataset.pl ]; then
      path_to_import_updated=$webrun_directory/import_updated
      if [ ! -f $path_to_import_updated ]; then
         # create/touch path to set timestamp
         >$path_to_import_updated
      fi
      start_daemon -n 10 -p $import_dataset_pid $target_directory/scripts/import_dataset.pl $webrun_directory/import_dataset.out $import_dataset_pid
      if [ $? -ne 0 ]; then
         echo "import_dataset failed: $?"
         return $?;
      fi
   fi
   if [ "[==METAMODHARVEST_DIRECTORY==]" != "" -a -r $target_directory/scripts/harvester.pl ]; then
      start_daemon -n 10 -p $harvester_pid $target_directory/scripts/harvester.pl -log $webrun_directory/harvester.out -pid $harvester_pid
      if [ $? -ne 0 ]; then
         echo "harvester failed: $?"
         return $?;
      fi
   fi   
}

stop() {
   if [ "[==METAMODUPLOAD_DIRECTORY==]" != "" -a -r $target_directory/scripts/upload_monitor.pl ]; then
      killproc -p $upload_monitor_pid $target_directory/scripts/upload_monitor.pl SIGTERM
   fi
   if [ "[==METAMODBASE_DIRECTORY==]" != "" -a -r $target_directory/scripts/import_dataset.pl ]; then
      killproc -p $import_dataset_pid $target_directory/scripts/import_dataset.pl SIGTERM
   fi
   if [ "[==METAMODHARVEST_DIRECTORY==]" != "" -a -r $target_directory/scripts/harvester.pl ]; then
      killproc -p $harvester_pid $target_directory/scripts/harvester.pl SIGTERM
   fi
}

restart() {
   stop;
   start;
}

status() {
   retval=0
   if [ "[==METAMODUPLOAD_DIRECTORY==]" != "" -a -r $target_directory/scripts/upload_monitor.pl ]; then
      if running $upload_monitor_pid; then
         echo "upload_monitor running";
      else
         echo "upload monitor not running";
         retval=1
      fi
   fi
   if [ "[==METAMODBASE_DIRECTORY==]" != "" -a -r $target_directory/scripts/import_dataset.pl ]; then
      if running $import_dataset_pid; then
         echo "import_dataset running"
      else
         echo "import_dataset not running"
         retval=2
      fi
   fi
   if [ "[==METAMODHARVEST_DIRECTORY==]" != "" -a -r $target_directory/scripts/harvester.pl ]; then
      if running $harvester_pid; then
         echo "harvester running"
      else
         echo "harvester not running"
         retval=3
      fi
   fi  
   return $retval;
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
        echo "Usage: $0 {start|stop|restart|reload|force-reload|status}"
        exit 1
        ;;
esac

exit 0

        