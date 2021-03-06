=begin licence

----------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2013 met.no

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
----------------------------------------------------------------------------

=end licence

=cut

package Metamod::MMD::DAV;

use strict;
use warnings;

use Data::Dumper;
use HTTP::DAV;
use Metamod::Config;

__PACKAGE__->run(@ARGV) unless caller();

=head1 NAME

Metamod::MMD::DAV - read/write MMD documents from/to DAV store (presumable SVN)

=head1 SYNOPSIS



=head1 DESCRIPTION



=head1 FUNCTIONS

=head2 $resource = Metamod::MMD::DAV->new($name)

=head2 $resource = Metamod::MMD::DAV->new($name, $projectname)

=head2 $resource = Metamod::MMD::DAV->new($name, $projectname, $dav_url)

Set up a new editor object

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    my $config = Metamod::Config->new();

    my $project = shift || $config->get('APPLICATION_ID') or die "Missing project for metadata editor";
    my $base_url = shift || $config->get('METAEDIT_SVN_DAV');
    $base_url =~ s/\[PROJECT\]/$project/;
    $self->{'url'} = $base_url;
    #print STDERR "Opening $self->{'url'} for business\n";

    $self->{'dav'} = HTTP::DAV->new();
    $self->{'dav'}->credentials(
        -user  => $config->get('METAEDIT_SVN_DAV_USER'),
        -pass  => $config->get('METAEDIT_SVN_DAV_PASSWORD'),
        -url   => $base_url,
        #-realm => "DAV Realm"
    );
    #print STDERR Dumper $self;
    my $r = $self->{'dav'}->open( $self->{'url'} )
        or die "Could not open DAV resource $self->{'url'}";
    ## Make a null lock on newdir
    #$self->{'dav'}->lock( -url => $base_url, -timeout => "10m" )
    #    or die "Won't put unless I can lock for 10 minutes\n";
    return $self;
}

#sub DESTROY {
#    my $self = shift;
#    $self->{'dav'}->unlock( -url => $self->{'url'} );
#}

=head2 $resource->find()

Return result of propfind (HTTP::DAV::Resource object)

=cut

sub find {
    my $self = shift;
    my $d = $self->{'dav'};
    my %docs;

    if ( my $r = $d->propfind( -url => $self->{'url'}, -depth => 1) ) {
        if ( $r->is_collection ) {
            my $rlist = $r->get_resourcelist;
            #printf STDERR "Collection: %s %s\n", ref $rlist, $rlist->as_string;
            foreach ($rlist->get_resources) {
                my $uri = $_->get_property('rel_uri'); # $_->get_uri->rel( $self->{'url'} )->as_string;
                $docs{$uri} = { lastmodified => $_->get_property('lastmodifiedepoch') };
            }
        } else {
            my $uri = $r->get_property('rel_uri'); # $r->get_uri->rel( $self->{'url'} )->as_string;
            $docs{$uri} = { lastmodified => $r->get_property('lastmodifiedepoch') };
        }
        return \%docs;
    } else {
        print STDERR $d->message;
    }
}

=head2 $resource->get($docname)

Download a document from the SVN repo

=cut

sub get {
    my $self = shift;
    my $docname = shift or die "Missing resource name";
    my $xml;
    my $dav = $self->{'dav'};
    my $url = $self->{'url'} . "$docname.xml";
    $dav->get($url, \$xml) or die "cannot GET from $url: ". $dav->message;
    #print "$xml\n";
    return $xml;
}

=head2 $resource->put($doc)

=head2 $resource->put($doc, $docname)

Upload a document to the SVN repo.

$doc may be filename or ref to XML string; in the latter case $docname is required

=cut

sub put {
    my $self = shift;
    my $doc = shift or die "Missing document filename";
    my $docname = shift;
    die "Missing document name" if ref $doc && !$docname;
    my $url = $self->{'url'};
    $url .= "$docname.xml" if $docname;
    my $dav = $self->{'dav'};
    $dav->put($doc, $url) or die "cannot PUT to $url: ". $dav->message;
    return $dav->is_success;
}

=head2 $resource->delete($docname)

Delete a document in the SVN repo.

=cut

sub delete {
    my $self = shift;
    my $docname = shift or die "Missing document name";
    my $url = $self->{'url'} . "$docname.xml";
    my $dav = $self->{'dav'};
    $dav->delete($url) or die "cannot DELETE $url: ". $dav->message;
    return $dav->is_success;
}

=head2 run

Run tests from command line

=cut

sub run {
    my $self = shift;
    my $file = shift @ARGV;
    if ($file) {
        test($file);
    } else {
        print STDERR "Usage: perl $0 <xmlfile>\n";
        exit 1;
    }
}

sub test {
    my $file = shift or die "Missing input file parameter";
    my $dataset = -f $file ? `basename $file .xml` : $file; # rewrite to use some File::* method
    chomp $dataset;

    my $r = Metamod::MMD::DAV->new();
    $r->{'dav'}->DebugLevel(1);
    my $coll = $r->find();

    if (my $lastmod = $$coll{"$dataset.xml"}->{'lastmodified'}) {
        printf STDERR "%s: <<%s<< >>%s>>\n", $dataset, scalar localtime( (stat($file))[10] ), scalar localtime($lastmod);
        my $doc = $r->get($dataset);
        print $doc;
        eval {
            $r->put($file, 'dummy_test');
            my $doc2 = $r->get('dummy_test');
            print $doc2;
            $r->delete('dummy_test');
        } or die $@;
    } else {
        eval {
            $r->put($file);
            my $doc = $r->get($dataset);
            $r->delete($dataset);
        } or die $@;
    }

    #eval { $r->put(\$doc, 'test2.xml') } or die $@;
}

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
