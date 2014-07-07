#!/usr/bin/perl -w

=begin LICENSE

METAMOD - Web portal for metadata search and upload

Copyright (C) 2014 met.no

Contact information:
Norwegian Meteorological Institute
Box 43 Blindern
0313 OSLO
NORWAY
email: geira@met.no

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

use strict;
use warnings;

# core modules:
use Carp;
use Data::Dumper;
use Pod::Usage;
use Getopt::Long;

# CPAN modules:
use LWP::UserAgent;
use XML::LibXML;
use URI;

use constant THREDDS_NS => 'http://www.unidata.ucar.edu/namespaces/thredds/InvCatalog/v1.0';
use constant MM2_NS     => 'http://www.met.no/schema/metamod/MM2';
local $Data::Dumper::Terse = 1;

my ($config, $logger, %opt, $search_criteria);

GetOptions( \%opt, qw(help full recursive debug id=s) ) or pod2usage(2);
pod2usage(1) if $opt{help} || @ARGV != 1;

my $input = shift @ARGV;

my $ua = LWP::UserAgent->new;
$ua->timeout(5);
#$ua->env_proxy;

if ($input =~ /^https?:/) {
    # presumably a link to thredds
    my $refs = parseCatalog($input);
    print Dumper $refs;
} elsif (-r $input) {
    # presumably a METAMOD MM2 document
    parseMM2($input);
} else {
    pod2usage(2);
}

# regenerate MM2 with new datarefs from THREDDS catalog

sub parseMM2 {
    my $file = shift or die "Missing file";
    my $mm2 = XML::LibXML->load_xml( location => $file ) or die "Not an XML file";
    # check if legal MM2 (or MMD) - TODO
    my $xc = XML::LibXML::XPathContext->new($mm2);
    $xc->registerNs('mm', MM2_NS);

    foreach my $dr_elem ($xc->findnodes('/*/mm:metadata[@name="dataref"]') ) { # locate dataref in MM2
        my $dataref = $dr_elem->findvalue('normalize-space(.)'); # chop trailing newlines in url
        my $t_refs = parseCatalog($dataref); # get xml from thredds
        print STDERR "THREDDS Refs = ", Dumper $t_refs if $opt{debug};

        # locate dataset in xml
        my ($dsid) = $dataref =~ /\?dataset=([^&]+)/; # try extracting thredds ID from URL
        my @keys = keys %$t_refs;
        $dsid = $keys[0] if @keys == 1; # if only one dataset in list, use it (make option? FIXME)
        $dsid = $opt{id} if exists $opt{id}; # id can be overridden on command line
        if (! defined $dsid) {
            print STDERR "Please specify dataset using -id parameter from the following:\n";
            print STDERR join( "\n", keys(%$t_refs)), "\n";
            exit 1;
        } elsif(! exists $t_refs->{$dsid}) {
            print STDERR "No URLs found for $dsid\n";
            exit 1;
        }

        # extract new datarefs and insert into MM2
        my $ds_refs = $t_refs->{$dsid};
        foreach my $service (keys %$ds_refs) {
            my $newNode = $dr_elem->cloneNode();
            $newNode->setAttribute('name', "dataref_$service");
            $newNode->appendTextNode( $ds_refs->{$service} );
            foreach ($xc->findnodes( "/*/mm:metadata[\@name='dataref_$service']") ) {
                #$_->unbindNode();
                $_->replaceNode( XML::LibXML::Comment->new( $_->toString ) );
            }
            $dr_elem->parentNode->insertAfter( $newNode, $dr_elem );
            $dr_elem->parentNode->insertAfter( XML::LibXML::Text->new("
  "), $dr_elem );
        }
    }

    print $mm2->toString(1);
}

# parse THREDDS XML Catalog doc and extract service URLs

sub parseCatalog {
    my $base = URI->new(shift) or die "Missing/improper URL";
    print STDERR "Parsing top catalog ...\n"     if $base =~ s|\.html$|\.xml|              && $opt{debug};
    print STDERR "Parsing level 2 dataset ...\n" if $base =~ s|catalog\.html|catalog\.xml| && $opt{debug};
    my $doc = getXML($base) or die;
    print $doc->toString(1) if $opt{full};
    my $xc = XML::LibXML::XPathContext->new($doc);
    $xc->registerNs('t', THREDDS_NS);
    my (%prefix, %datarefs);

    # since several compound services can be declared, we must index them all and check each dataset for the right one
    foreach my $cs ( $xc->findnodes('/t:catalog/t:service[@serviceType="Compound"]') ) {
        my $sname = $cs->getAttribute('name');
        $prefix{$sname} = {};
        foreach ( $cs->getChildrenByLocalName('service') ) {
            $prefix{$sname}{$_->getAttribute('serviceType')} = URI->new_abs($_->getAttribute('base'), $base);
        }
    }
    print STDERR "Service base URLs = ", Dumper \%prefix if $opt{debug};

    # catalogRef - not currently used for much
    foreach ($doc->getElementsByTagNameNS(THREDDS_NS, 'catalogRef') ) {
        my $link = URI->new_abs($_->getAttribute('xlink:href'), $base);
        printf STDERR "Catalog: %s\n", $link if $opt{debug};
    }

    # dataset
    foreach my $ds ($xc->findnodes('//t:dataset') ) {
        my $id = $ds->getAttribute('ID') or next;
        #printf STDERR "Dataset: '%s'\n", $id if $opt{debug};
        my $path = $ds->getAttribute('urlPath') or next;
        my $sname = $xc->findvalue('ancestor-or-self::t:dataset/t:metadata[@inherited="true"]/t:serviceName', $ds);
        my %paths;
        foreach (keys %{$prefix{$sname}}) {
            my $link = URI->new_abs($path, $prefix{$sname}{$_});
            $paths{$_} = "$link";
            #printf STDERR "  %11.11s: %s\n", $_, $link if $opt{debug};
        }
        $datarefs{$id} = \%paths;
    }
    return \%datarefs;
}

# fetch and parse XML from URL

sub getXML {
    my $url = shift or die "Missing URL";
    croak "getXML: Malformed URL in '$url'" unless $url =~ /^http:/;
    printf STDERR "GET %s ...\n", $url if $opt{debug};
    my $response = $ua->get($url);
    if ($response->is_success) {
        #print STDERR $response->content, "\n";
        eval {
            return XML::LibXML->load_xml( string => $response->content );
        } or croak($@);
    }
    else {
        printf STDERR "$url - %d %s\n", $response->code, status_message($response->code);
        croak "getXML failed for for $url: " . $response->status_line;
    }
}

=head1 NAME

B<get_dataref.pl > - get datarefs from THREDDS

=head1 DESCRIPTION

This script tries to figure out the various service URLs offered by THREDDS for
a given dataset (WMS, OPeNDAP, HTTP download etc), optionally inserting them
into a METAMOD MM2 document printed on stdout.

=head1 USAGE

  get_dataref.pl [--id <thredds_id>] [--full] [--debug] <dataref_url> | <mm2file>

=head1 ARGUMENTS

Either an URL to a THREDDS dataset (html or xml), or the path to a METAMOD MM2 document (.xml, not .xmd)

=head1 OPTIONS

=head2 --full

Dump returned THREDDS XML

=head2 --debug

Show diagnostic info

=head2 --id <thredds_id>

Specify THREDDS ID in case can't be determined from MM2 file

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

=head1 LICENSE

Copyright (C) 2014 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut

