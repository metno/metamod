package Metamod::DBIxSchema::Metabase::Result::Dataset;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("dataset");
__PACKAGE__->add_columns(
  "ds_id",
  {
    data_type => "serial",
    #default_value => "nextval('dataset_ds_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable => 0,
    size => 4,
  },
  "ds_name",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
  "ds_parent",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "ds_status",
  { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
  "ds_datestamp",
  {
    data_type => "timestamp without time zone",
    default_value => undef,
    is_nullable => 0,
    size => 8,
  },
  "ds_ownertag",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
  "ds_creationdate",
  {
    data_type => "timestamp without time zone",
    default_value => undef,
    is_nullable => 0,
    size => 8,
  },
  "ds_metadataformat",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 128,
  },
  "ds_filepath",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 1024,
  },
);
__PACKAGE__->set_primary_key("ds_id");
__PACKAGE__->add_unique_constraint("dataset_ds_name_key", ["ds_name"]);
__PACKAGE__->add_unique_constraint("dataset_pkey", ["ds_id"]);
__PACKAGE__->has_many(
  "bk_describes_ds",
  "Metamod::DBIxSchema::Metabase::Result::BkDescribesDs",
  { "foreign.ds_id" => "self.ds_id" },
);
__PACKAGE__->has_many(
  "dataset_locations",
  "Metamod::DBIxSchema::Metabase::Result::DatasetLocation",
  { "foreign.ds_id" => "self.ds_id" },
);
__PACKAGE__->has_many(
  "ds_has_mds",
  "Metamod::DBIxSchema::Metabase::Result::DsHasMd",
  { "foreign.ds_id" => "self.ds_id" },
);
__PACKAGE__->has_many(
  "numberitems",
  "Metamod::DBIxSchema::Metabase::Result::Numberitem",
  { "foreign.ds_id" => "self.ds_id" },
);
__PACKAGE__->has_many(
  "parentprojectioninfos",
  "Metamod::DBIxSchema::Metabase::Result::Projectioninfo",
  { "foreign.ds_id" => "self.ds_parent" },
);
__PACKAGE__->has_many(
  "selfprojectioninfos",
  "Metamod::DBIxSchema::Metabase::Result::Projectioninfo",
  { "foreign.ds_id" => "self.ds_id" },
);
__PACKAGE__->has_many(
  "parentwmsinfos",
  "Metamod::DBIxSchema::Metabase::Result::Wmsinfo",
  { "foreign.ds_id" => "self.ds_parent" },
);
__PACKAGE__->has_many(
  "selfwmsinfos",
  "Metamod::DBIxSchema::Metabase::Result::Wmsinfo",
  { "foreign.ds_id" => "self.ds_id" },
);

__PACKAGE__->has_many(
  "child_datasets",
  "Metamod::DBIxSchema::Metabase::Result::Dataset",
  { "foreign.ds_parent" => "self.ds_id" },
);

__PACKAGE__->has_one(
  "parent_dataset",
  "Metamod::DBIxSchema::Metabase::Result::Dataset",
  { "foreign.ds_id" => "self.ds_parent" },
);

__PACKAGE__->has_many(
  "sibling_datasets",
  "Metamod::DBIxSchema::Metabase::Result::Dataset",
  { "foreign.ds_parent" => "self.ds_parent" },
);

__PACKAGE__->has_many(
  "oai_info",
  "Metamod::DBIxSchema::Metabase::Result::OaiInfo",
  { "foreign.ds_id" => "self.ds_id" },
);


# You can replace this text with custom content, and it will be preserved on regeneration

=begin LICENSE

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

=head1 NAME

Metamod::DBIxSchema::Metabase::Result::Dataset

=head1 DESCRIPTION

DBIx::Class Dataset class in the metadata database

=head1 METHODS

=cut

use Carp;
use Try::Tiny;
use XML::LibXML;
use Data::Dumper;
use Metamod::Config;
use Log::Log4perl qw();
use Metamod::FimexProjections;

my $logger = Log::Log4perl::get_logger(__PACKAGE__);
my $config = Metamod::Config->instance(); # problem - should be sent as parameter.
# current fix for shell scripts is to run Metamod::Config->new() in BEGIN block

=head2 $self->unqualified_ds_name()

=over

=item return

