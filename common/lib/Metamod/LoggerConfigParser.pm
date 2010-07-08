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

use Metamod::Config;

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

sub write_perl_config {
    my ($self,$config,$filename) = @_;

    my $success = open my $PERL_CONFIG, '>', $filename;
    if(!$success){
        die "Could not write Perl logger config to '$filename': $!";
    }
    print $PERL_CONFIG, $config;
    close $PERL_CONFIG;

}

sub write_php_config {
    my ($self,$config,$filename) = @_;

    my $success = open my $PHP_CONFIG, '>', $filename;
    if(!$success){
        die "Could not write PHP logger config to '$filename': $!";
    }
    print $PHP_CONFIG, $config;
    close $PHP_CONFIG;

}

sub create_and_write_configs {
    my ($self,$master_config,@meta_files) = @_;

    my $mm_config = Metamod::Config->new($master_config);
    my $log4perl_config_file = $mm_config->get('LOG4PERL_CONFIG');
    my $log4php_config_file = $mm_config->get('LOG4PHP_CONFIG');

    my $config_string = $self->read_meta_files(@meta_files);
    my $log4perl_config = $self->create_perl_config($config_string);
    my $log4php_config = $self->create_php_config($config_string);

    $self->write_perl_config($log4perl_config,$log4perl_config_file);
    $self->write_php_config($log4php_config,$log4php_config_file);

    return;

}




1;