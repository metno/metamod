#!/usr/bin/perl -w

=begin LICENCE

----------------------------------------------------------------------------
  METAMOD - Web portal for metadata search and upload

  Copyright (C) 2013 met.no

  Contact information:
  Norwegian Meteorological Institute
  Box 43 Blindern
  0313 OSLO
  NORWAY
  email: geir.aalberg@met.no

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

=end LICENCE

=cut

use strict;
use warnings;

use File::Path qw(mkpath);
#use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/common/lib";
use Metamod::Config; # this depends only on core modules
use Pod::Usage;

#sub usage {
#    printf "Usage:$0 <config_dir>\n";
#    exit 1;
#}

my $config_dir = $ARGV[0] or pod2usage(1);

if (!Metamod::Config->config_found($config_dir)){
  die "Could not find the configuration on the command line or the in the environment\n";
}

my $config = Metamod::Config->new($config_dir, { nolog => 1 });

if (-f $config_dir) {
    $config_dir = `dirname $config_dir`;
    chomp $config_dir;
}

mkpath "$config_dir/bin";

open my $file, '>', "$config_dir/bin/activate";
while (<DATA>) {
    s/\[==([A-Z0-9_]+)==\]/$config->get($1)/ge;
    print $file $_;
    #print $_;
}
close($file);

=head1 NAME

B<virtualenv.pl> - check METAMOD master_config

=head1 DESCRIPTION

Perl version of Python's virtualenv, modified to METAMOD environment

=head1 USAGE

 virtualenv.pl <path_to_config_dir>

=head1 AUTHOR

Geir Aalberg, E<lt>geira@met.noE<gt>

Based on penv.pl (C) 2010 Joe Topjian. Used by permission.
L<http://terrarum.net/development/perl-virtual-environments.html>

=head1 LICENSE

Copyright (C) 2013 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut

__DATA__
# Create an environment for running METAMOD from the commandline.
# This is just a convenience for setting the correct lib paths and
# master config environment
#
# This file must be used with "source bin/activate" *from bash*
# you cannot run it directly
#
# Created by virtualenv.pl

deactivate () {
    # reset old environment variables
    if [ -n "$_OLD_VIRTUAL_PERL5LIB" ] ; then
    	export PERL5LIB="$_OLD_VIRTUAL_PERL5LIB"
    else
	unset PERL5LIB
    fi
    unset _OLD_VIRTUAL_PERL5LIB

    # This should detect bash and zsh, which have a hash command that must
    # be called to get it to forget past commands.  Without forgetting
    # past commands the $PATH changes we made may not be respected
    if [ -n "$BASH" -o -n "$ZSH_VERSION" ] ; then
        hash -r
    fi

    if [ -n "$_OLD_VIRTUAL_PS1" ] ; then
        PS1="$_OLD_VIRTUAL_PS1"
        export PS1
        unset _OLD_VIRTUAL_PS1
    fi

    if [ -n "$_OLD_VIRTUAL_PATH" ] ; then
        PATH="$_OLD_VIRTUAL_PATH"
        export PATH
        unset _OLD_VIRTUAL_PATH
    fi

    unset VIRTUAL_ENV
    if [ ! "$1" = "nondestructive" ] ; then
    # Self destruct!
        unset -f deactivate
    fi
}

# unset irrelevant variables
deactivate nondestructive

export METAMOD_MASTER_CONFIG=[==CONFIG_DIR==]

export _OLD_VIRTUAL_PATH="$PATH"
ROOT=[==INSTALLATION_DIR==]
export PATH=$PATH:"$ROOT:$ROOT/base/init":"$ROOT/base/userinit":"$ROOT/base/scripts":"$ROOT/common":"$ROOT/common/scripts":"$ROOT/catalyst/script"

if [ -n "[==CATALYST_LIB==]" ]; then
    export _OLD_VIRTUAL_PERL5LIB="$PERL5LIB"
    export PERL5LIB=$PERL5LIB:"[==CATALYST_LIB==]"
fi

if [ -z "$VIRTUAL_ENV_DISABLE_PROMPT" ] ; then
    _OLD_VIRTUAL_PS1="$PS1"
    export PS1="\033[1;44m([==CONFIG_DIR==])\033[1;m $PS1"
fi

# This should detect bash and zsh, which have a hash command that must
# be called to get it to forget past commands.  Without forgetting
# past commands the $PATH changes we made may not be respected
if [ -n "$BASH" -o -n "$ZSH_VERSION" ] ; then
    hash -r
fi

if [ -d "[==CATALYST_LIB==]" ]; then
    eval $(perl -I[==CATALYST_LIB==] -Mlocal::lib=[==CATALYST_LIB==])
fi
