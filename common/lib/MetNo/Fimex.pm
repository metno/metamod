package MetNo::Fimex;

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

MetNo::Fimex - wrapper for fimex

=head1 SYNOPSIS

  use MetNo::Fimex;

  %fimexParams = ('input.file' => 'test.nc',
                  'input.type' => 'netcdf',
                  'output.file' => 'out.nc',
                  'output.type' => 'netcdf',
                  'interpolate.method' => 'nearestneighbor',
                  'interpolate.projString' => '+proj=latlong +elips=sphere +a=6371000 +e=0',
                  'interpolate.xAxisValues' => '-60,-59,-58,...,-30',
                  'interpolate.yAxisValues' => '50,51,52,...,70',
                  'interpolate.metricAxes' => 1);
  eval { MetNo::Fimex::projectFile(%fimexParams); };
  if ($@) {
      # do something with this error
  }

=head1 DESCRIPTION

This is a perl-wrapper around calling fimex. It will do some simple parameter-checking
and call the fimex program internally.

To debug, set $MetNo::Fimex::DEBUG to 1 before calling projectFile.

=head1 FUNCTIONS

=cut

our $VERSION = do { my @r = (q$LastChangedRevision$ =~ /\d+/g); sprintf "0.%d", @r };

our $DEBUG = 0;

use strict;
use warnings;
use Params::Validate qw();
use Moose;
use LWP::Simple qw();
use File::Spec qw();
use File::Temp qw();

=head1 METHODS

=head2 new

generate a fimex object

=head2 program

Get or set the path of the fimex-program. Defaults to 'fimex' in the PATH.

=cut
has 'program' => (
    is => 'rw',
    isa => 'Str',
    default => 'fimex',
);

=head2 inputURL([$str])

Get or set the input-url. This will automatically  set the input-file to ''.

=cut
has 'inputURL' => (
    is => 'rw',
    isa => 'Str',
    trigger => \&_unset_inputfile,
);

sub _unset_inputfile {
    my ($self, $inputurl) = @_;
    if ($inputurl) {
        $self->inputFile('');
    }
}

=head2 inputFile([$str])

Get or set the input-file. This will automatically  set the input-url to ''.

=cut
has 'inputFile' => (
    is => 'rw',
    isa => 'Str',
    trigger => \&_unset_inputurl,
);
sub _unset_inputurl {
    my ($self, $inputfile) = @_;
    if ($inputfile) {
        $self->inputURL('');
    }
}

=head2 inputConfig([$str])

Get or set the input config. Use '' to use noe config.

=cut
has 'inputConfig' => (
    is => 'rw',
    isa => 'Str',
);

=head2 outputFile([$str])

Get or set the outputfile. Select only the file-part, without directory. use outputdir to set the
directory. If '', a L<Temp::File> object will be selected.

=cut
has 'outputFile' => (
    is => 'rw',
    isa => 'Str'
);
=head2 outputDirectory([$str])

Get or set the outputdirectory. Defaults to File::Spec->tmpdir

=cut
has 'outputDirectory' => (
    is => 'rw',
    isa => 'Str',
    default => File::Spec->tmpdir()
);

=head2 outputConfig([$str])

Get or set the outputconfig. Use '' to not use a config.

=cut
has 'outputConfig' => (
    is => 'rw',
    isa => 'Str',
);
=head2 projString([$str])

Get or set the proj4 string.

=cut
has 'projString' => (
    is => 'rw',
    isa => 'Str',
);
=head2 interpolateMethod([$str])

Get or set the interpolation method. Defaults to nearestneighbor.

=cut
has 'interpolateMethod' => (
    is => 'rw',
    isa => 'Str',
    default => 'nearestneighbor',
);

=head2 xAxisValues([$str])

Get or set the xAxisValues for the reprojection in fimex format.

=cut
has 'xAxisValues' => (
    is => 'rw',
    isa => 'Str',
);
=head2 xAxisValues([$str])

Get or set the xAxisValues for the reprojection in fimex format.

=cut
has 'yAxisValues' => (
    is => 'rw',
    isa => 'Str',
);

=head2 metricAxes([1|0])

Get or set if reprojected axes are metric or degree

=cut
has 'metricAxes' => (
    is => 'rw',
    isa => 'Bool',
);


=head2 doWork

This will trigger the download of data (if required) and trigger fimex to to the conversion.
It will die if fimex throws an error, i.e. if parameters are missing.

It might internally set some variables, i.e. outputdirectory or outputfile if those are undefined.

Returns the fimex command, mostly for debugging reasons

