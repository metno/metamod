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

#use warnings FATAL => qw( all ); # remove FIXME

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

Comma separated list of variables (the first is the X axis and should normally be time).

B<New:> Multi-dimensional variables now supported. Use foo[0],foo[1]... or just foo for all columns.

=head3 format

Either "json" or "csv" (comma separated with header row)

=head3 Examples

  /ts/5435/time,ice_concentration/json
  /ts/1020/time,gsl[1],gsl[4],gsl[11]/csv

=cut

sub ts :Path("/ts") :Args(3) {
    my ( $self, $c, $ds_id, $varlist, $format ) = @_;

    my $config = Metamod::Config->instance();
    my $fimexpath = $config->get('FIMEX_PROGRAM')
        or $c->detach( 'Root', 'error', [ 501, "Not available without FIMEX installed"] );

    my @params = split ',', $varlist;
    my $x_axis = $params[0];
    my @vars; # use this to remember the column order
    my %cols; # requested cols with name and optionally col index (if 2D)
    my %data; # this is where all the good stuff from NetCDF is stored
    my %indexes; # any arrays used for labeling other vars

    foreach (@params) {
        /^(\w+)(\[(\d+)\])?$/ or die; # pick out name and optionally index
        unless (exists $cols{$1}) {
            $cols{$1} = [];
            push @vars, $1; # store only once if multicol
        }
        push @{ $cols{$1} }, $3 if defined $3; # empty if single array
    }
    #printf STDERR "vars: %sparams: %scols: %s", Dumper \@vars, \@params, \%cols;

    $MetNo::Fimex::DEBUG = 0; # turn off debug or nothing will happen

    my $ds = $c->model('Metabase::Dataset')->find($ds_id) or $c->detach('Root', 'default');
    my $dapurl = $ds->opendap_url() or $c->detach('Root', 'default');

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
    my $nc2 = MetNo::NcFind->new($ncfile);
    if (! $nc2) {
        $self->logger->warn("Can not parse NetCDF file $ncfile");
        $c->detach( 'Root', 'error', [ 500, "Can not parse NetCDF file $ncfile"] );
    }

    # first fetch all variables from db since we need to lookup names
    foreach my $v ($nc2->variables) {
        #print STDERR "+++ $v\n";

        my $name = $nc2->att_value($v, 'standard_name'); # TODO also check long_name, short_name
        $name = $v if $name eq 'Not available';
        my $role = $nc2->att_value($v, 'cf_role');

        if (exists $cols{$name} || $role eq 'timeseries_id') { # skip vars not in request
            my @dim = $nc2->dimensions($v);
            @dim = grep !/^string|maxStrlen64$/, @dim;
            $self->logger->debug("name = $name [", join(', ', @dim), "]\n", Dumper $cols{$name});

            foreach my $d (@dim) { # check if should be put in indexes
                if (@dim == 1 and $d ne $x_axis) { # i believe we have a label array, Watson
                    $indexes{$d} = [] unless exists $indexes{$d};
                    push @{ $indexes{$d} }, $name;
                    $self->logger->debug("* adding $name to index of $d");
                    #printf STDERR "* d = $d; cols = %s", Dumper \%cols;
                }
                die if ($d eq 'string'); # string dimensions are automatically collapsed in get_struct()
                #die unless defined $role && $role eq 'timeseries_id'; # have no idea what this column might be
            }
            # now store all the relevant data
            $data{$name} = $nc2->get_struct($v); # read in data array(s)
            $data{'dimensions'}{$name} = \@dim;
            $data{'units'}{$name} = $nc2->att_value($v, 'units');
        }
    }

    # loop through request and discard unwanted stuff
    foreach my $k (keys %cols) {
        # check that all variables actually exist
        $c->detach( 'Root', 'error', [ 400, "No such variable '$k'"] )
            unless $data{$k};
        # any subcols to extract?
        my @subcols = exists $cols{$k} ? @{ $cols{$k} } : (); # any foo[..] in URL
        if (@subcols) {
            #printf STDERR "* subcols for $k = %s\n", Dumper \@subcols;
            $data{$k} = [ map { @{$data{$k}}[$_] } @subcols ]; # extract selected cols and replace
            foreach my $d (@{ $data{'dimensions'}->{$k} } ) {
                next if $d eq $x_axis;
                my ($index) = eval { @{ $indexes{$d} } };
                next unless defined $index;
                $self->logger->debug("** index $d of $k: $index");
                $data{$index} = [ map { @{$data{$index}}[$_] } @subcols ]; # extract selected col headings and replace
            }
        }
    }

    if (exists $cols{'time'}) { # convert times to ISO
        my @isotime;
        foreach my $t (@{ $data{'time'} }) { # FIXME read units2
            #print STDERR "++++++++++++++++ $t\n";
            if ($t < 3000) { # assume years instead of epoch seconds
                push @isotime, $t; # use just year instead of full timestamp
            } else {
                my $dt = DateTime->from_epoch( epoch => $t );
                push @isotime, $dt->ymd . 'T' . $dt->hms;
            }
        }
        #print STDERR "time: ", Dumper \@isotime;
        $data{'time'} = \@isotime;
    }

    #printf STDERR "Data: %sIndexes: %s", Dumper \%data, \%indexes;

    # now output stuff
    if ($format eq 'json') {

        my $j = JSON->new->utf8;
        #$j->pretty(1);
        $j->indent(1);
        my $json = $j->encode( \%data );
        $c->response->content_type('application/json');
        $c->response->body( $json );

    } elsif ($format eq 'csv') {

        my (@tablecols, @tablerows, @tablehead);

        # figure out column headings
        foreach my $v (@vars) {
            my $dims = $data{'dimensions'}{$v};
            my $cols = $cols{$v}; # selected cols in 2-dim matrix
            #printf STDERR "col=$v dims=%s cols=%s\n", join(',',  @$dims), join(',', @$cols);
            my $array = $data{$v};
            foreach my $d (@$dims) {
                if ($d eq $x_axis) {
                    if (ref @$array[0]) { # it's a 2D array
                        push @tablecols, @$array; # push all cols
                    } else {
                        push @tablecols, $array; # push simple col
                        push @tablehead, $v; # add col header
                    }
                } else {
                    if ( my $legends = $indexes{$d} ) {
                        my $index = shift @{ $legends };
                        $self->logger->debug("*** index of $v = $index");
                        push @tablehead, @{ $data{$index} };
                    } else {

                    }
                }
            }
        }

        # transpose cols
        push @tablerows, [ @tablehead ];
        my $col = scalar(@{ $tablecols[0] }) || 0;
        foreach my $col (0 .. $col-1) {
            push @tablerows, [ map {$_->[$col]} @tablecols ];
        }

        #print STDERR "tablecols: ", Dumper \@tablecols;
        #print STDERR "tablerows: ", Dumper \@tablerows;
        #print STDERR "tablehead: ", Dumper \@tablehead;

        my $out;
        foreach (@tablerows) {
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

=head1 AUTHOR

Geir Aalberg, E<lt>geira\@met.noE<gt>

=head1 SEE ALSO

L<MetNo::NcFind;>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

__PACKAGE__->meta->make_immutable;
