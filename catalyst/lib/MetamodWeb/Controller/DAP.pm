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
use JSON::Any;
use Fcntl;

use MetNo::Fimex;
use PDL;
use PDL::NetCDF;
#use PDL::Char;
# PDF barfs out following warning on start which seems to conflict with Catalyst inner workings... ignore for now:
# Prototype mismatch: sub MetamodWeb::Controller::DAP::inner: none vs (;@) at /usr/local/lib/perl/5.10.1/PDL/Exporter.pm line 64

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

Example: /ts/5435/json

=cut

sub ts :Path("/ts") :Args(3) {
    my ( $self, $c, $ds_id, $varlist, $format ) = @_;

    my @vars = split ',', $varlist;
    #print STDERR Dumper \@vars;

    $MetNo::Fimex::DEBUG = 0; # turn off debug or nothing will happen
    my $tmpdir = File::Spec->tmpdir();
    my $tmpfile = sprintf "mmDAP_%d_%d.nc", $$, time ;
    # make sure not to clobber if more than one request per sec per process
    my $bis = 0;
    while (-e "$tmpdir/$tmpfile") {
        $tmpfile = sprintf "fimex_%d_%d_%d.nc", $$, time, ++$bis ;
    }

    my $ds = $c->model('Metabase::Dataset')->find($ds_id) or $c->detach('Root', 'default');

    my $urls = $ds->metadata()->{'dataref_OPENDAP'} or $c->detach('Root', 'default');
    my $url = shift @$urls;

    # setup fimex to fetch data via opendap
    my $f = new MetNo::Fimex(
        dapURL => $url,
        outputFile => $tmpfile,
        outputDirectory => $tmpdir,
        program => '/usr/bin/fimex',
    );
    eval { $f->doWork() };
    if ($@) {
        $self->logger->warn("FIMEX runtime error: $@");
        $c->detach( 'Root', 'error', [ 502, "FIMEX runtime error: $@"] );
    }

    # parse netcdf resulting file
    my $nc = PDL::NetCDF->new ( "$tmpdir/$tmpfile", {MODE => O_RDONLY} )
        or $c->detach( 'Root', 'error', [ 500, "Can not parse NetCDF file $tmpdir/$tmpfile"] );
        # add logger - FIXME

    my $title = $nc->getatt('title');
    my (%data, %units);
    foreach (@{ $nc->getvariablenames }) { # fetch data from db
        #print STDERR "+++ $_\n";
        my @v = list( $nc->get($_) );
        my $name = $nc->getatt('standard_name', $_); # TODO also check long_name, short_name
        next unless grep /^$name$/, @vars; # skip vars not in request
        $units{$name} = $nc->getatt('units', $_);
        $data{$name} = \@v;
    }

    foreach (@vars) { # check that all variables actually exist
        $c->detach( 'Root', 'error', [ 400, "No such variable '$_'"] )
            unless $data{$_};
    }

    if (grep /^time$/, @vars) { # convert times to ISO
        my @isotime;
        foreach (@{ $data{'time'} }) {
            my $dt = DateTime->from_epoch( epoch => $_ );
            push @isotime, $dt->ymd . 'T' . $dt->hms;;
        }
        $data{'time'} = \@isotime;
    }

    #print STDERR Dumper \%data;

    # output stuff
    if ($format eq 'json') {

        my $j = JSON::Any->new;
        my $json = $j->encode( \%data );
        $c->response->content_type('application/json');
        $c->response->body( $json );

    } elsif ($format eq 'csv') {

        # push column headings first on list
        foreach (@vars) {
            unshift @{ $data{$_} }, /^time$/ ? $_ : "$_ ($units{$_})";
        }

        # rearrange from hash of arrays into table of rows
        my $out;
        my $rows = $nc->dimsize('time');
        for (my $i = 0; $i <= $rows; $i++) {
            my @cells = map $data{$_}->[$i], @vars;
            $out .= join("\t", @cells) . "\n";
        }
        $c->response->content_type('text/plain');
        $c->response->body( $out );

    }

    # cleanup (should probably also be done when detaching... FIXME)
    $self->logger->debug("Deleting temp fimex file $tmpfile");
    $nc->close;
    unlink("$tmpdir/$tmpfile") or $self->logger->error("Could not delete temp file $tmpfile");

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
