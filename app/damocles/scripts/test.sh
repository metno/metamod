#!/bin/sh
ftp_dir_path=[==UPLOAD_FTP_DIRECTORY==]
upload_dir_path=[==UPLOAD_DIRECTORY==]
webrun_directory=[==WEBRUN_DIRECTORY==]
work_directory=$webrun_directory/upl/work
uerr_directory=$webrun_directory/upl/uerr
work_expand=$work_directory/expand
work_flat=$work_directory/flat
application_id=[==APPLICATION_ID==]
xml_directory=$webrun_directory/XML/$application_id
xml_history_directory=$webrun_directory/XML/history
target_directory=[==TARGET_DIRECTORY==]
opendap_directory=[==OPENDAP_DIRECTORY==]
problem_dir_path=$webrun_directory/upl/problemfiles
path_to_syserrors=$webrun_directory/upl/syserrors
path_to_shell_error=$webrun_directory/upl/shell_command_error
path_to_shell_log=$webrun_directory/upl/shell_log
path_to_control=$webrun_directory/upl/CONTINUE_UPLOAD_MONITOR
rm $ftp_dir_path/*
find $upload_dir_path -type f -exec rm {} \;
rm $webrun_directory/upl/shell_log
rm $work_directory/*
rm $uerr_directory/*
rm $work_expand/*
rm $work_flat/*
rm $xml_directory/*
rm $xml_history_directory/*
find $opendap_directory -type f -exec rm {} \;
cat >$opendap_directory/.htaccess <<EOF
Order Deny,Allow
Deny from all
EOF
rm $problem_dir_path/*
rm $path_to_syserrors
rm $path_to_shell_error
rm $path_to_shell_log
rm -rf $webrun_directory/maps
mkdir $webrun_directory/maps
cp $target_directory/htdocs/img/orig.png $webrun_directory/maps
source $target_directory/start_services.sh
if [ 1 -eq 1 ]; then
cat >t_events <<EOF
4 /disk1/data/UT/TaraMeteo/TaraMeteo_RadiationDaily.cdl
4 /disk1/data/AWI/MSM0204CTD_test1.tar.gz
60 /disk1/data/DTU/gmmicemov/gmmicemov_20070519-20070522.nc
60 /disk1/data/IOPAS/oceania_AR07.tar
60 /disk1/data/DTU/gmmicemov/gmmicemov_20060213-20060216.nc
60 /disk1/data/DTU/gmmicemov/gmmicemov_20061031-20061103.nc
60 /disk1/data/DTU/optimal/optimal_20071101.nc
60 /disk1/data/SU/aoe/aoe_sband_cloud_radar_low.nc
60 /disk1/data/SU/aoe/aoe_mast_turbulence_5m_15min.nc
60 /disk1/data/SU/aoe/aoe_sodar.nc
60 /disk1/data/SU/aoe/aoe_scanning_radiometer.nc
60 /disk1/data/SU/aoe/aoe_mast_turbulence_15m_15min.nc
60 /disk1/data/SU/aoe/aoe_2d_sonic_wind.nc
60 /disk1/data/SU/aoe/aoe_station_2_turb.nc
60 /disk1/data/AWI/MSM0204CTD/MSM0204CTD_78801.nc
60 /disk1/data/DMI/icedrift/icedrift_ch4_200511112255_200511121237.nc
60 /disk1/data/DMI/icedrift/icedrift_ch4_200508281334_200508282313.nc
60 /disk1/data/DMI/icedrift/icedrift_ch2_200505281429_200505291301.nc
60 /disk1/data/DMI/icedriftC2/icedriftC2_200508241338_200508251314.nc
60 /disk1/data/DMI/icedriftC2/icedriftC2_200507051324_200507061300.nc
60 /disk1/data/DMI/icedriftC4/icedrift_ch4_200512201306_200512202301.nc
60 /disk1/data/DMI/icedriftC4/icedrift_ch4_200601012326_200601021128.nc
60 /disk1/data/DMI/icedriftC4/icedrift_ch4_200509141341_200509142324.nc
60 /disk1/data/met.no/synop/synop_99710.nc
60 /disk1/data/met.no/synop/synop_99950.nc
60 /disk1/data/met.no/synop/synop_99720.nc
60 /disk1/data/met.no/icesst/icesst_metno_ana.2007010400.nc
60 /disk1/data/met.no/icesst/icesst_metno_ana.2007011400.nc
0 0
EOF
exec <t_events
teller=1
while [ true ]; do
#   
#    Read one line from standard input
#    and assign blank-separated tokens to
#    the varable list:
#   
   read waitsec filename
   if [ $waitsec -eq 0 ]; then
      exit
   fi
   sleep $waitsec
   bname=`basename $filename`
   newname=$upload_dir_path`echo $filename | sed 's/^...........//'`
   cp $filename /disk1/tmp_uploaded
#   if [ `expr $teller % 2` -eq 0 ]; then
#      echo "Upload $newname"
#      mv /disk1/tmp_uploaded $newname
#   else
      echo "Upload [==UPLOAD_FTP_DIRECTORY==]/$bname"
      mv /disk1/tmp_uploaded [==UPLOAD_FTP_DIRECTORY==]/$bname
#   fi
   teller=`expr $teller + 1`
done
else
cp $target_directory/staticdata/datasets/* $xml_directory
fi
