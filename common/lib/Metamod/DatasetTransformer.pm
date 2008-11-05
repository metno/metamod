package Metamod::DatasetTransformer;

use 5.6.0;
use strict;
use warnings;
use Fcntl ':flock'; # import LOCK_* constants
use File::Spec;

our $VERSION = 0.2;

sub new {
    die "'new' not implemented yet: new(\$dataStr)\n";
}

sub getBasename {
    my ($self, $file) = @_;
    unless (__PACKAGE__->isa($self) or (defined ref($self) and ref($self) eq __PACKAGE__)) {
        # called as function, not method
        $file = $self; 
    }
    $file =~ s/\.\w+$//;
    return $file;
}

sub getFileContent {
    my ($self, $file) = @_;
    unless (__PACKAGE__->isa($self) or (defined ref($self) and ref($self) eq __PACKAGE__)) {
        # called as function, not method
        $file = $self; 
    }
    $file =~ s/\.\w+$//;
    my $xmdFile = "$file.xmd" if -f "$file.xmd";
    my $xmlFile = "$file.xml" if -f "$file.xml";
    my ($md, $ml);
    if ($xmdFile) {
        open $md, $xmdFile or die "cannot read $xmdFile: $!\n";
        flock $md, LOCK_SH or die "cannot lock $xmdFile: $!\n";
    }
    if ($xmlFile) {
        open $ml, $xmlFile or die "cannot read $xmlFile: $!\n";
        flock $ml, LOCK_SH or die "cannot lock $xmlFile: $!\n";
    }
    local $/ = undef;
    my $xmdStr = <$md> if $xmdFile;
    my $xmlStr = <$ml> if $xmlFile;
    close($ml) if $xmlFile;
    close($md) if $xmdFile;
    return ($xmdStr, $xmlStr);
}

sub getPlugins {
    my $classPath = __PACKAGE__;
    $classPath = File::Spec->catfile(split '::', $classPath);
    $classPath .= '.pm';
    my $fullClassPath = $INC{$classPath};
    my $basePluginPath = $fullClassPath;
    $basePluginPath =~ s/\.pm$//;
    my $d;
    opendir $d, $basePluginPath;
    my @files = grep {/\.pm$/ && -f File::Spec->catfile($basePluginPath,$_)} readdir $d;
    closedir $d;
    
    my @plugins;
    foreach my $file (@files) {
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

sub test {
    die "'test' not implemented yet\n";
}

sub transform {
    die "'transform' not implemented yet\n";
}

sub originalFormat {
    die "'originalFormat' not implemented yet\n";
}

1;
__END__

=head1 NAME

Metamod::DatasetTransformer - interface to transform datasets

=head1 SYNOPSIS

  use Metamod::DatasetTransfomer::Impl;
  my ($xmdStr, $xmlStr) = Metamod::DatasetTransfomer::getFileContent("filename");
  my $implX = new Metamod::DatasetTransfomer::ImplX($xmdStr, $xmlStr);
  my $datasetStr;
  if ($implX->test) {
      my ($dsDoc, $mm2Doc) = $implX->transform;
  }

=head1 DESCRIPTION

=head1 FUNCTIONS

=over 4

=item getBasename($filename)

return the filename without appendix

=item getFileContent("filename")

Read the content of filename.xmd and filename.xml. It is not considered a problem if one of the
files doesn't exist. In that case, the content is undef. This function will die if other problems
occur, i.e. filename is not readable (but exists) or flock fails.

Return: ($xmdContent, $xmlContent)

=item getPlugins

load and return list of plugins

Return: @array = (Metamod::DatasetTransformer::Impl1, Metamod::DatasetTransformer::Impl2, ...)

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