Returns the dataset name without any qualification like DAMOC or similar. If
the ds name is not qualified it just returns C<ds_name>.

=back

=cut

sub unqualified_ds_name {
    my $self = shift;

    my $unqualified_name;
    if ( $self->ds_name =~ /^.+\/(.+)$/ ) {
        $unqualified_name = $1;
    } else {
        $unqualified_name = $self->ds_name;
    }

    return $unqualified_name;

}

=head2 $self->metadata( [ $metadata_names ] )

Get metadata associated with the dataset.

=over

=item $metadata_names (optional)

An array reference with mt_names. If given only the metadata matching the
mt_names will be returned.

=item return

Returns a hash reference with one key per mt_name that the dataset has metadata
for. Each value is an array reference of metadata values. The value is an array
reference even if only one value is associated with the datasets for a
specific mt_name.

=back

=cut

sub metadata {
    my $self = shift;

    my ( $metadata_names ) = @_; # should maybe warn if name is not existing?

    $metadata_names = [] if !defined $metadata_names;

    # cache the metadata if not requesting specific metadata names
    if( exists $self->{ _metadata_cache } && 0 == @$metadata_names ){
        return $self->{ _metadata_cache };
    }

    my $search_conds = {};
    if( defined $metadata_names && 0 != @$metadata_names ){
        $search_conds->{ 'md_id.mt_name' } = { IN => $metadata_names };
    }

    my $metadata = $self->ds_has_mds()->search( $search_conds, { select => [ qw( md_id.md_content md_id.mt_name ) ],
                                                                 join => 'md_id',
                                                                 order_by => 'md_id.md_content'} );
    my %metadata = ();
    foreach my $md_name ( @$metadata_names ){
        $metadata{ $md_name } = [];
    }

    my $metadata_cursor = $metadata->cursor();
    while ( my ($md_content, $mt_name ) = $metadata_cursor->next() ) {

        push @{ $metadata{ $mt_name } }, $md_content;
    }

    if( 0 == @$metadata_names ){
        $self->{ _metadata_cache } = \%metadata;
    }
    return \%metadata;
}

=head2 $self->xmlfile()

Returns the path to the XML file if exists, otherwise undef

=cut

sub xmlfile {
    my ($self) = @_;
    my $path = $self->ds_filepath();
    if ($path =~ s/\.xm[dl]$//) {
        $logger->warn("Filepath for dataset " . $self->ds_id() . " contain extension: $path ...");
        # FIXME write correct path to metabase TODO
    }
    $path .= '.xml';
    #$logger->debug("Reading XML file for dataset " . $self->ds_id() . " in $path ...");
    return $path if -r $path;
}

=head2 $self->projectioninfo()

Returns projectioninfo object of either self or parent

=cut

sub projectioninfo {
    my ($self) = @_;
    my $rs = $self->selfprojectioninfos() || $self->parentprojectioninfos() || return;
    return unless $rs->count;
    my $prow = $rs->first() or die "Unknown error";
    my $dom = XML::LibXML->load_xml( string => $prow->pi_content );
    return $dom;
}

=head2 $self->projectioninfos() [DEPRECATED]

Returns projectioninfo resultset of either self or parent

=cut

sub projectioninfos {
    my ($self) = @_;
    return $self->selfprojectioninfos() || $self->parentprojectioninfos();
}

=head2 $self->fimex_projections()

Returns a Metamod::FimexProjections object (never null)

=cut

sub fimex_projections {
    my ($self) = @_;

    return new Metamod::FimexProjections() unless $config->get('FIMEX_PROGRAM');

    my $projinfo_row = $self->projectioninfos()->first();
    my $dsName = $self->ds_name;
    my $projinfo;
    if ( defined $projinfo_row ) {
        my $projinfo_str = $projinfo_row->pi_content() || "";
        eval { $projinfo = new Metamod::FimexProjections($projinfo_str, 1); };
        if ($@) {
            $logger->error("xml-error while reading projectionInfo for dataset $dsName: $@");
        }
    } else {
        $projinfo = new Metamod::FimexProjections();
    }
    return $projinfo;
}

=head2 $self->wmsinfo()

Returns the C<wi_content> XML DOM for the dataset if it has any Wmsinfo. Returns undef otherwise.

From 2.11 wmsinfo is delivered "as is" - variable substituion (%DATASET% etc) is
now done in $self->wmsurl which should be called insteadd of wmsinfo() where appropriate.

