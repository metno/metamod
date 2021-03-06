=begin licence

----------------------------------------------------------------------------
METAMOD - Web portal for metadata search and upload

Copyright (C) 2009 met.no

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


=head1 NAME

Metamod::MetadataEditor - interface with MMD metadataeditor

=head1 SYNOPSIS

    use Metamod::MetadataEditor;
    my $editor = Metamod::MetadataEditor->new();
    my $xml =  $editor->download_mmd($datasetname);
    my $GUI_url = $editor->upload_mmd($datasetname, $mmd-string);

=head1 DESCRIPTION

Create an editor object for a given project (default APPLICATION_ID).

Designed to be used in conjunction with the met.no Metadata Editor available at L<https://github.com/metno/metadata-editor>.

=cut

package Metamod::MetadataEditor;

use strict;
use warnings;

use LWP::UserAgent; # rewrite to use HTTP::Request - FIXME
use HTTP::Request;


use Metamod::Config;
use Metamod::MMD;
use Data::Dumper;

__PACKAGE__->run(@ARGV) unless caller();

=head1 FUNCTIONS/METHODS

=head2 $editor = Metamod::MetadataEditor->new()

=head2 $editor = Metamod::MetadataEditor->new($projectname)

=head2 $editor = Metamod::MetadataEditor->new($projectname, $editor_url)

Set up a new editor object

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my $config = Metamod::Config->new();
    my $project = shift || $config->get('APPLICATION_ID') or die "Missing project for metadata editor";
    $self->{'editor_url'} = shift || $config->get('METAEDIT_WS_URL') or die "Missing metadata editor URL";
    $self->{'editor_url'} =~ s/\[PROJECT\]/$project/;

    $self->{'DEBUG'} = 1 unless caller();
    return $self;
}

=head2 $editor->editor_url($datasetname)

Return API URL for a given dataset

=cut

sub editor_url {
    my $self = shift;
    my $docname = shift or die "Missing document name";
    my $url = $self->{'editor_url'};
    $url =~ s/\[DATASET\]/$docname/;
    #print STDERR "*** EDITOR webservice URL = $url\n";
    return $url;
}

=head2 $editor->upload_mmd($datasetname, $document)

Upload a document to the editor

Accepts document as string, filehandle or DOM object (TODO)

=cut

sub upload_mmd {
    my $self = shift;
    my $docname = shift or die "Missing document name";
    my $mmd = shift or die "Missing document";
    my $url = $self->editor_url($docname);

    # encode XML entitites in $mmd here - FIXME
    # check if string/filehandle/DOM - FIXME

    my $ua = LWP::UserAgent->new;
    $ua->timeout(180);

    #my $response = $ua->post($url, 'metadata' => $mmd);
    my $req = HTTP::Request->new( 'POST', $url );
    $req->content( $mmd );
    my $response = $ua->request($req);

    unless ($response->is_success) {
        die "cannot upload to $url: ". $response->message;
    #} else {
        #print STDERR $response->decoded_content . "\n";
    }
    return $response->decoded_content;
}

=head2 $editor->download_mmd($datasetname)

Download a document from the editor

=cut

sub download_mmd {
    my $self = shift;
    my $docname = shift or die "Missing document name";
    my $url = $self->editor_url($docname);

    my $ua = LWP::UserAgent->new;
    $ua->timeout(180);
    my $response = $ua->get($url);

    unless ($response->is_success) {
        die "cannot download from $url: ". $response->message;
    } else {
        #print STDERR $response->decoded_content . "\n";
    }
    return $response->decoded_content;
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
    }
}

sub test {
    my $file = shift or die "Missing input file parameter";
    #my $config = Metamod::Config->new();
    my $dataset = `basename $file .xml`; # rewrite to use some File::* method
    chomp $dataset;

    my $editor = Metamod::MetadataEditor->new(); # for testing put project into METAEDIT_WS_URL in config
    my $doc = Metamod::MMD->new($file)->mmd;
    print STDERR "**** $dataset:\n" . $doc->toString(2);

    my $GUI_url = $editor->upload_mmd($dataset, $doc->toString);
    print STDERR "Edit at $GUI_url\n";

    my $xml = $editor->download_mmd($dataset);
    #print STDERR "$xml\n\n";
    my $doc2 = Metamod::MMD->new($xml);
    printf STDERR "*** Returned MMD: ***\n%s\n\n*** Converted MM2: ***\n%s\n", $doc2->{'dom'}->toString(2), $doc2->mm2->toString(2);

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
