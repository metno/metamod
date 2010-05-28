#! /usr/bin/perl -w
use strict;
use warnings;

my $mmVersion = 'VERSION';
my $changeLog = 'debian/changelog';

my $chMajorVersion;
open my $ch, $changeLog or die "Cannot read $changeLog: $!\n";
while (defined (my $line = <$ch>)) {
    if ($line =~ /metamod-(\d+\.\w+)/) {
        $chMajorVersion = $1;
        last;
    }
}
close $ch;
die "no changelog version" unless $chMajorVersion;

my $mmMajorVersion;
open my $mh, $mmVersion or die "Cannot read $mmVersion: $!\n";
while (defined (my $line = <$mh>)) {
    if ($line =~ /version\s+(\d+\.\w+)/) {
        $mmMajorVersion = $1;
        last;
    }
}
close $mh;
die "no VERSION version" unless $mmMajorVersion;

if ($chMajorVersion ne $mmMajorVersion) {
    die "version mismatch between $mmVersion and $changeLog: $mmMajorVersion <=> $chMajorVersion\n";
}
exit 0;