=cut

sub wmsinfo {
    my $self = shift;

    my $wmsinfo_row = $self->selfwmsinfos()->first() || $self->parentwmsinfos()->first()
        or return; # this dataset doesn't have any wmsinfo

    my $dom = XML::LibXML->load_xml( string => $wmsinfo_row->wi_content );
    my $root = $dom->documentElement;
    # check if correct wmsinfo format
    if ($root->namespaceURI ne 'http://www.met.no/schema/metamod/ncWmsSetup') {
        my $foo = $self->ds_id;
        my $bar = $self->ds_name;
        $logger->error("Wrong WMSinfo format for dataset $foo: $bar");
        return;
    }

    #printf STDERR " ******** RAW WMSINFO: %s\n", $dom->toString(1);

    #my $xpc = XML::LibXML::XPathContext->new($root);
    #$xpc->registerNs('setup', "http://www.met.no/schema/metamod/ncWmsSetup");
    #
    #foreach ( $xpc->findnodes('/*/setup:layer[@url]|/*/setup:baselayer[@url]') ) {
        #printf STDERR "--- Sanitize me! %s\n", sanitize_url( $_->getAttribute('name') ); # sanitize_url seems to be removed
    #}

    return $dom;

}

=head2 $self->wmsurl()

Returns the WMS URL for the dataset if it has any Wmsinfo, or undef otherwise.
The URL is given in either the B<aggregate_url> or B<url> attribute depending on level 1 or 2 dataset.

Use this method to check whether a dataset is "visualizable".

=head3 Substitutions

The following variables can be used in wmsinfo URLs:

=over

=item I<%DATASET%>

The ds_name of the current dataset. This is the only variable expanded
for level 1 datasets

=item I<%DATASET_PARENT%>

The ds_name of the parent dataset

=item I<%THREDDS_DATAREF%>

B<DEPRECATED - use I<%THREDDS_DATASET%> instead!> An attempt to construct a WMS URL from a THREDDS dataset URL
as per OSISAF file organization. Basically this consists of
"http://hostname.example.com/thredds/wms/" + the "dataset" query parameter.
Example:

    http://osisaf.met.no/thredds/catalog/osisaf/met.no/ice/drift_lr/single_sensor/amsr-aqua/2010/02/catalog.html?dataset=osisaf/met.no/ice/drift_lr/single_sensor/amsr-aqua/2010/02/ice_drift_nh_polstere-625_amsr-aqua_201002221200-201002241200.nc.gz

will be translated to

    http://osisaf.met.no/thredds/wms/osisaf/met.no/ice/drift_lr/single_sensor/amsr-aqua/2010/05/ice_drift_nh_polstere-625_amsr-aqua_201005291200-201005311200.nc.gz

=item I<%THREDDS_DATASET%>

The value of the "dataset" parameter in the query string of the THREDDS URL above

=back

=cut

sub wmsurl {
    my $self = shift;

    my $setup = $self->wmsinfo or return;
    my $url = $self->is_level1_dataset ?
        $setup->documentElement->getAttribute('aggregate_url') :
        $setup->documentElement->getAttribute('url');

    return unless $url; # both urls are optional

    #if (! $url) {
    #    my $foo = $self->ds_id;
    #    $logger->error("Missing WMS url in wmsinfo for dataset $foo"); # stupid bareword errors
    #    $logger->debug( $setup->toString(1) );
    #    carp "Missing WMS url in wmsinfo for dataset $foo";
    #}

    my ($tag, $parent, $dataset) = split '/', $self->ds_name;
    #printf STDERR " *** %s\n", join '|', ($tag, $parent, $dataset);

    if ($self->is_level1_dataset) {

        $url =~ s|%DATASET%|$parent|;

    } else {

        $url =~ s|%DATASET%|$dataset|;
        $url =~ s|%DATASET_PARENT%|$parent|;
        if ( $url =~ /%(THREDDS_|UGLY_HACK)/ ){
            #$logger->debug("*** WMS URL before substitution: $url");
            my $metadata = $self->metadata(['dataref']);
            if (exists $metadata->{dataref}) {

                my $dataref = $metadata->{dataref}[0];
                # %THREDDS_DATAREF% translates OSISAF-like THREDDS URLs into WMS URLs... DEPRECATED
                #$logger->debug("*** dataref: $dataref");
                unless ( $dataref =~ m|(.*/thredds)/catalog/.*\?dataset=(.*)| ) {
                    $logger->warn("Missing dataset ID in dataref $dataref");
                    return;
                }
                my $threddsDataref = "$1/wms/$2";
                my $dataset_id = $2;
                $url =~ s|%THREDDS_DATAREF%|$threddsDataref|;

                # %THREDDS_DATASET% only gives you the dataset parameter in the query string (thredds ID)
                my @datarefpath = split('/', $dataset_id);
                my $filename = $datarefpath[1] || $dataset_id;
                $url =~ s|%THREDDS_DATASET%|$dataset_id|;
                $url =~ s|%UGLY_HACK_FOR_MYOCEAN%|$filename|; #FIXME ASAP
            } else {
                $logger->warn("Missing dataref for dataset #" . $self->ds_id);
                return; # wmsinfo does not compute
            }
        }

    }

    #$logger->debug("*** WMS URL after substitution: $url");
    return $url if $url =~ /\?&$/; # ok if ends with ? or &
    return ($url =~ /\?/) ? "$url&" : "$url?"; # else add whatever is needed

}


