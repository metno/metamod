#!/usr/bin/perl -w

=begin LICENCE

----------------------------------------------------------------------------
  METAMOD - Web portal for metadata search and upload

  Copyright (C) 2008 met.no

  Contact information:
  Norwegian Meteorological Institute
  Box 43 Blindern
  0313 OSLO
  NORWAY
  email: egil.storen@met.no

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

use FindBin qw($Bin);
use lib "$Bin/../../common/lib", , "$Bin/../lib";
use Metamod::Config;
use Getopt::Long;
#use Pod::Usage; # rewrite - FIXME

my ($opt_p, $config_file_or_dir);
GetOptions('p' => \$opt_p, # print to stdout
           'config=s' => \$config_file_or_dir,
) or usage();

usage() unless Metamod::Config->config_found($config_file_or_dir);

my $config = Metamod::Config->new($config_file_or_dir, { nolog => 1 } );

my $funcdefs = <<'EOT';
declare -A NAGIOS=(
    ["OK"]=0
    ["WARN"]=1
    ["CRIT"]=2
    ["UNKNOWN"]=3
)

FINAL=0

function set_status {
    EXIT=${NAGIOS[$1]}
    EXIT_TEXT=$1
    if [[ $EXIT > $FINAL ]]
    then
        FINAL=$EXIT
    fi
}

function get_status {
    set_status OK
    TEXT="`service $1 status 2>/dev/null`"
    STATUS=$?
    [ $STATUS -ne 0 ] && set_status CRIT
    [ "$TEXT" == "" ] && TEXT="(service command did not supply any textual status)"
}

function check_catalyst_process {
    service="catalyst-$APPLICATION_ID"
    get_status $service

    if [[ $TEXT =~ Catalyst[[:space:]]is[[:space:]]running[[:space:]]on[[:space:]]PID[[:space:]]([0-9]+) ]]
    then
        PID=${BASH_REMATCH[1]}
        CHILDREN=`pgrep -c -P $PID`
        PERFDATA="workers=$CHILDREN"
    else
        PERFDATA='workers=0'
    fi

    echo $EXIT Service_$service $PERFDATA $EXIT_TEXT - $TEXT
}


function check_daemons {
    service="metamodServices-$APPLICATION_ID"
    get_status $service
    DAEMONS=`perl -E "@d = '$TEXT' =~ /(\w+) is running/g; say scalar @d"`
    echo $EXIT Service_$service daemons=$DAEMONS $EXIT_TEXT - $TEXT
}

function check_http_responses {
    TEMPFILE="/tmp/$(basename $0).$$.tmp"

    # testing directly against Catalyst
    set_status OK
    DELAY=`curl -o $TEMPFILE -s -w %{time_total} http://localhost:$CATALYST_PORT/settings/VERSION`
    if [ $? -ne 0 ]; then
        set_status CRIT
        TEXT="Catalyst not responding"
    else
        #TEXT="Version `cat $TEMPFILE`"
        TEXT="Response time: $DELAY sec"
    fi
    echo "$EXIT Catalyst_response_time_$APPLICATION_ID time=$DELAY;0.1;1 $EXIT_TEXT - $TEXT"


    # testing via Apache proxy
    set_status OK
    HTTP_CODE=`curl -o $TEMPFILE -s -w %{http_code} $BASE_PART_OF_EXTERNAL_URL$LOCAL_URL/settings/VERSION`
    if [ $? -ne 0 -o "$HTTP_CODE" -ge "400" ]; then
        set_status CRIT
    elif [ "$HTTP_CODE" -ge "300" ]; then
        set_status WARN
    fi
    echo "$EXIT Apache_HTTP_status_$APPLICATION_ID code=$HTTP_CODE $EXIT_TEXT - HTTP Status $HTTP_CODE"


    # testing robots.txt (via Apache)
    set_status OK
    HTTP_CODE=`curl -o $TEMPFILE -s -w %{http_code} $BASE_PART_OF_EXTERNAL_URL/robots.txt`
    if [ $? -ne 0 -o "$HTTP_CODE" -ge "400" ]; then
        set_status CRIT
    elif [ "$HTTP_CODE" -ge "300" ]; then
        set_status WARN
    else
        grep -q "Disallow: $LOCAL_URL/search" $TEMPFILE || set_status CRIT
    fi
    echo "$EXIT Apache_robots.txt_$APPLICATION_ID code=$HTTP_CODE $EXIT_TEXT - HTTP Status $HTTP_CODE"


    # testing OAI-PMH
    # we could possible change this to oai?verb=ListSets to decrease load
    set_status OK
    RECORDS=0
    PERIOD=`date -d "-30 days" -I`
    DELAY=`curl -o $TEMPFILE -s -w %{time_total} http://localhost:$CATALYST_PORT/oai\?verb=ListIdentifiers\&metadataPrefix=dif\&from=$PERIOD`
    if [ $? -ne 0 ]; then
        set_status CRIT
        TEXT="OAI-PMH service not responding"
    else
        xmllint --format $TEMPFILE >$TEMPFILE.2 2>/dev/null
        if [ $? -ne 0 ]; then
            set_status CRIT
            TEXT="Cannot parse XML"
        else
            # count identifier tags
            RECORDS=`grep -c '<identifier>' $TEMPFILE.2`
            TEXT="Returned $RECORDS records in $DELAY sec"
        fi
    fi
    echo "$EXIT OAI-PMH_status_$APPLICATION_ID records=$RECORDS|time=$DELAY;1;5 $EXIT_TEXT - $TEXT"

    # cleaning up so Martin won't kick your butt
    rm -r $TEMPFILE $TEMPFILE.2
}

