#!/usr/bin/perl

=begin LICENCE

----------------------------------------------------------------------------
  METAMOD - Web portal for metadata search and upload

  Copyright (C) 2011 met.no

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
----------------------------------------------------------------------------

=end LICENCE

=cut

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../common/lib";
use lib "$FindBin::Bin/../lib";

use Metamod::Config;

if( @ARGV != 1 ) {
    print STDERR "usage $0 <path to config directory>\n";
    exit 1;
}

my $config_directory = shift @ARGV;
if( !( -e $config_directory ) || !( -r $config_directory ) ){
    print STDERR "'$config_directory' does not exist or is not readable\n";
    exit 1;
}

my $master_config_file = "$config_directory/master_config.txt";
if( !( -e $master_config_file ) || !( -r $master_config_file ) ){
    print STDERR "'$master_config_file' does not exist or is not readable\n";
    exit 1;
}

my $config = Metamod::Config->new($master_config_file);

my @configVars = $config->getVarNames();

my $bash_script = '';
foreach my $var_name (@configVars){

    # avoid the config vars with strange names
    next if !( $var_name =~ /^\w+$/ );

    my $value = $config->get($var_name);

    # multi line strings must be treated differently.
    if( !($value =~ /\n/) ){
        $value =~ s/'/'\\''/g;
        $bash_script .= qq{$var_name='$value'\n};
    } else {
        $bash_script .= <<"END_MULTILINE";
read -d '' $var_name <<"EOF"
$value
EOF
END_MULTILINE

    }


}

# Uncomment if you want write the results to a file.
#open my $FILE, '>', 'config.sh';
#print $FILE $bash_script;
#close $FILE;

print $bash_script;

=head1 NAME

B<gen_bash_conf.pl> - Generate a bash script that creates one bash variable for each config variable

=head1 DESCRIPTION

Generates a bash script with one variable for each variable in the
master_config.txt file. The default master_config.txt file (decided by
C<Metamod::Config>) will be used. Or you can override the default by setting
the environment. See C<Metamod::Config> for details.

=head1 USAGE

 gen_bash_conf.pl

=head1 LICENSE

Copyright (C) 2010 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
