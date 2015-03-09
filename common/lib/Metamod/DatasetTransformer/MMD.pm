=begin licence

----------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2013 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: egil.storen@met.no

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
----------------------------------------------------------------------------

=end licence

=cut

package Metamod::DatasetTransformer::MMD;
use base qw(Metamod::DatasetTransformer);

use strict;
use warnings;
use encoding 'utf-8';
use UNIVERSAL;
use Carp qw();
use mmTtime;
use Metamod::Config;
use Log::Log4perl;
use POSIX qw();
#use Dataset; # required later, so we don't have circular 'use'



our $VERSION = do { my @r = (q$LastChangedRevision: 2351 $ =~ /\d+/g); sprintf "0.%d", @r };
my $logger = Log::Log4perl::get_logger('metamod::common::'.__PACKAGE__);

sub originalFormat {
    return "MMD";
}

sub new {
    if (@_ < 3 || (scalar @_ % 2 != 1)) {
        croak ("new " . __PACKAGE__ . " needs argument (package, file), got: @_");
    }

    my $XSLT_FILE_MM2 = Metamod::DatasetTransformer::xslt_dir() . 'mmd-to-mm2.xsl';
    # my $XSLT_FILE_XMD = Metamod::DatasetTransformer::xslt_dir() . 'dif2dataset.xslt';

    my ($class, $xmdStr, $xmlStr, %options) = @_;
    my $self = {xmdStr => $xmdStr,
                xmlStr => $xmlStr,
                mmdDoc => undef, # init by test
                xmdDoc => undef,
                # xmdXslt => $options{xmdXslt} || $XSLT_FILE_XMD,
                mm2Xslt => $options{mm2Xslt} || $XSLT_FILE_MM2,
               };
    return bless $self, $class;
}

sub test {
    my $self = shift;
    # test on xml-file of xmlStr
    unless ($self->{xmlStr}) {
        $logger->debug("no data");
        return 0; # no data
    }
    unless ($self->{mmdDoc}) {
        if (UNIVERSAL::isa($self->{xmlStr}, 'XML::LibXML::Document')) {
            $self->{mmdDoc} = $self->{xmlStr};
        } else {
            eval {
                $self->{mmdDoc} = $self->XMLParser->parse_string($self->{xmlStr});
            }; # do nothing on error, $doc stays empty
            if ($@) {
                $logger->debug($@);
            }
        }
    }
    return 0 unless $self->{mmdDoc}; # $doc not initialized

    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('mmd', 'http://www.met.no/schema/mmd');
    $xpc->registerNs('d', 'http://www.met.no/schema/metamod/dataset');

    # test of content in xmlStr
    my $isMmd = 0;
    my $root = $self->{mmdDoc}->getDocumentElement();
    my $nodeList = $xpc->findnodes('/mmd:mmd', $root);
    $logger->debug("found ".$nodeList->size." nodes with /mmd:mmd");
    if ($nodeList->size() == 1) {
        $isMmd = 1;
    }

    my $isXMD = 1;
    if ($self->{xmdStr}) {
        $isXMD = 0; # reset to 0, might fail
        # test optional xmdStr (if xmd file has been created earlier)
        unless ($self->{xmdDoc}) {
            if (UNIVERSAL::isa($self->{xmdStr}, 'XML::LibXML::Document')) {
                $self->{xmdDoc} = $self->{xmdStr};
            } else {
                eval {
                    $self->{xmdDoc} = $self->XMLParser->parse_string($self->{xmdStr});
                }; # do nothing on error, $doc stays empty
                if ($@) {
                    $logger->debug("$@ during xmdStr parsing");
                }
            }
        }
        return 0 unless $self->{xmdDoc};

        my $dsRoot = $self->{mmdDoc}->getDocumentElement();
        my $nList = $xpc->findnodes('/d:dataset/d:info/@ownertag', $root);
        if ($nodeList->size() == 1) {
            $isXMD = 1;
        } else {
            $logger->debug("could not find /d:dataset/d:info/\@ownertag");
        }
    }
    return $isXMD && $isMmd;
}

