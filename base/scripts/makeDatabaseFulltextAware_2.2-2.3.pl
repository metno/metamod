#!/usr/bin/perl -w
# 
#---------------------------------------------------------------------------- 
#  METAMOD - Web portal for metadata search and upload 
# 
#  Copyright (C) 2009 met.no 
# 
#  Contact information: 
#  Norwegian Meteorological Institute 
#  Box 43 Blindern 
#  0313 OSLO 
#  NORWAY 
#  email: heiko.klein@met.no 
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
use strict;
use warnings;
use File::Spec;

# small routine to get lib-directories relative to the installed file
sub getTargetDir {
    my ($finalDir) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
    $dir = $dir ? File::Spec->catdir($dir, "..") : File::Spec->updir();
    $dir = File::Spec->catdir($dir, $finalDir); 
    return File::Spec->catpath($vol, $dir, "");
}

use lib ('../../common/lib', getTargetDir('lib'), getTargetDir('scripts'), '.');

use DBI;
use Metamod::Config;
my $config = new Metamod::Config();

#
#  Connect to PostgreSQL database:
#
my $dbname = $config->get("DATABASE_NAME");
my $user = $config->get("PG_ADMIN_USER");
my $dbh = DBI->connect("dbi:Pg:dbname=" . $dbname . " ".$config->get("PG_CONNECTSTRING_PERL"), $user, "");
#
#  Use full transaction mode. The changes has to be committed or rolled back:
#
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

my $selectSth = $dbh->prepare("SELECT MD_id, MD_content FROM Metadata");
# add the ts2search vector 
my $updateSth = $dbh->prepare("UPDATE Metadata SET MD_content_vector = to_tsvector(?) WHERE MD_id = ?");

$selectSth->execute;
while (my ($mdId, $mdContent) = $selectSth->fetchrow_array) {
    $updateSth->execute($mdContent, $mdId);	
    print STDERR "updated $mdId\n";
}
$dbh->commit;
$dbh->disconnect;
