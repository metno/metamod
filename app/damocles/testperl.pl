#!/usr/bin/perl -w
use strict;
use File::Copy;
use File::Path;
use XML::Simple qw(:strict);
use Data::Dumper;
use DBI;
use POSIX;
use warnings;
use Geo::Proj4;
use Fcntl;
use Mail::Mailer;
