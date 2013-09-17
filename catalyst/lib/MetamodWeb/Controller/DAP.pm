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

    my @params = split ',', $varlist;
    my $x_axis = $params[0];
    my @vars; # we need this to remember the column order
    my %cols;
    foreach (@params) {
        /^(\w+)(\[(\d+)\])?$/ or die; # pick out name and optionally index
        unless (exists $cols{$1}) {
            $cols{$1} = [];
            push @vars, $1; # store only once if multicol
        }
        push @{ $cols{$1} }, $3 if $3; # empty if single array
    }
    #print STDERR "vars: ", Dumper \@vars, \@params, \%cols;

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
    #my $nc = PDL::NetCDF->new ( $ncfile, {MODE => O_RDONLY} ); # PDF method has been deprecated
    my $nc2 = MetNo::NcFind->new($ncfile);
    if (! $nc2) {
        $self->logger->warn("Can not parse NetCDF file $ncfile");
        $c->detach( 'Root', 'error', [ 500, "Can not parse NetCDF file $ncfile"] );
    }

    #my $title = $nc->getatt('title');
    #my $title2 = $nc2->globatt_value('title'); # doesn't seem to be in use anywhere

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
    foreach ($nc2->variables) { # fetch all variables from db since need to lookup names
        #print STDERR "+++ $_\n";
        my @dim = $nc2->dimensions($_);
        my $name = $nc2->att_value($_, 'standard_name'); # TODO also check long_name, short_name
        $name = $_ if $name eq 'Not available';
        next unless exists $cols{$name}; # skip vars not in request
        #print STDERR "name = $name [", join(', ', @dim), "]\n";
        $data2{$name} = {};
        foreach my $d (@dim) {
            #my @v = $nc2->get_values($_);
            #$data2{$name}{$d} = \@v;
            next unless $d eq $x_axis;
            $data2{$name} = $nc2->get_struct($_);
        }
        $units2{$name} = $nc2->att_value($_, 'units');
    }
    #print STDERR Dumper \%data2, \%units2;

    foreach (keys %cols) { # check that all variables actually exist
        $c->detach( 'Root', 'error', [ 400, "No such variable '$_'"] )
            unless $data2{$_};
    }

    if (exists $cols{'time'}) { # convert times to ISO
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
        #$j->pretty(1);
        $j->indent(1);
        my $json = $j->encode( \%data2 );
        $c->response->content_type('application/json');
        $c->response->body( $json );

    } elsif ($format eq 'csv') {

        my @table = ([]);

        # push column headings first on list
        foreach (@params) {
            #unshift @{ $data2{$_} }, /^time$/ ? $_ : "$_ ($units2{$_})";
            my ($name) = /^(\w+)/;
            push $table[0], /^time$/ ? $_ : "$_ ($units2{$name})";
        }
        print STDERR "table1 = ", Dumper \@table;

        # rearrange from hash of arrays into table of rows
        my $rows = $nc2->dimensionSize($x_axis); #$nc->dimsize('time');
        for (my $i = 0; $i < $rows; $i++) {
            my @cells = ();
            foreach my $v (@vars) {
                #map $data2{$_}->[$i], @vars;
                my @cols = @{ $cols{$v} };
                #print STDERR "v = $v i = $i\n", Dumper \@cols;
                if (@cols) {
                    map  { push @cells, $data2{$v}->[$_]->[$i] } @cols;
                } else {
                    push @cells, $data2{$v}->[$i];
                }
            }
            push @table, \@cells;
        }

        print STDERR "table2 = ", Dumper \@table;

        my $out;
        foreach (@table) {
            $out .= join("\t", @$_) . "\n";
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
