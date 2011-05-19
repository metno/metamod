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

=head1 NAME

MetamodWeb::Controller::FimexDownload - catalyst controller for downloads through fimex

=head1 DESCRIPTION

=cut

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); @r ? sprintf "0.%d", @r : 0 };

our $DEBUG = 0;

use IO::File;
use File::Spec qw();
use Moose;
use MetNo::Fimex qw();
use Metamod::Config qw();
use namespace::autoclean;


BEGIN {extends 'MetamodWeb::BaseController::Base'; }

sub fimexDownload :Path('/search/fimexdownload') :Args(0) {
    my ( $self, $c ) = @_;

    my $config = Metamod::Config->new();


    my $dsName = $c->req->params->{ dataset_name } || 0;
    my $projection = $c->req->params->{ projection } || 0;

    $self->logger->debug("Projection of $dsName, $projection");
    if (!$dsName or !$projection) {
        $c->response->status(400); # bad request
        $c->response->body("Required parameters: dataset_name, projection");
        $c->response->content_type("text/plain");
        $self->logger->debug("missing dataset_name or projection");
        return;
    }

    # get the fimexProjection and dataref of the $dsName
    my $ds = $c->model('Metabase::Dataset')->search({ds_name => $dsName})->first; # only one
    $self->logger->debug("found dataset for $dsName: ". $ds->ds_id);
    unless ($ds) {
        # TODO error page
        $self->logger->warn("no dataset for $dsName");
        return;
    }
    my $projectioninfo = $ds->projectioninfos->first;
    unless ($projectioninfo) {
        # TODO error page
        $self->logger->warn("no projectioninfos for dataset: $dsName");
        return;
    }
    my $fiProjection = Metamod::FimexProjections->new($projectioninfo->pi_content);

    # find the datasets 'dataref'
    my $metadataRef = $ds->metadata(['dataref']);
    my $dataref = $metadataRef->{'dataref'}[0];

    unless ($dataref) {
        # TODO error page
        $self->logger->warn("no dataref for dataset: $dsName");
        return;
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
    if ($input =~ m^\s*(http://|ftp:)^) {
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
    eval {my $command = $fimex->doWork(); $self->logger->debug("running fimex-command: $command");};
    if ($@) {
        # TODO error page
        $self->logger->error("cannot run fimex: $@");
        return;
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
