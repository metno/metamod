package MetamodWeb::Controller::Restricted::Transform;

=begin LICENSE

Copyright (C) 2010 met.no

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

=end LICENSE

=cut


=head1 NAME

MetamodWeb::Controller::Restricted::Transform - catalyst controller for transformation via FIMEX

=head1 DESCRIPTION

Only available if the directive FIMEX_PROGRAM is set in master_config.

=head1 METHODS

=cut

use Moose;
use namespace::autoclean;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); @r ? sprintf "0.%d", @r : 0 };
our $DEBUG = 0; # or does nothing

use Data::Dumper;
#use Try::Tiny;
use IO::File;
#use File::Spec qw();
use XML::LibXSLT;
use DateTime::Format::Strptime;
use MetNo::Fimex qw();
use MetNo::OPeNDAP;
use Metamod::Config qw();
#use Metamod::WMS qw(getProjString);

has 'xslt' => ( is => 'ro', isa => 'XML::LibXSLT', default => sub { XML::LibXSLT->new() } );

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

# TODO: Either change to MetamodWeb::Controller::Search::FimexDownload or change URL to not include /search FIXME

=head2 transform

Transform NetCDF file via OPeNDAP according to user criteria

=head3 GET request

Display menu form generated via THREDDS DDX webservice

=head3 POST request

Download and process file, then send to user

=cut

# TODO: Find out how to present login page w/o header FIXME

sub transform :Path('/search/transform') :ActionClass('REST') :Args {
    my ($self, $c) = @_;

    $c->stash( 'current_view' => 'Raw' );
    $c->stash( debug => $self->logger->is_debug() );

    my $para = $c->req->params->{ ds_id };
    if ( ref $para ) { # more than one ds_id
        $c->detach('Root', 'error', [400, "Only one dataset per request currently supported"]);
    }
    my $ds = $c->model('Metabase::Dataset')->find($para)
        or $c->detach('Root', 'error', [404, "Dataset not found"]);
    my $dapurl = $ds->opendap_url()
        or $c->detach('Root', 'error', [501, "Missing OPeNDAP URL in dataset"]);
    $c->stash( dapurl => $dapurl, dataset => $ds );

    $c->stash( projections => Metamod::WMS::projList() );
}

sub transform_GET {
    my ($self, $c) = @_;

    my $dapurl = $c->stash->{dapurl};
    my $ds_id = $c->stash->{dataset}->ds_id;
    $self->logger->debug("Calling OPeNDAP DDX $dapurl ...");
    $c->detach('Root', 'Bad OPeNDAP URL', [502, $@]) if $dapurl !~ /^http/; # workaround for value 'URL' in database
    my $dap = MetNo::OPeNDAP->new($dapurl);
    my $ddx = eval { $dap->ddx }
        or $c->detach('Root', 'error', [502, $@]); # bad gateway

    $c->stash( ddx => $ddx );

    #print STDERR $ddx->toString(1);
    #print STDERR "*** $expires ***\n";

    # check if data has expired
    my $now = DateTime->now;
    my $dataparser = DateTime::Format::Strptime->new( pattern => '%F %TZ');
    my $gridded = $ddx->findvalue('/*/*[local-name()="Grid"]');
    my $expires = $ddx->findvalue('/*/*[@name="NC_GLOBAL"]/*[@name="Expires"]/*');
    my $expiration_date = $expires ? $dataparser->parse_datetime($expires) : $now;

    if( $now > $expiration_date ){
        $c->detach( 'Root', 'error', [ 410, "Dataset $ds_id expired"] );
    }

    # extract bounding box coords from DB since OPeNDAP not necessarily in lat/lon
    my $bounding_box = $c->stash->{dataset}->metadata()->{'bounding_box'}->[0]
        or $self->logger->warn("Missing bounding box in dataset $ds_id (timeseries?)");;
    my ($e, $s, $w, $n) = split(/\s*,\s*/, $bounding_box) if defined $bounding_box; # ESWN

    my %xslparam;
    if ($e > $w && $n > $s) {
       %xslparam = ( e => $e, s => $s, w => $w, n => $n );
    } else {
        $self->add_error_msgs($c, 'Error: bounding box coordinates not in correct order');
    }

    # using XSLT here since extracting data in Template Toolkit is too cumbersome
    my $stylesheet = $self->xslt->parse_stylesheet_file( $c->path_to( '/root/xsl/ddx2html.xsl' ) ); # move to constructor
    my $results = eval { $stylesheet->transform( $ddx, XML::LibXSLT::xpath_to_string(%xslparam) ) }
        or $c->detach('Root', 'error', [500, $@]);

    $c->stash(
        template => $gridded ? 'search/transform.tt' : 'search/transform_ts.tt',
        html => $results->toString,
        #projs => Metamod::WMS::projList()
    );

}