=cut
sub doWork {
    my ($self) = @_;
    my $inputTemp; # make sure the temporary file object survives the fimex-call
    my $input;
    if ($self->inputURL) {
        $inputTemp = _downloadToTemp($self->inputURL, $self->outputDirectory);
        $input = $inputTemp-filename();
    } else {
        $input = $self->inputFile;
    }
    unless ($input) {
        die "no input file or url";
    }

    my $temp; # make sure the temporary file object survives the fimex-call
    unless ($self->outputFile) {
        $temp = File::Temp->new(TEMPLATE => 'fimexXXXXXX',
                                DIR => $self->outputDirectory,
                                SUFFIX => '.nc',
                                UNLINK => 0);
        my $filename = (File::Spec->splitpath($temp->filename()))[2];
        $self->outputFile($filename);
    }
    my $outputPath;
    if ($self->outputDirectory) {
        $outputPath = File::Spec->catfile($self->outputDirectory, $self->outputFile);
    } else {
        $outputPath = $self->outputFile;
    }

    my $command;
    if ($self->projString) {
        my %args;
        # map attributes to projectFile arguments
        $args{fimexProgram} = $self->program;
        $args{'input.file'} = $input;
        $args{'input.config'} = $self->inputConfig if $self->inputConfig;
        $args{'output.file'} = $outputPath;
        $args{'output.config'} = $self->outputConfig if $self->outputConfig;
        $args{'interpolate.method'} = $self->interpolateMethod;
        $args{'interpolate.projString'} = $self->projString;
        $args{'interpolate.metricAxes'} = $self->metricAxes;
        $args{'interpolate.xAxisValues'} = $self->xAxisValues;
        $args{'interpolate.yAxisValues'} = $self->yAxisValues;

        $command = projectFile(%args);
    } else {
        # no changes, just copy to output
        File::Copy::copy($input, $outputPath)
            or die "cannot copy $input to $outputPath: $!\n";
    }
    return $command; # for debugging
}

# downloadToTemp($url, $dir)
# fetch a url to a temporary file, return the temporary file in dir
sub _downloadToTemp {
    my ($url, $dir) = @_;

    my $temp = File::Temp->new(TEMPLATE => 'fimexDownloadXXXXX',
                               SUFFIX => '.nc',
                               DIR => $dir,
                               UNLINK => 0);
    my $rc = LWP::Simple::getstore($url, $temp->filename());
    unless (LWP::Simple::is_success($rc)) {
        die "cannot download from $url: $rc";
    }
    return $temp->filename();
}

no Moose;
__PACKAGE__->meta->make_immutable;
# below follow static functions

=head2 projectFile

reproject a file using fimex

=over 4

=item %fimexParas a list of fimex parameters. Accepted are the input.*, output.*
      and the interpolate.* parameters. Additional parameters are fimexProgram (if
      fimex is not in your PATH) and interpolate.metricAxes => 1/0 which is a shortcut
      for interpolate.?AxisValues.

=back

=cut
sub projectFile {
    my %p = Params::Validate::validate( @_, {
        'fimexProgram' => {default => 'fimex'},
        'input.file' => 1,
        'input.type' => {default => 'nc'},
        'input.config' => 0,
        'output.type' => {default => 'nc'},
        'output.file' => 1,
        'output.config' => 0,
        'interpolate.method' => {default => 'nearestneighbor'},
        'interpolate.projString' => 1,
        'interpolate.xAxisValues' => 1,
        'interpolate.yAxisValues' => 1,
        # either ?axisUnit or metricAxes is required
        'interpolate.xAxisUnit' => 0,
        'interpolate.yAxisUnit' => 0,
        'interpolate.metricAxes' => {type => Params::Validate::BOOLEAN, optional => 1},
        # the following are currently ignored
        'interpolate.latitudeName' => 0,
        'interpolate.longitudeName' => 0,
        'interpolate.printCS' => 0
    });

    if (exists $p{'interpolate.metricAxes'}) {
        if ($p{'interpolate.metricAxes'}) {
            $p{'interpolate.xAxisUnit'} = 'm';
            $p{'interpolate.yAxisUnit'} = 'm';
        } else {
            $p{'interpolate.xAxisUnit'} = 'degree_east';
            $p{'interpolate.yAxisUnit'} = 'degree_north';
        }
        delete $p{'interpolate.metricAxes'};
    }

    my @args = delete $p{fimexProgram};
    foreach my $key (sort keys %p) {
        push @args, '--'.$key, $p{$key};
    }
    my $command = join ' ', @args;
    if ($DEBUG > 0) {
        print STDERR $command, "\n" if $DEBUG == 1;
    } else {
        system(@args) == 0
            or die "system @args failed: $?";
    }
    return $command; # usually not used, just for debugging
}


1;
__END__


=head1 AUTHOR

Heiko Klein, E<lt>H.Klein@met.noE<gt>

=head1 SEE ALSO

L<http://wiki.met.no/fimex/>

=cut