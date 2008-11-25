package Metamod::DatasetTransformer::DIF;
use base qw(Metamod::DatasetTransformer);

use strict;
use warnings;
use Carp qw(carp croak);
use quadtreeuse;
#use Dataset; # required later, so we don't have circular 'use'

use 5.6.0;


our $VERSION = 0.3;
our $XSLT_FILE_MM2 = "[==SOURCE_DIRECTORY==]/common/schema/dif2MM2.xslt";
our $XSLT_FILE_DS = "[==SOURCE_DIRECTORY==]/common/schema/dif2dataset.xslt";

sub originalFormat {
    return "DIF";
}

sub new {
    if (@_ < 3 || (scalar @_ % 2 != 1)) {
        croak ("new " . __PACKAGE__ . " needs argument (package, file), got: @_\n");
    }
    my ($class, $xmdStr, $xmlStr, %options) = @_;
    my $self = {xmdStr => $xmdStr,
                xmlStr => $xmlStr,
                difDoc => undef, # init by test
                dsDoc => undef,
                dsXslt => $options{dsXslt} || $XSLT_FILE_DS,
                mm2Xslt => $options{mm2Xslt} || $XSLT_FILE_MM2,
               };
    return bless $self, $class;
}

sub test {
    my $self = shift;
    # test on xml-file of xmlStr
    unless ($self->{xmlStr}) {
        warn "no data" if ($self->DEBUG);
        return 0; # no data
    }
    unless ($self->{difDoc}) {
        eval {
            $self->{difDoc} = $self->XMLParser->parse_string($self->{xmlStr});
        }; # do nothing on error, $doc stays empty
        if ($@ && $self->DEBUG) {
            warn "$@\n";
        }
    }
    return 0 unless $self->{difDoc}; # $doc not initialized
        
    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('dif', 'http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/');
    $xpc->registerNs('d', 'http://www.met.no/schema/metamod/dataset');
    
    # test of content in xmlStr
    my $isDIF = 0;
    my $root = $self->{difDoc}->getDocumentElement();
    my $nodeList = $xpc->findnodes('/dif:DIF', $root);
    if ($nodeList->size() == 1) {
        $isDIF = 1;
    } elsif ($self->DEBUG) {
        warn "found ".$nodeList->size." nodes with /dif:DIF\n";
    }
    
    my $isDS = 1;
    if ($self->{xmdStr}) {
        $isDS = 0; # reset to 0, might fail
        # test optional xmdStr (if xmd file has been created earlier)
        unless ($self->{dsDoc}) {
            eval {
                $self->{dsDoc} = $self->XMLParser->parse_string($self->{xmdStr});
            }; # do nothing on error, $doc stays empty
            if ($@ && $self->DEBUG) {
                warn "$@ during xmdStr parsing\n";
            }
        }
        return 0 unless $self->{dsDoc};
        
        my $dsRoot = $self->{difDoc}->getDocumentElement();
        my $nList = $xpc->findnodes('/d:dataset/d:info/@ownertag', $root);
        if ($nodeList->size() == 1) {
            $isDS = 1;
        } elsif ($self->DEBUG) {
            warn "could not find /d:dataset/d:info/\@ownertag\n";
        }
    }
    return $isDS && $isDIF;
}

