#!/usr/bin/perl -w
# 
#---------------------------------------------------------------------------- 
#  METAMOD - Web portal for metadata search and upload 
# 
#  Copyright (C) 2008 met.no 
# 
#  Contact information: 
#  Norwegian Meteorological Institute 
#  Box 43 Blindern 
#  0313 OSLO 
#  NORWAY 
#  email: egil.storen@met.no 
#   
#  This file is part of METAMOD 
# 
#  METAMOD is free software; you can redistribute it and/or modify 
#  it under the terms of the GNU General Public License as published by 
#  the Free Software Foundation; either version 2 of the License, or 
#  (at your option) any later version. 
# 
#  METAMOD is distributed in the hope that it will be useful, 
#  but WITHOUT ANY WARRANTY; without even the implied warranty of 
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
#  GNU General Public License for more details. 
#   
#  You should have received a copy of the GNU General Public License 
#  along with METAMOD; if not, write to the Free Software 
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA 
#---------------------------------------------------------------------------- 
#
#
#  Update static search data in the database from an XML file.
#
# use strict;
use XML::Simple qw(:strict);
# use Data::Dumper;
use DBI;
if (scalar @ARGV != 1) {
   die "\nUsage:\n\n     $0 name_of_xml_file\n\n";
}
my $searchdataxml = $ARGV[0];
#
#  Connect to PostgreSQL database:
#
my $dbname = "[==DATABASE_NAME==]";
my $user = "admin";
local $dbh = DBI->connect("dbi:Pg:dbname=" . $dbname . " [==PG_CONNECTSTRING_PERL==]", $user, "");
#
#  Use full transaction mode. The changes has to be committed or rolled back:
#
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;
#
#  Initialize log array. This will be appended to the logfile at
#  the end of a successful run.
#
local @logarr = ();
#
#  Set up a conversion table (hash) for 
#  converting characters >159 to HTML entities:
#
my %html_conversions = ();
for (my $jnum=160; $jnum < 256; $jnum++) {
   $html_conversions{chr($jnum)} = '&#' . $jnum . ';';
}
#
#  Evaluate block to catch runtime errors
#  (including "die()")
#
eval {
   &update_database;
};
#
#  Check error string returned from eval
#  If not empty, an error has occured
#
if ($@) {
   warn $@;
   $dbh->rollback or die $dbh->errstr;
   my $datestamp = localtime;
   @logarr = ("========= $datestamp: Load static searchdata failed. =========",
              "          Database rolled back",
              "          " . $@);
} else {
   $dbh->commit or die $dbh->errstr;
   $dbh->disconnect or warn $dbh->errstr;
   push (@logarr,"========= Load static searchdata finished");
}
open (LOG,">>[==LOGFILE==]");
foreach my $line (@logarr) {
   print LOG $line . "\n";
}

# ------------------------------------------------------------------
sub update_database {
#
#  Convert XML file to a hash (using XML::Simple):
#  First, read the whole XML file into the string variable $xmlcontent. Then
#  substitute all occurences of '&' with '&amp;'. Otherwise, XML::Simple
#  will decode all XML entities into their Latin-1 equivalents.
#  The XML entities should be preserved to avoid difficult-to-debug character
#  conversions while the text is sent to the database and later retrieved.
#
   unless (-r $searchdataxml) {die "Can not read from file: $searchdataxml\n";}
#
#   open (XMLINPUT,$searchdataxml);
#   undef $/;
#   my $xmlcontent = <XMLINPUT>;
#   $/ = "\n"; 
#   close (XMLINPUT);
#   $xmlcontent =~ s/&/&amp;/mg;
   my $xmlref = XMLin($searchdataxml,
                   KeyAttr => { sc => "id",
                                hkhead => "sc",
                                hk => "name",
                                mt => "name"
                              },
                   ForceArray => 1);
#   print Dumper($xmlref);
#   return;
#
   my $datestamp = localtime;
   push (@logarr,"========== Load static search data. $datestamp ==========");
#
#  Create hash with all static search data in the database:
#
   local %searchdata = ();
   local @ancestors = ();
   my $stm;
   $stm = $dbh->prepare("SELECT SC_id FROM SearchCategory");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      my $key1 = "SC:" . join(":",@row);
      $searchdata{$key1} = 1;
   }
   $stm = $dbh->prepare("SELECT BK_id, SC_id, BK_name FROM BasicKey");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      my $bkid = shift(@row);
      my $key1 = "BK:" . join(":",@row);
      $searchdata{$key1} = $bkid;
   }
   $stm = $dbh->prepare("SELECT HK_id, SC_id, HK_parent, HK_name FROM HierarchicalKey");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      my $hkid = shift(@row);
      my $key1 = "HK:" . join(":",@row);
      $searchdata{$key1} = $hkid;
   }
   $stm = $dbh->prepare("SELECT MT_name FROM MetadataType");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      my $key1 = "MT:" . join(":",@row);
      $searchdata{$key1} = 1;
   }
   $stm = $dbh->prepare("SELECT HK_id, BK_id FROM HK_Represents_BK");
   $stm->execute();
   while ( my @row = $stm->fetchrow_array ) {
      my $key1 = "HKBK:" . join(":",@row);
      $searchdata{$key1} = 1;
   }