=head2 $self->is_level1_dataset()

=over

=item return

Returns 1 if the dataset is a level 1 dataset. 0 otherwise.

=back

=cut

sub is_level1_dataset {
    my $self = shift;

    return $self->ds_parent() == 0 ? 1 : 0;

}

=head2 $self->is_level2_dataset()

=over

=item return

Returns 1 if the dataset is a level 2 dataset. 0 otherwise.

=back

=cut

sub is_level2_dataset {
    my $self = shift;

    return $self->ds_parent() != 0 ? 1 : 0;

}

=head2 $self->num_children()

=over

=item return

Get the number of children for a level 1 dataset. For a level 2 dataset it will always return 0.

=back

=cut

sub num_children {
    my $self = shift;

    return $self->child_datasets()->count();

}

=head2 $self->file_location()

Calculate the file location where the dataset is located if possible.

=over

=item return

Returns an URL where the file can be downloaded if possible. Returns C<undef>
if the file location cannot be calculated.

=back

=cut

sub file_location {
    my $self = shift;

    my $metadata = $self->metadata( ['dataref'] );

    my $opendap_basedir = $config->get('OPENDAP_BASEDIR') || '';
    my $thredds_dataset_prefix = $config->get('THREDDS_DATASET_PREFIX') || '';

    my $server_location = "http://thredds.met.no/thredds/fileServer/$opendap_basedir/"; # FIXME - remove hardcoded met.no hostname

    my $dataref = $metadata->{dataref}->[0];
    my $filename;
    if ( $dataref =~ /.*dataset=$thredds_dataset_prefix(.*)&?/ ) {
        $filename = $1
    } else {
        return
    }

    return "$server_location$filename";

}

=head2 $self->external_ts_url()

Calculate URL to external timeseries plot if available (must be set in TIMESERIES_URL in master_config)

=over

=item return

Returns an URL to the image file. Returns C<undef> if the URL cannot be calculated.

=back

=cut

sub external_ts_url {
    my $self = shift;

    my $tsurl = $config->get('TIMESERIES_URL') or return;

    my $metadata = $self->metadata( ['dataref_OPENDAP', 'timeseries'] );
    my $opendap = $metadata->{dataref_OPENDAP}->[0] or return;
    my $tsvars  = $metadata->{timeseries}->[0] || $self->parent_dataset->metadata->{timeseries}->[0];

    $tsurl =~ s/\[OPENDAP\]/$opendap/;
    $tsurl =~ s/\[TIMESERIES\]/$tsvars/ if $tsvars;

    $logger->debug('Timeseries URL = ' . $tsurl);

    return $tsurl;
}

## seems like this has been moved to MetamodWeb::Utils::UI::WMS
#
#=head2 sanitize_wmsurl($url)
#
#Make sure $url ends in either '?' or '&' as defined in spec
#
#=cut
#
#sub sanitize_wmsurl {
#    my $url = shift or die "Missing parameter";
#    return $url if $url =~ /\?&$/;              # ok if ends with ? or &
#    return ($url =~ /\?/) ? "$url&" : "$url?";  # else add whatever is needed
#}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