sub transform {
    my $self = shift;
    croak("Cannot run transform if test fails\n") unless $self->test;
    
    my $mm2Doc;
    {
        my $styleDoc = $self->XMLParser->parse_file($self->{mm2Xslt});    
        my $stylesheet = $self->XSLTParser->parse_stylesheet($styleDoc);
        $mm2Doc = $stylesheet->transform($self->{difDoc});
    }
    
    my $dsDoc = $self->{dsDoc};
    unless ($dsDoc) { # no xmdStr and thus no dsDoc, extract from dif
        my $styleDoc = $self->XMLParser->parse_file($self->{dsXslt});
        my $stylesheet = $self->XSLTParser->parse_stylesheet($styleDoc);
        $dsDoc = $stylesheet->transform($self->{difDoc});
    }

    # postprocess results / exceptions
    require Metamod::Dataset;
    my $ds = newFromDoc Metamod::Dataset($mm2Doc, $dsDoc);
    for my $degName (qw(latitude_resolution longitude_resolution)) {
        # remove 'degree' units
        my @vals = $ds->removeMetadataName($degName);
        @vals = map {s/\s*degree.*//ig;} @vals;
        $ds->addMetadata({$degName => \@vals});
    }
    
    if (!$self->{xmdStr}) {
        my %info = $ds->getInfo;
        $info{name} =~ s^_^/^g;
        $info{ownertag} = 'DAM' if ($info{ownertag} eq 'DAMOCLES');
        foreach my $date (qw(timestamp creationDate)) { # timestamp is reference for other dates if not existing
            unless ($info{$date}) {
                if ($date eq 'timestamp') {
                    $info{$date} = POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
                } else {
                    $info{$date} = $info{timestamp};
                }
            }
            if (length $info{$date} == 10) {
                $info{$date} .= 'T00:00:00Z';
            }
            if (length $info{$date} != 20) {
                warn "$date". $info{$date}." not in format YYYY-MM-DDTHH:MM:SSZ\n";
            }
        }
        $ds->setInfo(\%info);
        
        require quadtreeuse;
        my %metadata = $ds->getMetadata;
        my ($south, $north, $east, $west) = qw(southernmost_latitude northernmost_latitude 
                                               easternmost_longitude westernmost_longitude);
        if (exists $metadata{bounding_box}) {
            my @bbs = @{ $metadata{bounding_box} };
            my @nodes;
            foreach my $bb (@bbs) {
                # bounding_box consists of 4 degree values
                my @bounding_box = split ',', $bb;
                if (@bounding_box != 4) {
                    warn "wrong defined bounding_box: $bb\n";
                }
                my ($eLon, $sLat, $wLon, $nLat) = @bounding_box;
                my $qtu = new quadtreeuse(90, 0, 3667387.2, 7, "+proj=stere +lat_0=90 +datum=WGS84");
                if (defined $sLat && defined $nLat && defined $wLon && defined $eLon) {
                    if ($sLat <= -90) {
                        if ($nLat <= -89.9) {
                            warn "cannot build northern polar-stereographic quadtree on southpole\n";
                        } else {
                            $sLat = 89.9;
                        }
                    }
                    $qtu->add_lonlats("area",
                                      [$eLon, $wLon, $wLon, $eLon, $eLon],
                                      [$sLat, $sLat, $nLat, $nLat, $sLat]);
                    push @nodes, $qtu->get_nodes;
                }
            }
            if (@nodes) {
                my %unique;
                @nodes = map {$unique{$_}++ ? () : $_} @nodes;
                $ds->setQuadtree(\@nodes);
            }
        }
    }
    
    return ($ds->getDS_DOC, $ds->getMETA_DOC);
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer::DIF - transform old-dataset to dataset and MM2

=head1 SYNOPSIS

  use Metamod::DatasetTransfomer::DIF.pm;
  my $dsT = new Metamod::DatasetTransfomer::Dataset($xmdStr, $xmlStr);
  my $datasetStr;
  if ($dsT->test) {
      $ds2Obj = $dsT->transform;
  }

=head1 DESCRIPTION

This module is an implentation of L<Metamod::DatasetTransformer> to convert the old
dataset format to the dataset and MM2 format. DIF files may contain information from MM2 and
Dataset, but Dataset-information may also be provided through the xmdString.

=head1 METHODS

For inherited options see L<Metamod::DatasetTransformer>, only differences are mentioned here.

=over 4

=item new($xmlStr, %options)

Options include:

=over 8

=item dsXslt => 'filename.xslt'

Overwrite the default xslt file to convert to the actual dataset format.

=item mm2Xslt => 'filename.xslt'

Overwrite the default xslt file to convert to the mm2 format.

=back

=back

=head1 VERSION

0.1

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>, L<XML::LibXSLT>, L<Metamod::DatasetTransformer>

=cut

