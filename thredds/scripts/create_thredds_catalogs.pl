#!/usr/bin/perl -w

=begin LICENSE

Copyright (C) YYYY The Norwegian Meteorological Institute.  All Rights Reserved.

B<METAMOD> - Web portal for metadata search and upload

Copyright (C) 2008 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: egil.storen@met.no

This file is part of METAMOD

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

METAMOD is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with METAMOD; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

=end LICENSE

=cut

use strict;
use warnings;
use File::Spec;

use FindBin;
use lib ("$FindBin::Bin/../../common/lib");

use Metamod::Dataset;
use Metamod::Utils qw(findFiles);
use Metamod::Config qw(:init_logger);
use Data::Dumper;
use Getopt::Long;
use Log::Log4perl;
use DBI;
use File::Spec qw();
use File::Copy;
use File::Path;
use Fcntl ':flock';
use mmTtime; # can we get away from this, please? FIXME


# Parse cmd line params
my ($pidFile, $logFile, $config_file_or_dir);
GetOptions ('pid|p=s'  => \$pidFile,                # name of pid file - if given, run as daemon
            'log|l=s'  => \$logFile,                # redirect STDERR and STDOUT here
            'config=s' => \$config_file_or_dir,     # path to config dir/file
);

usage() unless $pidFile && $logFile;

if(!Metamod::Config->config_found($config_file_or_dir)){
    print STDERR "Could not find the configuration on the commandline or the in the environment\n";
    exit 3;
}

my $logger = Log::Log4perl->get_logger('metamod.thredds.create_thredds_catalogs');
my $config = new Metamod::Config($config_file_or_dir);
my $dbname = $config->get("DATABASE_NAME");
my $user   = $config->get("PG_ADMIN_USER");
my $opendap_directory = $config->get("OPENDAP_DIRECTORY");
my $opendap_url = $config->get("OPENDAP_URL");
my $webrun_directory = $config->get("WEBRUN_DIRECTORY");

#
# setup thredds environment
#
foreach ( qw(THREDDS_CATALOG_FILE THREDDS_CATALOG_DIR THREDDS_CATALOG_NAME THREDDS_TOP_DATASET_NAME) ) {
	die "Missing directive $_ in master_config" unless $config->has($_);
}
my $thredds_config_path = $webrun_directory . "/thredds_config";
my $thredds_catalog_name = $config->get("THREDDS_CATALOG_NAME");
my $thredds_top_dataset_name = $config->get("THREDDS_TOP_DATASET_NAME");
#my $java_home = $config->get("JAVA_HOME");
#my $catalina_home = $config->get("CATALINA_HOME");
my $catalog_file = $config->get("THREDDS_CATALOG_FILE");
my $catalog_dir = $config->get("THREDDS_CATALOG_DIR");
my $thredds_catalog_path = "$catalog_dir/$catalog_file";
my $path_to_syserrors = $webrun_directory . "/syserrors";
my $old_catalog_signature = "";
my %old_catalog_hash = ();

#
# start daemon
#
our $SIG_TERM = 0;

eval {
   Metamod::Utils::daemonize($logFile, $pidFile);
   $SIG{TERM} = \&sigterm;
   while (!$SIG_TERM) {
      &main_body();
   }
};
if ($@) {
   $logger->error("ABORTED: " . $@);
} else {
   $logger->info("NORMAL TERMINATION");
}

sub sigterm {
   ++$SIG_TERM;
}

