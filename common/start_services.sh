#!/bin/sh
webrun_directory=[==WEBRUN_DIRECTORY==]
target_directory=[==TARGET_DIRECTORY==]
if [ -r $target_directory/scripts/upload_monitor.pl ]; then
   work_directory=$webrun_directory/upl/work
   work_expand=$work_directory/expand
   work_flat=$work_directory/flat
   path_to_shell_error=$webrun_directory/upl/shell_command_error
   continue_upload_monitor=$webrun_directory/upl/CONTINUE_UPLOAD_MONITOR
   rm -f $work_directory/*
   rm -f $path_to_shell_error
   >$continue_upload_monitor
   nohup nice $target_directory/scripts/upload_monitor.pl >$webrun_directory/upload_monitor.out &
fi
if [ -r $target_directory/scripts/import_dataset.pl ]; then
   continue_xml_import=$webrun_directory/CONTINUE_XML_IMPORT
   path_to_import_updated=$webrun_directory/import_updated
   >$continue_xml_import
   if [ ! -f $path_to_import_updated ]; then
      >$path_to_import_updated
   fi
   nohup nice $target_directory/scripts/import_dataset.pl >$webrun_directory/import_dataset.out &
fi
