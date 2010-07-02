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

package Metamod::InitLogger;

use strict;
use warnings;

use Log::Log4perl;

use Metamod::Config;

our $init_performed = 0;

sub init_logger {

    if( $init_performed ){
        return;
    }

    my $config = Metamod::Config->new();

    my $log_config = $config->get( 'LOG4PERL_CONFIG' );
    my $system_log = $config->get( 'LOG4ALL_SYSTEM_LOG' );
    my $reinit_period = $config->get( 'LOG4PERL_WATCH_TIME' ) || 10;

    $ENV{ 'METAMOD_SYSTEM_LOG' } = $system_log;

    Log::Log4perl->init_and_watch( $log_config, $reinit_period );

    $init_performed = 1;
    return 1;

}

1;
__END__

=head1 NAME

Metamod::InitLogger - Wrapper around the Log::Log4perl initialisation.

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

