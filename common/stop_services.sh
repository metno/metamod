#!/bin/sh
webrun_directory=[==WEBRUN_DIRECTORY==]
continue_upload_monitor=$webrun_directory/upl/CONTINUE_UPLOAD_MONITOR
continue_xml_import=$webrun_directory/CONTINUE_XML_IMPORT
continue_harvester=$webrun_directory/CONTINUE_OAI_HARVEST
if [ -d $webrun_directory/upl ]; then
   rm -f $continue_upload_monitor
fi
rm -f $continue_xml_import
rm -f $continue_harvester
