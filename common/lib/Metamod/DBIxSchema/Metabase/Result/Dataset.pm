package Metamod::DBIxSchema::Metabase::Result::Dataset;

use strict;
use warnings;

use base 'DBIx::Class';
use XML::LibXML;
use Data::Dumper;
use Metamod::Config;
use Log::Log4perl qw();
use Metamod::FimexProjections;

my $logger = Log::Log4perl::get_logger(__PACKAGE__);

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
  "ga_describes_ds",
  "Metamod::DBIxSchema::Metabase::Result::GaDescribesDs",
  { "foreign.ds_id" => "self.ds_id" },
);
__PACKAGE__->has_many(
  "numberitems",
  "Metamod::DBIxSchema::Metabase::Result::Numberitem",
  { "foreign.ds_id" => "self.ds_id" },
);
__PACKAGE__->has_many(
  "projectioninfos",
  "Metamod::DBIxSchema::Metabase::Result::Projectioninfo",
  { "foreign.ds_id" => "self.ds_parent" },
);
__PACKAGE__->has_many(
  "wmsinfos",
  "Metamod::DBIxSchema::Metabase::Result::Wmsinfo",
  { "foreign.ds_id" => "self.ds_parent" },
);

__PACKAGE__->has_many(
  "child_datasets",
  "Metamod::DBIxSchema::Metabase::Result::Dataset",
  { "foreign.ds_parent" => "self.ds_id" },
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

use Carp;
use Try::Tiny;

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

=head2 $self->metadata([$metadata_names])

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

    my ( $metadata_names ) = @_;

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

=head2 $self->fimex_projections()

=over

=item return

Returns a Metamod::FimexProjections object (never null)

=back

=cut

sub fimex_projections {
    my ($self) = @_;
    my $config = Metamod::Config->new();
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

=over

=item return

Returns the C<wi_content> XML DOM for the dataset if it has any Wmsinfo. Returns undef otherwise.

=back

=cut

sub wmsinfo {
    my $self = shift;

    my $wmsinfo_row = $self->wmsinfos()->first();

    if( !defined $wmsinfo_row ){
        #printf STDERR "* No wms setup for dataset %s\n", $self->ds_name;
        return;
    }

    my $parser = new XML::LibXML;
    my $dom = $parser->parse_string( $wmsinfo_row->wi_content() );
    my $root = $dom->documentElement;
    # check if correct wmsinfo format
    if ($root->namespaceURI ne 'http://www.met.no/schema/metamod/ncWmsSetup') {
        carp "Wrong WMSinfo format!\n";
        return;
    }
    my $url = $root->getAttribute('url');
    if (!$url) {
        carp "Missing url in wmsinfo!";
        return;
    }

    my ($tag, $parent, $dataset) = split '/', $self->ds_name;
    #printf STDERR " *** %s\n", join '|', ($tag, $parent, $dataset);
    $url =~ s|%DATASET%|$dataset|;
    $url =~ s|%DATASET_PARENT%|$parent|;
    if ($url =~ m|%THREDDS_DATAREF%|) {
        my $metadata = $self->metadata(['dataref']);
        if (exists $metadata->{dataref}) {
            my $threddsDataref = $metadata->{dataref}[0];
            # translate url like
            # http://osisaf.met.no/thredds/catalog/osisaf/met.no/ice/drift_lr/single_sensor/amsr-aqua/2010/02/catalog.html?dataset=osisaf/met.no/ice/drift_lr/single_sensor/amsr-aqua/2010/02/ice_drift_nh_polstere-625_amsr-aqua_201002221200-201002241200.nc.gz
            # to
            # http://osisaf.met.no/thredds/wms/osisaf/met.no/ice/drift_lr/single_sensor/amsr-aqua/2010/05/ice_drift_nh_polstere-625_amsr-aqua_201005291200-201005311200.nc.gz
            #                          dataset=osisaf/met.no/ice/drift_lr/single_sensor/amsr-aqua/2010/02/ice_drift_nh_polstere-625_amsr-aqua_201002221200-201002241200.nc.gz
            $threddsDataref =~ s:(.*/thredds)/catalog/.*\?dataset=(.*):$1/wms/$2:;
            $url =~ s|%THREDDS_DATAREF%|$threddsDataref|;
        } else {
            # TODO: some logging
        }
    }

    $dom->documentElement->setAttribute('url', $url);
    #printf STDERR " ******** WMSINFO: %s\n", $wmsinfo_row->wi_content();

    return $dom;

}

=head2 $self->wmsthumb()

=over

=item return

Returns hash with URLs to WMS thumbnail based on wmsinfo setup.

Make sure to check if wmsinfo exist before calling this method.

=back

=cut

sub wmsthumb {
    my $self = shift;
    my ($size) = @_;

    try {
        my $config = Metamod::Config->new();

        my $setup = $self->wmsinfo or die "Error: Missing wmsSetup for dataset " . $self->ds_name;

        #printf STDERR "* Setup (%s) = %s\n", ref $setup, $setup->toString;
        my $sxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
        $sxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");

        # find base URL from wmsinfo
        my $wms_url = $sxc->findvalue('/*/@url') or die "Missing URL in wmsinfo";

        # find area info (dimensions, projection)
        my (%area, %layer);
        foreach ( $sxc->findnodes('/*/s:displayArea[1]/@*') ) {
            $area{$_->nodeName} = $_->getValue;
        }
        # find metadata of first layer (name, style)
        foreach ( $sxc->findnodes('/*/s:layer[1]/@*') ) {
            $layer{$_->nodeName} = $_->getValue;
        }

        # build WMS params for maps
        my $wmsparams = "SERVICE=WMS&REQUEST=GetMap&VERSION=1.1.1&FORMAT=image%2Fpng"
            . "&SRS=$area{crs}&BBOX=$area{left},$area{bottom},$area{right},$area{top}&WIDTH=$size&HEIGHT=$size"
            . "&EXCEPTIONS=application%2Fvnd.ogc.se_inimage";

        # get map url's according to projection
        my $mapserver = $config->get('WMS_BACKGROUND_MAPSERVER');
        my $map = $config->get('WMS_WORLD_MAP');
        if ($area{crs} eq "EPSG:32661") {
            $map = $config->get('WMS_NORTHPOLE_MAP');
        } elsif ($area{crs} eq "EPSG:32761") {
            $map = $config->get('WMS_SOUTHPOLE_MAP');
        }

        #print STDERR Dumper($wms_url, \%area, \%layer ); #$metadata

        my $out = {
            xysize  => $size,
            datamap => "$wms_url?$wmsparams&LAYERS=$layer{name}&STYLES=$layer{style}",
            outline => "$mapserver$map?$wmsparams&TRANSPARENT=true&LAYERS=borders&STYLES=",
        };

        #print STDERR Dumper($out);

        return $out;

    } catch {
        carp $_; # use logger - FIXME
        return;
    }
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

=head2 file_location()

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

    my $config = Metamod::Config->new();
    my $opendap_basedir = $config->get('OPENDAP_BASEDIR') || '';
    my $thredds_dataset_prefix = $config->get('THREDDS_DATASET_PREFIX') || '';

    my $server_location = "http://thredds.met.no/thredds/fileServer/$opendap_basedir/";

    my $dataref = $metadata->{dataref}->[0];
    my $filename;
    if ( $dataref =~ /.*dataset=$thredds_dataset_prefix(.*)&?/ ) {
        $filename = $1
    } else {
        return
    }

    return "$server_location$filename";

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;