sub transform {
    my $self = shift;
    Carp::croak("Cannot run transform if test fails") unless $self->test;

    my $mm2Doc;
    {
        my $styleDoc = $self->XMLParser->parse_file($self->{mm2Xslt});
        my $stylesheet = $self->XSLTParser->parse_stylesheet($styleDoc);
        $mm2Doc = $stylesheet->transform($self->{mmdDoc});
        #print STDERR "\n\n\n$mm2Doc\n\n\n";
    }

    my $xmdDoc = $self->{xmdDoc};
    unless ($self->{xmdDoc}) { # no xmdStr and thus no xmdDoc, extract from dif
        my $styleDoc = $self->XMLParser->parse_file($self->{xmdXslt});
        my $stylesheet = $self->XSLTParser->parse_stylesheet($styleDoc);
        $xmdDoc = $stylesheet->transform($self->{mmdDoc});
    }

    # postprocess results / exceptions
    require Metamod::Dataset;
    my $ds = newFromDoc Metamod::Dataset($mm2Doc, $xmdDoc);
    for my $degName (qw(latitude_resolution longitude_resolution)) {
        # remove 'degree' units
        my @vals = $ds->removeMetadataName($degName);
        @vals = map {s/\s*degree.*//ig;} @vals;
        $ds->addMetadata({$degName => \@vals});
    }

    unless ($self->{xmdDoc}) { # no xmdStr and thus no xmdDoc, extracted from dif, postprocessing
        my %info = $ds->getInfo;
        $info{'name'} =~ s^_^/^g;
        $info{'ownertag'} = 'DAM' if ($info{'ownertag'} eq 'DAMOCLES');
        unless ($info{'datestamp'}) {
            $info{'datestamp'} = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime(mmTtime::ttime()));
        }
        foreach my $date (qw(datestamp creationDate)) {
            unless ($info{$date}) {
                $info{$date} = $info{datestamp}; # datestamp is reference, see above
            }
            if (length $info{$date} == 10) {
                $info{$date} .= 'T00:00:00Z';
            }
            if (length $info{$date} != 20) {
                warn "$date". $info{$date}." not in format YYYY-MM-DDTHH:MM:SSZ";
            }
        }
        unless ($info{'name'}) {
            warn "missing name, ususally set from DIF Entry_ID, inventing one";
            $info{'name'} = 'UNKNOWN/EntryId' . int(rand(1e9));
        }
        unless ($info{'name'} =~ m^/^) {
            warn "mismatching datasetname from DIF Entry_ID, setting project UNKNOWN";
            $info{'name'} = 'UNKNOWN/'.$info{'name'};
        }
        $ds->setInfo(\%info);

        # conversion to datasetregion
        my %metadata = $ds->getMetadata;
        my $datasetRegion = $ds->getDatasetRegion();
        my ($south, $north, $east, $west) = qw(southernmost_latitude northernmost_latitude
                                               easternmost_longitude westernmost_longitude);
        if (exists $metadata{bounding_box}) {
            my @bbs = @{ $metadata{bounding_box} };
            foreach my $bb (@bbs) {
                # bounding_box consists of 4 degree values
                my @bounding_box = split ',', $bb;
                if (@bounding_box != 4) {
                    warn "wrong defined bounding_box: $bb";
                }
                my %bb;
                @bb{qw(east south west north)} = @bounding_box;
                eval {
                    # datasetRegion does several check and dies on error
                    $datasetRegion->extendBoundingBox(\%bb);
                    # bounding box might be to big (one number for everything)
                    # add each bounding as polygon, too
                    my ($eLon, $sLat, $wLon, $nLat) = @bounding_box;
                    if ($nLat == $sLat and $eLon == $wLon) {
                        $datasetRegion->addPoint([$eLon, $nLat]);
                    } else {
                        $datasetRegion->addPolygon([[$eLon, $nLat], [$eLon, $sLat], [$wLon, $sLat], [$wLon, $nLat], [$eLon, $nLat]]);
                    }
                    $logger->debug("adding polygon [[$eLon, $nLat], [$eLon, $sLat], [$wLon, $sLat], [$wLon, $nLat], [$eLon, $nLat]]");
                }; if ($@) {
                    my %info = $ds->getInfo();
                    warn "problems setting boundingBox for ".$info{name}.": $@";
                }
            }
            $ds->setDatasetRegion($datasetRegion);
        }
    }

    return ($ds->getXMD_DOC, $ds->getMETA_DOC);
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer::MMD - transform MMD to MM2

=head1 DESCRIPTION

This module is an implentation of L<Metamod::DatasetTransformer> to convert the MMD format
to the dataset (xmd) and MM2 format. MMD files may contain information from MM2 and
Dataset, but Dataset-information may also be provided through the xmdString.

The MMD format is used by the met.no Metadata Editor.

=head1 METHODS

For inherited options see L<Metamod::DatasetTransformer>, only differences are mentioned here.

=over 4

=item new($xmdStr, $xmlStr, %options)

Initialize the transformation by the meta-metadata (optional) and the MMD document. Both arguments can
be strings or XML::LibXML::Documents.

Options include:

=over 8

=item xmdXslt => 'filename.xslt'

Overwrite the default xslt file to convert to the actual dataset format.

=item mm2Xslt => 'filename.xslt'

Overwrite the default xslt file to convert from dif to the mm2 format.

=back

=back

=head1 AUTHOR

Øystein Torget <lt>oysteint@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<XML::LibXSLT>, L<Metamod::DatasetTransformer>

=cut