#
#  Prepare SQL statements for repeated use.
#  Use "?" as placeholders in the SQL statements:
#
   local $sql_insert_SC = $dbh->prepare(
      "INSERT INTO SearchCategory (SC_id, SC_type, SC_fnc) VALUES (?, ?, ?)");
   local $sql_getkey_BK = $dbh->prepare("SELECT nextval('BasicKey_BK_id_seq')");
   local $sql_insert_BK = $dbh->prepare(
      "INSERT INTO BasicKey (BK_id, SC_id, BK_name) VALUES (?, ?, ?)");
   local $sql_insert_MT = $dbh->prepare(
      "INSERT INTO MetadataType (MT_name, MT_share, MT_def) VALUES (?, ?, ?)");
   local $sql_getkey_HK = $dbh->prepare("SELECT nextval('HierarchicalKey_HK_id_seq')");
   local $sql_insert_HK = $dbh->prepare(
      "INSERT INTO HierarchicalKey (HK_id, HK_parent, SC_id, HK_level, HK_name) " .
      "VALUES (?, ?, ?, ?, ?)");
   local $sql_insert_HKBK = $dbh->prepare(
      "INSERT INTO HK_Represents_BK (HK_id, BK_id) VALUES (?, ?)");
#
# Loop through a given level of tags 
# rooted in a hash reference $xmlref.
# Each $ref1 is a new reference to HASH, ARRAY or SCALAR
#
   foreach my $key1 (keys %$xmlref) {
      my $ref1 = $xmlref->{$key1};
      if ($key1 eq "sc") {
#      
#        Check if reference is a HASH
#      
         if (ref($ref1) ne "HASH") {
            die "$0: XML hash: Top level value (key 'sc') is not a hash reference\n";
         }
#         
#       Loop through all SearchCategories in the XML file:
#       
         foreach my $key2 (keys %$ref1) {
            my $ref2 = $ref1->{$key2};
#            
#           Execute prepared SQL statement
#           Each argument below replaces a "?" placeholder in the $sqlstatement:
#            
            if (ref($ref2) ne "HASH") {
               die "$0: XML hash: sc element is not a hash reference\n";
            }
            if (! exists($searchdata{"SC:" . $key2})) {
               my $type = $ref2->{"type"};
               my $fnc = $ref2->{"fnc"};
               $sql_insert_SC->execute($key2,$type,$fnc);
               $searchdata{"SC:" . $key2} = 1;
#               push (@logarr,"Added to SC: $key2,$type,$fnc");
            }
         }
      } elsif ($key1 eq "hkhead") {
#      
#        Check if reference is a HASH
#      
         if (ref($ref1) ne "HASH") {
            die "$0: XML hash: Top level value (key 'hkhead') is not a hash reference\n";
         }
#      
#       Loop through a given level of tags
#      
         foreach my $scid (keys %$ref1) {
            my $ref2 = $ref1->{$scid};
#         
#           Check if reference is a HASH
#         
            if (ref($ref2) ne "HASH") {
               die "$0: XML hash: 'hkhead' element is not a hash reference\n";
            }
            if (!exists($ref2->{'hk'})) {
               die "$0: XML hash: 'hk' element not found in 'hkhead'\n";
            }
            my $ref3 = $ref2->{'hk'};
            my $level = 1;
#         
#           Subroutine call: hkloop
#         
            &hkloop($level,$ref3,$scid,0);
         }
      } elsif ($key1 eq "bk") {
         if (ref($ref1) ne "ARRAY") {
            die "$0: XML hash: Top level value (key 'bk') is not an array reference\n";
         }
#      
#       Loop through all 'bk' elements at the top XML level
#      
         foreach my $ref2 (@$ref1) {
            if (ref($ref2) ne "HASH") {
               die "$0: XML hash: Error in 'bk' element at the top XML level\n";
            }
            my $name = &convert_to_htmlentities($ref2->{'content'},\%html_conversions);
            my $scid = $ref2->{'sc'};
            if (! exists($searchdata{"BK:" . $scid . ":" . $name})) {
#         
#           Get new primary key ($bkid) and insert into the BasicKey table:
#         
               $sql_getkey_BK->execute();
               my @result = $sql_getkey_BK->fetchrow_array;
               my $bkid = $result[0];
               $sql_insert_BK->execute($bkid,$scid,$name);
               $searchdata{"BK:" . $scid . ":" . $name} = $bkid;
#               push (@logarr,"Added to BK: $bkid,$scid,$name");
            }
         }
      } elsif ($key1 eq "mt") {
         if (ref($ref1) ne "HASH") {
            die "$0: XML hash: Top level value (key 'mt') is not a hash reference\n";
         }
#      
#       Loop through all 'mt' elements at the top XML level
#      
         foreach my $name (keys %$ref1) {
            my $ref2 = $ref1->{$name};
            if (ref($ref2) ne "HASH" || !exists($ref2->{'def'})) {
               die "$0: XML hash: Error in 'mt' element\n";
            }
#         
#           Execute prepared SQL statement
#         
            my $def = &convert_to_htmlentities($ref2->{'def'},\%html_conversions);
            my $share = $ref2->{'share'};
            if (! exists($searchdata{"MT:" . $name})) {
               $sql_insert_MT->execute($name,$share,$def);
               $searchdata{"MT:" . $name} = 1;
#               push (@logarr,"Added to MT: $name,$share,$def");
            }
         }
      }
   }
}
# ------------------------------------------------------------------
#
#  Recursive subroutine to digest 'hk' tags inside toplevel 'hkhead' tags:
#  -----------------------------------------------------------------------
#
sub hkloop {
#   
#     Split argument array into variables
#   
   my ($level,$ref1,$scid,$hkparent) = @_;
   $ancestors[$level] = $hkparent;
#   
#    Loop through all 'hk' tags at the current level
#   
   foreach my $name (keys %$ref1) {
      my $ref2 = $ref1->{$name};
#
#        Get primary key for HK ($hkid):
#
      my $hkid;
      my $hashkey = "HK:" . $scid . ":" . $hkparent . ":" . $name;
      if (! exists($searchdata{$hashkey})) {
         $sql_getkey_HK->execute();
         my @result = $sql_getkey_HK->fetchrow_array;
         $hkid = $result[0];
         $sql_insert_HK->execute($hkid,$hkparent,$scid,$level,$name);
         $searchdata{$hashkey} = $hkid;
#         push (@logarr,"Added to HK: $hkid,$hkparent,$scid,$level,$name");
      } else {
         $hkid = $searchdata{$hashkey};
      }
#      
#       The next level in the XML hash is either a reference to a set
#       of 'hk' nodes (one level below current node), a reference to a
#       set of 'bk' nodes or both:
#      
      foreach my $key1 (keys %$ref2) {
         my $ref3 = $ref2->{$key1};
         if ($key1 eq "hk") {
#            
#              Recursive call to hkloop:
#            
            &hkloop($level+1,$ref3,$scid,$hkid);
         } elsif ($key1 eq "bk") {
#            
#             Loop through all 'bk' elements within a 'hk' element:
#            
            foreach my $ref4 (@$ref3) {
               if (ref($ref4) ne "HASH") {
                  die "$0: XML hash: Error in 'bk' element within a 'hk' element\n";
               }
#               
#                 Get primary key for BasicKey ($bkid):
#               
               my $bkid;
               my $name = &convert_to_htmlentities($ref4->{'content'},\%html_conversions);
               my $scid = $ref4->{'sc'};
               my $hashkey = "BK:" . $scid . ":" . $name;
               if (! exists($searchdata{$hashkey})) {
                  $sql_getkey_BK->execute();
                  my @result = $sql_getkey_BK->fetchrow_array;
                  $bkid = $result[0];
                  $sql_insert_BK->execute($bkid,$scid,$name);
                  $searchdata{$hashkey} = $bkid;
#                  push (@logarr,"Added to BK: $bkid,$scid,$name");
               } else {
                  $bkid = $searchdata{$hashkey};
               }
#
               if (! exists($searchdata{"HKBK:" . $hkid . ":" . $bkid})) {
#
#                    Add to HK_represent_BK relationship:
#
                  $sql_insert_HKBK->execute($hkid,$bkid);
                  $searchdata{"HKBK:" . $hkid . ":" . $bkid} = 1;
#                  push (@logarr,"Added to HKBK: $hkid,$bkid");
               }
               for (my $lev=$level; $lev > 1; $lev--) {
                  my $hkid1 = $ancestors[$lev];
                  if (! exists($searchdata{"HKBK:" . $hkid1 . ":" . $bkid})) {
#
#                    Add to HK_represent_BK relationship:
#
                     $sql_insert_HKBK->execute($hkid1,$bkid);
                     $searchdata{"HKBK:" . $hkid1 . ":" . $bkid} = 1;
#                     push (@logarr,"Added to HKBK: $hkid1,$bkid");
                  }
               }
            }
         }
      }
   }
}
#
#---------------------------------------------------------------------------------
#
sub convert_to_htmlentities {
   my ($str,$conversions) = @_;
   my @contarr = split(//,$str);
   my $result = "";
   foreach my $ch1 (@contarr) {
      if (exists($conversions->{$ch1})) {
         $result .= $conversions->{$ch1};
      } else {
         $result .= $ch1;
      }
   }
   return $result;
};