function count_files {
    set_status OK
    FILES=`find $2 -type f | wc -l`
    [ $? -ne 0 ] && set_status CRIT && FILES="?"
    echo "$EXIT Files_in_$1_dir_$APPLICATION_ID files=$FILES $EXIT_TEXT - Found $FILES files"
}
EOT

my %var =  map { $_ => $config->get($_) } qw(APPLICATION_ID CATALYST_PORT BASE_PART_OF_EXTERNAL_URL LOCAL_URL
                                             UPLOAD_DIRECTORY UPLOAD_FTP_DIRECTORY OPENDAP_DIRECTORY);

my $envdefs = join '', map "$_=\"$var{$_}\"\n", keys %var;

my $mainbody = <<"EOT";
#!/bin/bash
#
# Check_MK plugin which monitors local services.
#
# This file is automatically generated by gen_checkmk_script.pl; your changes will perish!
#
# *** INSTALLATION ***
#
# Copy this file as root to /usr/lib/check_mk_agent/local/$var{APPLICATION_ID}-services
# (symlinks don't seem to be supported)

$envdefs
$funcdefs
#
# execute checks
#

check_catalyst_process
check_daemons
check_http_responses
count_files upload $var{UPLOAD_DIRECTORY}
count_files ftp $var{UPLOAD_FTP_DIRECTORY}
# OPENDAP disabled as contains too many files
#count_files opendap $var{OPENDAP_DIRECTORY}

exit \$FINAL
EOT

my $etc_dir    = $config->get('CONFIG_DIR') . "/etc";
my $conf_file  = "$etc_dir/checkmk-services";

if ($opt_p) {
    print $mainbody;
} else {
    mkdir $etc_dir unless -e $etc_dir;
    open FH, ">$conf_file" or die "Cannot open $conf_file for writing";
    print STDERR "Writing proxy config to $conf_file\n";
    print FH $mainbody;
    close FH;
    chmod 0700, $conf_file;
}

sub usage { # rewrite to use pod2usage - FIXME
    print STDERR "Usage: $0 [-p] [--config <config file or dir>]\n";
    exit (1);
}

=head1 NAME

B<gen_checkmk_script.pl> - CheckMK script generator for Metamod

=head1 DESCRIPTION

This utility generates a CheckMK script for monitoring production servers.
See L<http://mathias-kettner.com/checkmk_localchecks.html> for more info.

The generated file is written to $target/etc/checkmk, or stdout if using -p.
It must be copied to /usr/lib/check_mk_agent/local manually or by using install_jobs.sh.
If running on a multi-installation environment it must be renamed to something unique.

=head1 USAGE

=head2 Running script

 ./common/scripts/gen_checkmk_script.pl [-p] [--config <config file or dir>]

=head1 OPTIONS

=head2 Parameters

=over 4

=item -p

Prints output to stdout regardless of setting in master_config.

=item --config

Directory containing master_config.txt and where to write generated ./etc file.

=back

=head1 LICENSE

Copyright (C) 2015 The Norwegian Meteorological Institute.

METAMOD is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
