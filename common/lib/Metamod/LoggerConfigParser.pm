#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2010 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: oystein.torget@met.no
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

package Metamod::LoggerConfigParser;

use strict;
use warnings;

use POSIX qw( strftime );

sub new {
    my ($class, $options) = @_;

    my $self = bless {}, $class;

    $self->{ _verbose } = $options->{ verbose };

    return $self;

}

sub read_meta_files {
    my ($self, @meta_files) = @_;

    my $config_string = '';
    foreach my $filename ( @meta_files ){

        print "Reading meta file '$filename'\n" if $self->{ _verbose };
        my $success = open my $META_FILE, '<', $filename;
        if( !$success ){
            print STDERR "Failed to open the meta file '$filename': $!\n";
            print STDERR "Skipping file\n";
            next;
        }

        $config_string = do { local $/; <$META_FILE> };

    }

    return $config_string;
}

sub create_perl_config {
    my ($self,$config_string) = @_;

    $config_string =~ s/^log4all/log4perl/mg;

    my @lines = split( "\n", $config_string );
    my $perl_config = '# Generated with Metamod::LoggerConfigParser on ' . $self->_timestamp() ."\n";
    foreach my $line ( @lines ){

        if( $line =~ /^log4perl/ ){
            $perl_config .= $line . "\n";
        }

    }

    return $perl_config;

}

sub create_php_config {
    my ($self,$config_string) = @_;

    $config_string =~ s/^log4all/log4php/mg;

    my @lines = split( "\n", $config_string );
    my $php_config = '# Generated with Metamod::LoggerConfigParser on ' . $self->_timestamp() . "\n";
    foreach my $line ( @lines ){

        if( $line =~ /^log4php/ ){
            $php_config .= $line . "\n";
        }

    }

    return $php_config;
}

sub _timestamp {
    my ($self) = @_;

    return strftime('%Y-%m-%d %H:%M:%S', localtime);

}


1;