sub main_body {
   my %rolenames_from_config = ();
   my %datasets_to_ignore = ();
   my $minutes_between_runs = 10;
#
#  Slurp in the content of the config file
#
#  Example config file:
#
#  distribution DAMOCLES Restricted to Damocles
#  ignore dataset hirlam12
#  run each 5 minute
#
#   print "--- Reading the configuration file:\n";
   unless (-r $thredds_config_path) {die "Can not read from file: $thredds_config_path\n";}
   open (THREDDSCONFIG,$thredds_config_path);
   undef $/;
   my $thredds_config = <THREDDSCONFIG>;
   $/ = "\n";
   close (THREDDSCONFIG);
#
#  Parse the config file:
#
   my @configlines = split(/\n/m,$thredds_config);
   foreach my $line (@configlines) {
#
#     Ignore comments:
#
#      print "    $line\n";
      if ($line =~ /^\s*#/) {
         next;
      }
      if ($line =~ /([^#]*[^#\\])#/) {
         $line = $1;
      }
#
#     Split line in 'keyword obj rest' (only rest may contain whitespace):
#
      if ($line =~ /^\s*([^ \t]+)\s+([^ \t]+)\s+(.+)\b\s*$/) {
         my $keyword = $1; # First matching ()-expression
         my $obj = $2;
         my $rest = $3;
         if ($keyword eq "distribution") {
            $rolenames_from_config{lc($rest)} = $obj;
         } elsif ($keyword eq "ignore") {
            $datasets_to_ignore{$rest} = 1;
         } elsif ($keyword eq "run") {
            $minutes_between_runs = $rest;
            $minutes_between_runs =~ s/[^0-9].*$//;
            if (length($minutes_between_runs) == 0) {
               $minutes_between_runs = 10;
               $logger->warn("Improper minutes value: $rest. Using default" .
                        " $minutes_between_runs minutes between runs");
            }
         } else {
            die("Syntax error in thredds_config, line: $line");
         }
      } else {
         die("Syntax error in thredds_config, line: $line");
      }
   }
   $rolenames_from_config{"forbidden"} = "FORBIDDEN";
   &inner_loop(\%rolenames_from_config,\%datasets_to_ignore);
   sleep(60*$minutes_between_runs);
}
#
# ----------------------------------------------------------------------------
#
sub inner_loop {
   my ($rolenames_from_config,$datasets_to_ignore) = @_;
#   print "--- inner loop:\n";
#
#  Fetch 'dataref' and 'distribution_statement' from the
#  PostgreSQL database. Extract the dataset name from the 'dataref'
#  string, and set up the hash %dist_statements giving the
#  distribution statement for each dataset.
#
   my $dbname = $config->get("DATABASE_NAME");
   my $user   = $config->get("PG_WEB_USER");
   my $dbh =
     DBI->connect( "dbi:Pg:dbname=" . $dbname . " ". $config->get("PG_CONNECTSTRING_PERL"),
	   $user, "" );
   my %datarefs = ();
   my %distrib_stm = ();
   my $stm = $dbh->prepare("SELECT DataSet.DS_id, MT_name, MD_content " .
      "FROM DataSet, Metadata, DS_Has_MD " .
      "WHERE DS_status = 1 AND DS_parent = 0 " .
      "AND DS_Has_MD.DS_id = DataSet.DS_id AND DS_Has_MD.MD_id = Metadata.MD_id " .
      "AND (MT_name = 'dataref' OR MT_name = 'distribution_statement')");
   $stm->execute();
   while ( my ($dsid, $mtname, $mdcontent) = $stm->fetchrow_array ) {
#      print "    reading from database: $dsid, $mtname, $mdcontent\n";
      if (defined($mdcontent)) {
         if ($mtname eq 'dataref') {
            $datarefs{$dsid} = $mdcontent;
         } else { # $mtname eq 'distribution_statement'
            $distrib_stm{$dsid} = $mdcontent;
         }
      }
   }
   my %dist_statements = ();
   while (my ($dsid,$dref) = each(%datarefs)) {
      my $distribution_stm;
#
#     Datasets with no distribution_statement in the metadata are given
#     a default distribution statment = "forbidden". This is accosiated
#     with the rolename "FORBIDDEN" which is assumed not to exist in the
#     in the Tomcat configuration (tomcat-users.xml).
#
#     This will result in a THREDDS catalog that shows the existence of a
#     dataset, but gives a "FORBIDDEN response" when a user tries to accsess
#     a file in the dataset.
#
      if (exists($distrib_stm{$dsid})) {
         $distribution_stm = $distrib_stm{$dsid};
      } else {
         $distribution_stm = "forbidden";
      }
      if (index($dref,$opendap_url) == 0) {
#
#        String $dref starts with the string $opendap_url.
#        Datasets with other content in $dref (dataref field) are ignored
#
         if ($dref =~ m:/([^/]+)/[^/]*$:) {
            my $dataset = $1;
            if (!exists($datasets_to_ignore->{$dataset})) {
               $dist_statements{$dataset} = $distribution_stm;
            }
         }
      }
   }
#
#  The string $catalog_signature will contain a newline-separated list of
#  "institution/dataset rolename". It is used as a basis for creating the
#  THREDDS catalog, and also as a condenced version ("signature") of the
#  catalog. As a signature, it is used to trace changes in the would-be
#  catalog (the previous signature is stored in the $old_catalog_signature
#  variable). If changes occur, the catalog is written to disk, and the
#  THREDDS Data Server is restarted.
#
   my $catalog_signature = "";
#
#  Loop through all dataset directories within the top
#  OPeNDAP/THREDDS directory:
#
#   print "    traverse subdirectories of the top OPENDAP directory: $opendap_directory\n";
   opendir(OPENDAPDIR,$opendap_directory) ||
         die "Could not open directory $opendap_directory: $!\n";
   foreach my $institution_dir (sort readdir(OPENDAPDIR)) {
      my $inst_dir = "$opendap_directory/$institution_dir";
      if (-d $inst_dir and substr($institution_dir,0,1) ne '.') {
#         print "   found institution directory: $inst_dir\n";
         opendir(INSTITUTIONDIR,$inst_dir) ||
               die "Could not open directory $inst_dir: $!\n";
         my $institution = $inst_dir;
         $institution =~ s|^.*/||mg;
         foreach my $dataset_dir (sort readdir(INSTITUTIONDIR)) {
            my $dset_dir = "$inst_dir/$dataset_dir";
            if (-d $dset_dir and substr($dataset_dir,0,1) ne '.') {
#               print "   found dataset directory: $dset_dir\n";
               my $dataset = $dset_dir;
               $dataset =~ s|^.*/||mg;
               if (exists($dist_statements{$dataset})) {
                  my $distribution_statement = lc($dist_statements{$dataset});
                  if (exists($rolenames_from_config->{$distribution_statement})) {
                     my $rolename = $rolenames_from_config->{$distribution_statement};
                     $catalog_signature .= "$institution/$dataset $rolename\n";
                  } else {
                     $logger->warn("$dset_dir  - No rolename");
                  }
               }
            }
         }
         closedir(INSTITUTIONDIR);
      }
   }
   closedir(OPENDAPDIR);
#
   if ($catalog_signature ne $old_catalog_signature) {
      if (-e $thredds_catalog_path) {
         if (move($thredds_catalog_path,$thredds_catalog_path . "_bcup") == 0) {
            die "Moving $thredds_catalog_path to backup file did not succeed. Error code: $!\n";
         }
      }
      my $new_entry_count = 0;
      my $removed_entry_count = 0;
      if (! -e $catalog_dir) {
         File::Path::mkpath($catalog_dir) or die "Can't make THREDDS catalog directory $catalog_dir";
      }
      open (THREDDSCAT,">$thredds_catalog_path") or die "Could not open THREDDS catalog $thredds_catalog_path";
      flock (THREDDSCAT, LOCK_EX);
      $old_catalog_signature = $catalog_signature;
      $catalog_signature .= "dummy/dummy dummy";
      my @scatalog = split(/\n/,$catalog_signature);
      print THREDDSCAT <<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<catalog name="$thredds_catalog_name"
   xmlns="http://www.unidata.ucar.edu/namespaces/thredds/InvCatalog/v1.0"
   xmlns:xlink="http://www.w3.org/1999/xlink">

<service name="allServices" base="" serviceType="compound">
   <service name="thisDODS" serviceType="OpenDAP" base="/thredds/dodsC/" />
   <service name="httpService" serviceType="HTTPServer" base="/thredds/fileServer/" />
   <service name="wms" serviceType="WMS" base="/thredds/wms/" />
</service>

<dataset name="$thredds_top_dataset_name" ID="$thredds_top_dataset_name">
EOF
      my $prev_institution = "";
      foreach my $line (@scatalog) {
         if ($line ne "") {
            if ($line =~ /^([^ \/]+)\/([^ \/]+) ([^ ]+)$/o) {
               my $institution = $1;
               my $dataset = $2;
               my $rolename = $3;
               if ($institution ne "dummy") {
                  if (exists($old_catalog_hash{$line})) {
                     delete($old_catalog_hash{$line});
                  } else {
#                     print "    New catalog entry: $line\n";
                     $new_entry_count++;
                  }
               }
               if ($institution ne $prev_institution and $prev_institution ne "") {
                  print THREDDSCAT <<'EOF';
</dataset>

EOF
               }
               if ($institution ne $prev_institution and $institution ne "dummy") {
                  print THREDDSCAT <<"EOF";
<dataset name="$institution" ID="$institution">
EOF
               }
               if ($rolename eq "free") {
                  print THREDDSCAT <<"EOF";
<datasetScan name="$dataset" ID="$institution/$dataset"
   path="data/$institution/$dataset" location="$opendap_directory/$institution/$dataset">
   <metadata inherited="true">
      <serviceName>allServices</serviceName>
   </metadata>
   <filter>
      <include wildcard="*" atomic="true" collection="true" />
      <exclude wildcard=".*" />
   </filter>
</datasetScan>
EOF
               } elsif ($rolename ne "dummy") {
                  print THREDDSCAT <<"EOF";
<datasetScan name="$dataset" ID="$institution/$dataset"
   path="data/$institution/$dataset" location="$opendap_directory/$institution/$dataset" restrictAccess="$rolename">
   <metadata inherited="true">
      <serviceName>allServices</serviceName>
   </metadata>
   <filter>
      <include wildcard="*" atomic="true" collection="true" />
      <exclude wildcard=".*" />
   </filter>
</datasetScan>
EOF
               }
               $prev_institution = $institution;
            }
         }
      }
      print THREDDSCAT <<'EOF';
</dataset>

</catalog>
EOF
      close (THREDDSCAT);
#
#     The remaining entries in %old_catalog_hash are those that are removed from
#     the THREDDS catalog:
#
      foreach my $line (keys %old_catalog_hash) {
#          print "    Removed catalog entry: $line\n";
         $removed_entry_count++;
      }
      $logger->info("Writing new THREDDS catalog file: $thredds_catalog_path " .
                    "- adding $new_entry_count removing $removed_entry_count entries");
      %old_catalog_hash = ();
      foreach my $line (@scatalog) {
          if ($line ne "dummy/dummy dummy") {
             $old_catalog_hash{$line} = 1;
          }
      }
#
#     The following code is removed. THREDDS should be restarted
#     independent of METAMOD.
#     Restart the THREDDS server:
#
#      my $datestring = &datestring();
#      print "-- $datestring: Restart the THREDDS server\n";
#      print `JAVA_HOME=$java_home $catalina_home/bin/shutdown.sh 2>&1`;
#      print `JAVA_HOME=$java_home $catalina_home/bin/startup.sh 2>&1`;
   }
}
#
# ----------------------------------------------------------------------------
#
sub syserror {
   my ($errmsg,$where) = @_;
   my $datestring = &datestring();
#
   open (OUT,">>$path_to_syserrors");
   flock (OUT, LOCK_EX);
   print OUT "-------- Create_thredds_catalog $datestring IN: $where\n" .
             "         $errmsg\n";
   close (OUT);
}
#
# ----------------------------------------------------------------------------
#
sub datestring {
   my @ta = localtime();
   my $year = 1900 + $ta[5];
   my $mon = $ta[4] + 1; # 1-12
   my $mday = $ta[3]; # 1-31
   my $hour = $ta[2]; # 0-23
   my $min = $ta[1]; # 0-59
   return sprintf ('%04d-%02d-%02d %02d:%02d',$year,$mon,$mday,$hour,$min);
}

sub usage {
    print STDERR "usage: $0 --pid PIDFILE --log LOGFILE [--config FILE_OR_DIR]";
    exit(1);
}
