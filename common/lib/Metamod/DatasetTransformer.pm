#----------------------------------------------------------------------------
#  METAMOD - Web portal for metadata search and upload
#
#  Copyright (C) 2008 met.no
#
#  Contact information:
#  Norwegian Meteorological Institute
#  Box 43 Blindern
#  0313 OSLO
#  NORWAY
#  email: Heiko.Klein@met.no
#
#  This file is part of METAMOD
#
#  METAMOD is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  METAMOD is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with METAMOD; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#----------------------------------------------------------------------------
package Metamod::DatasetTransformer;

use 5.6.0;
use strict;
use warnings;
use Data::Dumper;
use Cwd;
use Carp;
use Fcntl ':flock'; # import LOCK_* constants
use File::Spec;
use XML::LibXML;
use XML::LibXSLT;
use UNIVERSAL;
use Metamod::Config;
use Log::Log4perl;

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

my $logger = Log::Log4perl::get_logger('metamod::common::Metamod::DatasetTransformer');

my @plugins;

# single parser
use constant XMLParser => new XML::LibXML();
use constant XSLTParser => new XML::LibXSLT();

sub xslt_dir {

    if ($ENV{METAMOD_XSLT_DIR}) {
        return $ENV{METAMOD_XSLT_DIR}
    } else {
        my $config = Metamod::Config->instance();
        return $config->get("INSTALLATION_DIR") . '/common/schema/';
    }
}


sub new {
    die "'new' not implemented yet in $_[0]: new(\$dataStr)\n";
}

sub getBasename {
    my ($self, $file) = @_;
    unless (UNIVERSAL::isa($self, __PACKAGE__)) {
        # called as function, not method
        $file = $self;
    }
    if ($file) {
        $file =~ s/\.xm[dl]$//;
    } else {
        $logger->logcarp('getBasename called without filename');
    }
    return $file;
}

sub getFileContent {
    my ($self, $file) = @_;
    unless (UNIVERSAL::isa($self, __PACKAGE__)) {
        # called as function, not method
        $file = $self;
        $self = __PACKAGE__;
    }
    $file = $self->getBasename($file);
    my $xmdFile = -f "$file.xmd" ? "$file.xmd" : '';
    my $xmlFile = -f "$file.xml" ? "$file.xml" : '';
    $logger->debug("Base + xml + xmd: $file : $xmdFile : $xmlFile");
    my ($md, $ml);
    if ($xmdFile) {
        open $md, $xmdFile or die "cannot read $xmdFile: $!\n";
        flock $md, LOCK_SH or die "cannot lock $xmdFile: $!\n";
    }
    if ($xmlFile) {
        open $ml, $xmlFile or die "cannot read $xmlFile: $!\n";
        flock $ml, LOCK_SH or die "cannot lock $xmlFile: $!\n";
    }
    binmode $md if $md; # drop all PerlIO layers possibly created by a use open pragma
    binmode $ml if $ml;

    local $/ = undef;
    my $xmdStr = <$md> if $xmdFile;
    my $xmlStr = <$ml> if $xmlFile;
    close($ml) if $xmlFile;
    close($md) if $xmdFile;
    return ($xmdStr, $xmlStr);
}

sub getPlugins {
    return @plugins if @plugins;
    my $classPath = __PACKAGE__;
    $classPath = File::Spec->catfile(split '::', $classPath);
    $classPath .= '.pm';
    my $fullClassPath = $INC{$classPath};
    my $basePluginPath = $fullClassPath;
    $basePluginPath =~ s/\.pm$//;
    #$logger->debug(" *** \$classPath=$classPath \$basePluginPath=$basePluginPath");
    #print STDERR Dumper \@INC;
    my $d;
    opendir $d, $basePluginPath or die "cannot read DatasetTransformer dir at $basePluginPath\nCurrent dir is ". cwd(); # this will most probably fail
    my @files = grep {/\.pm$/ && -f File::Spec->catfile($basePluginPath,$_)} readdir $d;
    closedir $d;

    my @plugins;
    foreach my $file (@files) {
        next if substr($file, 0, 2) eq 'To'; # Ignore modules To other formats
        my $plugin = __PACKAGE__ . "::$file";
        $plugin =~ s/\.pm$//;
        eval "require $plugin";
        if ($@) {
            warn "cannot load module $plugin: $@";
            next;
        }
        push @plugins, $plugin;
    }
    return @plugins;
}