sub transform_POST {
    my ($self, $c) = @_;

    my $config = Metamod::Config->instance();
    my $fimexpath = $config->get('FIMEX_PROGRAM')
        or $c->detach( 'Root', 'error', [ 501, "Not available without FIMEX installed"] );
    $MetNo::Fimex::DEBUG = 0; # turn off debug or nothing will happen

    my $p = $c->request->params;
    #printf STDERR Dumper \$p;

    my %fiParams = (
        dapURL => $c->stash->{dapurl},
        program => $fimexpath,
    );

    my $vars = $p->{vars};
    $fiParams{selectVariables} = ref $vars ? $vars : [ $vars ] if $vars; # listify if single, skip if empty

    for (qw(north south east west)) {
        next unless exists $$p{$_};
        $$p{$_} =~ s/^\s+|\s+$//g; # trim whitespace so fimex doesn't choke
        $fiParams{$_} = $$p{$_};
    }

    my ($fimex, $xAxisValues, $yAxisValues);

    eval { # Try::Tiny segfaults when used to catch errors

        # do some timestamp validation here
        $fiParams{'startTime'} = _fimextime( $$p{start_date} ) if $$p{start_date};
        $fiParams{'endTime'}   = _fimextime( $$p{stop_date } ) if $$p{stop_date };

        # setup fimex to fetch data via opendap
        $fimex = new MetNo::Fimex(\%fiParams);

        if ($p->{'projection'} ) {
            $xAxisValues = sprintf "%s,%s,...,%s", $p->{'xAxisMin'}, $p->{'xAxisMin'} + $p->{'xAxisStep'}||0, $p->{'xAxisMax'} if $p->{'xAxisMin'};
            $yAxisValues = sprintf "%s,%s,...,%s", $p->{'yAxisMin'}, $p->{'yAxisMin'} + $p->{'yAxisStep'}||0, $p->{'yAxisMax'} if $p->{'yAxisMin'};
            #printf STDERR "<<$xAxisValues>> <<$xAxisValues>>";
            $fimex->setProjString( $p->{'projection'}, $p->{'interpolation'}, $xAxisValues, $yAxisValues );
        }
        1;

    } or do {

        $self->add_info_msgs( $c, "Invalid input parameters to Fimex:\n$@" );
        #$c->res->redirect( $c->request->uri );

        #$self->logger->error("Cannot parse times '$$p{start_date}' '$$p{stop_date}': $@");
        #$c->detach( 'Root', 'error', [ 400, "Cannot parse times: $@"] );
        #
        $self->logger->debug("Invalid input parameters to Fimex: $@");
        $c->detach( 'Root', 'error', [ 400, "Invalid input parameters to Fimex:\n$@"] );

    };

    my $cmd = eval { $fimex->doWork() };
    if ($@) {
        $self->logger->warn("FIMEX runtime error: $@");
        $c->detach( 'Root', 'error', [ 502, "FIMEX runtime error: $@"] );
    }

    $self->logger->debug("Running FIMEX: $cmd");

    my $ncfile = $fimex->outputPath;

    $c->detach( 'Root', 'error', [ 502, "Missing output file"] ) unless -s $ncfile;

    #print STDERR "*************** $ncfile\n";

    $c->serve_static_file($ncfile);

    unlink $ncfile;

}


sub _fimextime {
    # convert timestamp into udunits as in https://projects.met.no/fimex/doc/classMetNoFimex_1_1TimeSpec.html
    my $time = shift;
    my ($yy, $mm, $dd, $rest) = $time =~ /^(\d+)-(\d+)-(\d+)[ T]?(.*)/ or die "Invalid time format";
    my ($h, $m, $s)        = $rest =~ /^(\d+):(\d+):(\d+(\.\d+)?)/;
    return $rest ? "$yy-$mm-$dd $h:$m:$s" : "$yy-$mm-$dd 00:00:00";

}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

=head1 SEE ALSO

=cut
