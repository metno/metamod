package MetamodWeb::Controller::FimexDownload;

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

MetamodWeb::Controller::FimexDownload - catalyst controller for downloads through FIMEX

=head1 DESCRIPTION

Only available if the directive FIMEX_PROGRAM is set in master_config.

=head1 METHODS

=cut

use Moose;
use namespace::autoclean;

our $DEBUG = 0; # or does nothing

use Data::Dumper;
use IO::File;
use File::Spec qw();
use XML::LibXSLT;
use DateTime::Format::Strptime;
use MetNo::Fimex qw();
use MetNo::OPeNDAP;
use Metamod::Config qw();

has 'xslt' => ( is => 'ro', isa => 'XML::LibXSLT', default => sub { XML::LibXSLT->new() } );

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

# TODO: Either change to MetamodWeb::Controller::Search::FimexDownload or change URL to not include /search FIXME

=head2 fimexDownload

Routine for downloading/transforming with set parameters (projection) either via OPeNDAP or http

Used mainly by DOKIPY

=cut

sub fimexDownload :Path('/search/fimexdownload') :Args(0) {
    my ( $self, $c ) = @_;

    my $config = Metamod::Config->instance();

    my $p = $c->req->params;
    my $ds_name = $p->{ dataset_name };
    my $ds_id = $p->{ ds_id };
    my $projection = $p->{ projection };

    $self->logger->debug("Projection of $ds_name, $projection");
    if (! ($ds_name || $ds_id) or !$projection) {
        $self->logger->debug("missing dataset_name/ds_id or projection");
        $c->detach('Root', 'error', [400, "Required parameters: dataset_name|ds_id, projection"]); # bad request
    }

    # get the fimexProjection and dataref of the dataset
    my $ds = $ds_id ? # call by id?
        $c->model('Metabase::Dataset')->find($ds_id) : # direct lookup
        $c->model('Metabase::Dataset')->search({ds_name => $ds_name})->first; # only one
    if ($ds) {
        $ds_id ||= $ds->ds_id;
        $ds_name ||= $ds->ds_name;
        $self->logger->debug("Found dataset for $ds_name: $ds_id");
    } else {
        $self->logger->warn("No such dataset " . $ds_name||$ds_id);
        $c->detach('Root', 'error', [ 404, 'Unknown: ' . $ds_name||$ds_id ]); # not found
    }

    my $projectioninfo = $ds->projectioninfos->first; # use projectioninfo instead - FIXME
    unless ($projectioninfo) {
        # TODO error page
        $self->logger->warn("no projectioninfos for dataset: $ds_name");
        $c->detach('Root', 'error', [500, "no projectioninfos for dataset: $ds_name"]);
    }
    my $fiProjection = Metamod::FimexProjections->new($projectioninfo->pi_content);

    # find the datasets 'dataref'
    my $metadataRef = $ds->metadata([]);
    #print STDERR Dumper \$metadataRef;
    my $dataref = $metadataRef->{'dataref'}[0];

    unless ($dataref) {
        # TODO error page
        $self->logger->warn("no dataref for dataset: $ds_name");
        $c->detach('Root', 'error', [500, "no dataref for dataset: $ds_name"]);
    }

    my $input = $dataref;
    my $regex = $fiProjection->getURLRegex;
    $regex = substr($regex, 1, -1); # remove / (or regex separator) around substr
    $regex = qr/$regex/;
    my $replace = $fiProjection->getURLReplace;
    $input =~ s/$regex/'"'.$replace.'"'/ee;
    my $inputX = $dataref;
    $inputX =~ s^$regex^$1/fileServer/data/$2^;

    $self->logger->debug("trying to retrieve data for fimex from $input from  $dataref  =~ s/ $regex / $replace /");
    $self->logger->debug("$inputX");

    # run fimex
    my $fimex = MetNo::Fimex->new();
    $fimex->program($config->get('FIMEX_PROGRAM'));
    if ($input =~ m^\s*(http://|ftp:)^) { # this is http download, not OPeNDAP
        $fimex->inputURL($input);
    } else {
        $fimex->inputFile($input);
    }
    my $projString = $fiProjection->getProjectionProperty($projection, 'projString');
    if ($projString) {
        $fimex->interpolateMethod($fiProjection->getProjectionProperty($projection, 'method'));
        $fimex->projString($projString);
        $fimex->xAxisValues($fiProjection->getProjectionProperty($projection, 'xAxis'));
        $fimex->yAxisValues($fiProjection->getProjectionProperty($projection, 'yAxis'));
        my $isMetric = ($fiProjection->getProjectionProperty($projection, 'toDegree') eq "true") ? 0 : 1;
        $fimex->metricAxes($isMetric);
    }
    my $command = eval { $fimex->doWork(); };
    $self->logger->debug("Running fimex-command: $command") if $command;
    if ($@) {
        $self->logger->error("cannot run fimex: $@");
        $c->detach('Root', 'error', [500, "Cannot run fimex: $@"]);
    }

    my $filename = File::Spec->catfile($fimex->outputDirectory(), $fimex->outputFile());
    my $fh = new IO::File($filename, "r")
        or $c->error("no such file: $filename");
    $c->response->header('Content-Disposition' => "attachment; filename=\"$filename\"");
    $c->response->content_type("application/x-netcdf");
    $c->response->body($fh);
}


__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

=cut