BEGIN {
    @plugins = getPlugins();
}

# difficult to unit-test, since options for $plugin->new are unknown (xslt files)
sub autodetect {
    my ($arg) = @_;
    return unless $arg;
    my $fds;
    if (UNIVERSAL::isa($arg, "Metamod::ForeignDataset")) {
        $fds = $arg;
    } else {
        $fds = Metamod::ForeignDataset->newFromFile($arg);
    }
    my @plugins = Metamod::DatasetTransformer::getPlugins();
    foreach my $plugin (@plugins) {
        my $p = $plugin->new($fds->getXMD_XML(), $fds->getMETA_XML());
        if ($p->test) {
            return $p;
        }
    }
    return undef;
}

sub test {
    die "'test' not implemented in $_[0] yet\n";
}

sub transform {
    die "'transform' not implemented in $_[0] yet\n";
}

sub originalFormat {
    die "'originalFormat' not implemented in $_[0] yet\n";
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer - interface to transform datasets to internal MM2 presentation

=head1 SYNOPSIS

  use Metamod::DatasetTransfomer::Impl;
  my ($xmdStr, $xmlStr) = Metamod::DatasetTransfomer::getFileContent("filename");
  my $implX = new Metamod::DatasetTransfomer::ImplX($xmdStr, $xmlStr);
  my $datasetStr;
  if ($implX->test) {
      my ($dsDoc, $mm2Doc) = $implX->transform;
  }

  # or
  my $implX = Metamod::DatasetTransfomer::autodetect("filename");
  ...

=head1 DESCRIPTION

The DatasetTransformer transform datasets from different plugin formats
to the internally used MM2 format.

=head2 VARIABLES

=over 4

=item $XSLT_DIR

Default directory of XSLT files. Uses ENV{METAMOD_XSLT_DIR} or
$config->get("SOURCE_DIRECTORY") . '/common/schema/'. The ENV part
is mainly thought for testing independently of config.

=back

=head2 FUNCTIONS

=over 4

=item XMLParser

Return: the xml parser as L<XML::LibXML> singleton. Use this parser to make sure, that the
parser doesn't go out of scope. (To prevent XML::LibXML warnings when deregistering nodes from the parser.)

=item XSLTParser

Return: the xml parser as L<XML::LibXML> singleton. Use this parser to make sure, that the
parser doesn't go out of scope. (To prevent XML::LibXML warnings when deregistering nodes from the parser.)

=item getBasename($filename)

return the filename without appendix

=item getFileContent("filename")

Read the content of filename.xmd and filename.xml. It is not considered a problem if one of the
files doesn't exist. In that case, the content is undef. This function will die if other problems
occur, i.e. filename is not readable (but exists) or flock fails.

Return: ($xmdContent, $xmlContent)

=item getPlugins

load and return list of plugins, that are packages below Metamod::DatasetTransformer, not starting
with "To"

Return: @array = (Metamod::DatasetTransformer::Impl1, Metamod::DatasetTransformer::Impl2, ...)

=back

=item autodetect($foreignDataset|$baseFileName)

Create a datasettransformer from a Metamod::ForeignDataset or from a file. Try to autodetect
the plugin from all available plugins.

Return: $datasetTransformer

=back

=head1 METHODS

These methods need to be implemented by the extending modules.

=over 4

=item new($xmdStr, $xmlStr)

Initialize the class with the appropriate data. $xmdStr and $xmlStr might be empty, but then the tests
might fail.

=item test

Test if the data belongs to this transformer. Return 1 on success 0 on failure. This method should not die,
except for severe programming errors.

=item transform

Transform the file to the 'dataset' and 'MM2' format. This functions returns two XML::LibXML::Documents. This function should die
if L<test> returns 0, or if the test wasn't sufficient.

return ($datasetDoc, $mm2Doc)

=item originalFormat

return a string describing the original format

=back

=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<XML::LibXML>

=cut
