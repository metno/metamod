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
use List::Util qw(max);
#use File::Spec qw();
use XML::LibXSLT;
use DateTime::Format::Strptime;
use MetNo::Fimex qw();
use MetNo::OPeNDAP;
use Metamod::Config qw();
use Metamod::WMS;
use MetamodWeb::Utils::FormValidator;

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
        or $self->logger->warn("Missing bounding box in dataset $ds_id (timeseries?)");
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

    # experimental openlayers map bbox selector
    my $config = Metamod::Config->instance();
    my %searchmaps;
    my $wmsprojs = $config->split('WMS_PROJECTIONS');
    foreach (keys %$wmsprojs) {
        my $crs = $_;
        my ($code) = /^EPSG:(\d+)/ or next; # search map needs just EPSG numeric code
        my $name = $wmsprojs->{$crs};
        my $url = getMapURL($crs) or next;
        $searchmaps{$code} = {
            url     => $url,
            name    => "$name ($crs)"|| getProjName($crs) || $crs,
        };
    }
    #print STDERR Dumper \%searchmaps;

    $c->stash(
        template => $gridded ? 'search/transform/grid.tt' : 'search/transform/ts.tt',
        html => $results->toString,
        searchmaps =>\%searchmaps,
        #projs => Metamod::WMS::projList()
    );

}

sub transform_POST {
    my ($self, $c) = @_;

    my $p = $c->request->params;
    printf STDERR Dumper \$p;

    my $result = $self->validate_transform($c, exists $p->{'projection'});
    if( !$result->success() ){
        $self->add_form_errors($c, $c->stash->{validator});
        return $c->res->redirect($c->uri_for('/search/transform', $c->req->params ) );
    }
#
# Extra validation not successfully done by validate_transform (egils):
#
    my $numeric_rex = '^ *[+-]?(\d+|\.\d+|\d+\.\d*) *$';
    my %error_messages = ();
    my $validator = $c->stash->{validator};
    foreach my $field ('xAxisMin', 'yAxisMin', 'xAxisMax', 'yAxisMax', 'xAxisStep', 'yAxisStep',
                       'east', 'west', 'north', 'south' ) {
        if ($p->{$field} && $p->{$field} !~ /$numeric_rex/) {
            $error_messages{$field} = { label => $validator->field_label($field), msg => 'Only numeric values allowed' };
        }
    }
    if (scalar keys(%error_messages) > 0) {
        $c->flash( 'form_errors' => \%error_messages );
        return $c->res->redirect($c->uri_for('/search/transform', $c->req->params ) );
    }
# Extra validation finished

    my $config = Metamod::Config->instance();
    my $fimexpath = $config->get('FIMEX_PROGRAM')
        or $c->detach( 'Root', 'error', [ 501, "Not available without FIMEX installed"] );
    $MetNo::Fimex::DEBUG = 0; # turn off debug or nothing will happen

    my %fiParams = (
        dapURL => $c->stash->{dapurl},
        program => $fimexpath,
    );

    my $vars = $p->{vars};
    $fiParams{selectVariables} = ref $vars ? $vars : [ $vars ] if $vars; # listify if single, skip if empty

    for (qw(north south east west)) {
        next unless $$p{$_};
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

        my $proj = $p->{'selected_map'} ? 'EPSG:' . $p->{'selected_map'} : $p->{'projection'};

        if ($proj) {
            #my $step = $proj eq 'EPSG:4326' ? 0.5 : 10000;
            my $range = max($p->{'yAxisMax'} - $p->{'xAxisMin'}, $p->{'yAxisMax'} - $p->{'xAxisMin'});
            my $step = $range / ( ( $p->{'steps'} || 500 ) - 1 );
            #print STDERR " * step = $step \n";
            $xAxisValues = sprintf "%s,%s,...,%s", $p->{'xAxisMin'}, $p->{'xAxisMin'} + $step, $p->{'xAxisMax'} if defined $p->{'xAxisMin'};
            $yAxisValues = sprintf "%s,%s,...,%s", $p->{'yAxisMin'}, $p->{'yAxisMin'} + $step, $p->{'yAxisMax'} if defined $p->{'yAxisMin'};
            #printf STDERR "== $proj : <<$xAxisValues>> <<$xAxisValues>>\n";
            $fimex->setProjString( $proj, $p->{'interpolation'}, $xAxisValues, $yAxisValues );
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

    $self->logger->info("Running FIMEX: $cmd");

    my $ncfile = $fimex->outputPath;

    $c->detach( 'Root', 'error', [ 502, "Missing output file"] ) unless -s $ncfile;

    #print STDERR "*************** $ncfile\n";

    $c->serve_static_file($ncfile);

    unlink $ncfile;

}

sub validate_transform : Private {
    my ($self, $c, $oldstyle) = @_;

    my %form_profile = (
        required => [qw( ds_id vars )],
        require_some => {
        },
        optional => [qw( start_date stop_date north south east west interpolation steps ) ],
        optional_regexp => qr/^(x|y)Axis(Min|Max|Step)$/,
        dependency_groups  => {
            # if either field is filled in, they all become required
            txt_coords => $oldstyle ? [qw( projection xAxisMax xAxisMin yAxisMax yAxisMin xAxisStep yAxisStep )]
                          : [qw( selected_map xAxisMax xAxisMin yAxisMax yAxisMin steps )],
        },
        filters       => ['trim'],
        field_filters => {
            north       => ['decimal'],
            south       => ['decimal'],
            east        => ['decimal'],
            west        => ['decimal'],
            west        => ['decimal'],
            steps       => ['pos_decimal'],
        },
        field_filter_regexp_map => {
            # sanitize numbers
            qr/Axis(Min|Max)$/  => ['decimal'],
            qr/AxisStep$/       => ['pos_decimal'],
        },
        constraint_methods => {
            interpolation   => qr/^(nearestneighbor|bilinear|bicubic|coord_nearestneighbor|coord_kdtree|forward_max|forward_mean|forward_median|forward_sum)$/,
        },
        constraint_method_regexp_map => {
            qr/Axis(Min|Max)$/    => qr/^-?\d+(\.\d*)?$/,
        },
        labels => {
            vars => 'Variables',
            xAxisMax    => 'x axis max',
            xAxisMin    => 'x axis min',
            yAxisMax    => 'y axis max',
            yAxisMin    => 'y axis min',
            xAxisStep   => 'x axis increment',
            yAxisStep   => 'y axis increment',
            north       => 'north',
            south       => 'south',
            east        => 'east',
            west        => 'west',
        },
        msgs => {
            missing => 'Required input missing or invalid format',
            invalid => 'Format not valid',
        },
        debug => 1,
    );
    my $validator = MetamodWeb::Utils::FormValidator->new( validation_profile => \%form_profile );
    my $result = $validator->validate($c->req->params);
    $c->stash( validator => $validator );
    return $result;
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
