package MetamodWeb::Controller::DAP;

=begin LICENSE

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

=head1 NAME

MetamodWeb::Controller::DAP - Catalyst controller for OPenDAP functions

=head1 DESCRIPTION

Use this to extract data from external servers using OPenDAP and FIMEX.
The latter must be installed and compiled with DAP support in libnetcdf
(see https://wiki.met.no/fimex/install).

=cut

use Moose;
use namespace::autoclean;
use Data::Dumper;
#use Try::Tiny;
use File::Spec;
use DateTime;
use JSON;
use Fcntl;

use MetNo::Fimex;
use MetNo::NcFind;
#use PDL;
#use PDL::NetCDF;
#use PDL::Char;
# PDF barfs out following warning on start which seems to conflict with Catalyst inner workings... ignore for now:
# Prototype mismatch: sub MetamodWeb::Controller::DAP::inner: none vs (;@) at /usr/local/lib/perl/5.10.1/PDL/Exporter.pm line 64
# using PDL qw() gives Caught exception in MetamodWeb::Controller::DAP->ts:
# "Undefined subroutine &PDL::Ops::assgn called at Basic/Core/Core.pm.PL (i.e. PDL::Core.pm) line 854."


BEGIN { extends 'MetamodWeb::BaseController::Base'; }


sub auto :Private {
    my ( $self, $c ) = @_;

    $c->stash( wmc => MetamodWeb::Utils::XML::WMC->new( { c => $c } ));
}


=head1 METHODS

=head2 /ts

Output timeseries data from given dataset via webservice

Arguments:

=head3 ds_id

Numerical id of dataset

=head3 vars

Comma separated list of variables (the first is the X axis and should normally be time)

=head3 format

Either "json" or "csv" (comma separated with header row)

Example: /ts/5435/time,ice_concentration/json

=cut

sub ts :Path("/ts") :Args(3) {
    my ( $self, $c, $ds_id, $varlist, $format ) = @_;

    my $config = Metamod::Config->instance();
    my $fimexpath = $config->get('FIMEX_PROGRAM')
        or $c->detach( 'Root', 'error', [ 501, "Not available without FIMEX installed"] );

    my @vars = split ',', $varlist;
    #print STDERR Dumper \@vars;

    $MetNo::Fimex::DEBUG = 0; # turn off debug or nothing will happen

    my $ds = $c->model('Metabase::Dataset')->find($ds_id) or $c->detach('Root', 'default');
    my $dapurl = $ds->metadata()->{'dataref_OPENDAP'}->[0] or $c->detach('Root', 'default');

    # setup fimex to fetch data via opendap
    my $f = new MetNo::Fimex(
        dapURL => $dapurl,
        program => $fimexpath,
    );
    eval { $f->doWork() };
    if ($@) {
        $self->logger->warn("FIMEX runtime error: $@");
        $c->detach( 'Root', 'error', [ 502, "FIMEX runtime error: $@"] );
    }

    my $ncfile = $f->outputPath;
    # parse netcdf resulting file
    #my $nc = PDL::NetCDF->new ( $ncfile, {MODE => O_RDONLY} );
    my $nc2 = MetNo::NcFind->new($ncfile);
    if (! $nc2) {
        $self->logger->warn("Can not parse NetCDF file $ncfile");
        $c->detach( 'Root', 'error', [ 500, "Can not parse NetCDF file $ncfile"] );
    }

    #my $title = $nc->getatt('title');
    #my $title2 = $nc2->globatt_value('title');

    ## PDL version
    #my (%data, %units);
    #foreach (@{ $nc->getvariablenames }) { # fetch data from db
    #    print STDERR "+++ $_\n";
    #    my @v = list( $nc->get($_) );
    #    my $name = $nc->getatt('standard_name', $_); # TODO also check long_name, short_name
    #    next unless grep /^$name$/, @vars; # skip vars not in request
    #    $units{$name} = $nc->getatt('units', $_);
    #    $data{$name} = \@v;
    #}
    ##print STDERR Dumper \%data, \%units;

    # Metno::NcFind version
    my (%data2, %units2);
    foreach ($nc2->variables) { # fetch data from db
        #print STDERR "+++ $_\n";
        my @v = $nc2->get_values($_);
        my $name = $nc2->att_value($_, 'standard_name'); # TODO also check long_name, short_name
        next unless grep /^$name$/, @vars; # skip vars not in request
        $units2{$name} = $nc2->att_value($_, 'units');
        $data2{$name} = \@v;
    }
    #print STDERR Dumper \%data2, \%units2;

    foreach (@vars) { # check that all variables actually exist
        $c->detach( 'Root', 'error', [ 400, "No such variable '$_'"] )
            unless $data2{$_};
    }

    if (grep /^time$/, @vars) { # convert times to ISO
        my @isotime;
        foreach (@{ $data2{'time'} }) {
            #print STDERR "++++++++++++++++ $_\n";
            my $dt = DateTime->from_epoch( epoch => $_ );
            push @isotime, $dt->ymd . 'T' . $dt->hms;;
        }
        $data2{'time'} = \@isotime;
    }

    # output stuff
    if ($format eq 'json') {

        my $j = JSON->new->utf8;
        my $json = $j->encode( \%data2 );
        $c->response->content_type('application/json');
        $c->response->body( $json );

    } elsif ($format eq 'csv') {

        # push column headings first on list
        foreach (@vars) {
            unshift @{ $data2{$_} }, /^time$/ ? $_ : "$_ ($units2{$_})";
        }

        # rearrange from hash of arrays into table of rows
        my $out;
        my $rows = $nc2->dimensionSize('time'); #$nc->dimsize('time');
        for (my $i = 0; $i <= $rows; $i++) {
            my @cells = map $data2{$_}->[$i], @vars;
            $out .= join("\t", @cells) . "\n";
        }
        $c->response->content_type('text/plain');
        $c->response->body( $out );

    }

    # cleanup (should probably also be done when detaching... FIXME)
    $self->logger->debug("Deleting temp fimex file $ncfile");
    #$nc->close;
    unlink($ncfile) or $self->logger->error("Could not delete temp file $ncfile");

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
