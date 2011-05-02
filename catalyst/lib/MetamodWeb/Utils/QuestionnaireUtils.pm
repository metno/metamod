package MetamodWeb::Utils::QuestionnaireUtils;

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

use Moose;
use namespace::autoclean;

use warnings;

use Data::FormValidator::Constraints qw( FV_max_length );
use DateTime;
use File::Spec;
use JSON;
use Log::Log4perl qw(get_logger);
use POSIX qw(strftime);

use Metamod::Config;
use Metamod::Dataset;
use MetamodWeb::Utils::FormValidator::Constraints;

#
# A Metamod::Config object containing the configuration for the application
#
has 'config' => ( is => 'ro', isa => 'Metamod::Config', default => sub { Metamod::Config->new() } );

#
# A Catalyst context object.
#
has 'c' => (
    is       => 'ro',
    required => 1,
    handles  => {
        meta_db => [ model => 'Metabase' ],
        user_db => [ model => 'Userbase' ],
    }
);

#
# The Log::Log4perl log object for this class
#
has 'logger' => ( is => 'ro', default => sub { get_logger('metamodweb') } );

=head1 NAME

MetamodWeb::Utils::Questionnaire - Utility functions for the questionnaire.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->quest_validator($config_file)

Generate a C<MetamodWeb::Utils::FormValidator> form profile from the
questionnaire configuration file.

=over

=item $config_file

The full path the to questionnaire configuration file in JSON format.

=item return

Returns a hash reference with the form profile that can be used for validation.

=back

=cut

sub quest_validator {
    my $self = shift;

    my ($config_file) = @_;

    my $quest_config = $self->quest_config($config_file);

    my %known_constraints = (
        wms_info => \&MetamodWeb::Utils::FormValidator::Constraints::wms_info,
    );

    my @required = ();
    my @optional = ();
    my %labels   = ();
    my %constraints = ();
    foreach my $element (@$quest_config) {

        my $name = $element->{name};

        # elements without names are not form input and can be ignored
        next if !$name;

        # existance is enough for marking required fields
        if ( exists $element->{mandatory} ) {
            push @required, $name;
        } else {
            push @optional, $name;
        }

        if( exists $element->{constraint} ){
            my $constraint = $element->{constraint};

            my $constraint_func;
            if( $constraint eq 'wms_info' ){
                my $wms_schema = $self->config->get("TARGET_DIRECTORY") . '/schema/ncWmsSetup.xsd';
                $constraint_func = MetamodWeb::Utils::FormValidator::Constraints::xml( $wms_schema )
            } elsif( $constraint eq 'projection_info') {
                my $projection_schema = $self->config->get("TARGET_DIRECTORY") . '/schema/fimexProjections.xsd';
                $constraint_func = MetamodWeb::Utils::FormValidator::Constraints::xml( $projection_schema )
            } else {
                die "Unknown constraint '$constraint'";
            }

            $constraints{$name} = $constraint_func;
        }

        if( exists $element->{size} ){

            if( !($element->{size} =~ /^\d+$/ ) ){
                die "'size' is not a number for '$name'";
            }

            $constraints{$name} = FV_max_length($element->{size});
        }

        $labels{$name} = $element->{label};
    }

    my %form_profile = (
        required           => \@required,
        optional           => \@optional,
        labels             => \%labels,
        constraint_methods => \%constraints,
        missing_optional_valid => 1,
    );

    return \%form_profile;

}

sub quest_data {
    my $self = shift;

    # fetch only the relevant metadata to be stored.
    my %quest_data = ();
    while ( my ( $name, $value ) = each %{ $self->c->req->params } ) {
        if ( $name =~ /^quest_(.*)$/ ) {

            # Metamod::Dataset expect that the values are array references
            # so for easier consistency we make single values to array
            # references as well
            if ( !( ref $value eq 'ARRAY' ) ) {
                $value = [$value];
            }

            $quest_data{$1} = $value;
        }
    }

    return \%quest_data;
}

=head2 $self->quest_config($config_file)

Get the configuration of a questionnaire from a config file.

=over

=item $config_file

The full path to the configuration file. The configuration file is exected to
be a JSON file where consisting of an array of hashes. Each element in the
array describes one UI element in the questionnaire.

=item return

Returns the configuration as reference to list of hash references.

=back

=cut

sub quest_config {
    my $self = shift;

    my ($config_file) = @_;

    if ( !( -r $config_file ) ) {
        die "Could not read configuration file '$config_file'";
    }

    open my $CONFIG_FILE, '<', $config_file;
    my $config_content = do { local $/, <$CONFIG_FILE> };

    my $config = from_json($config_content);
    return $config;

}

sub config_for_id {
    my $self = shift;

    my ($config_id) = @_;

    my $quest_configs = $self->quest_configuration();

    return if !exists $quest_configs->{$config_id};

    return $quest_configs->{$config_id};

}

sub quest_configuration {
    my $self = shift;

    my $quest_config = $self->config()->get('QUEST_CONFIGURATIONS');

    my $root = MetamodWeb::path_to_metamod_root(); #$self->config->get('TARGET_DIRECTORY');
    $root .= "/quest" unless $root eq $self->config->get('TARGET_DIRECTORY');
    #printf STDERR "** root = %s | target = %s\n", $root, $self->config->get('TARGET_DIRECTORY');

    my %quest_configurations = (
        'metadata' => {
        config_file => File::Spec->catfile($root, 'etc', 'qst', 'metadata_quest.json' ),
        tag         => $self->config->get('QUEST_OWNERTAG'),
        },
        'wms_and_projection' => {
        config_file => File::Spec->catfile($root, 'etc', 'qst', 'wms_and_projection.json' ),
        tag         => $self->config->get('QUEST_OWNERTAG'),
        }
    );

    my @configurations = split("\n", $quest_config);
    foreach my $line (@configurations){

        chomp($line);
        next if !$line;

        my ($config_id, $config_file, $tag) = split " ", $line;

        $quest_configurations{$config_id} = { config_file => $config_file, tag => $tag };

    }

    return \%quest_configurations;
}

=head2 $self->load_anon_metadata($config_id, $response_key)

Load metadata (and info) from a 'anonmous' dataset. That is a dataset that is
not stored in the userbase.

=over

=item $config_id

The id of the questionnaire that the metadata is related to.

=item $response_key

The key that the user will use to identify the response.

=item return

Returns the metadata for the dataset as a hash reference.

=back

=cut

sub load_anon_metadata {
    my $self = shift;

    my ( $config_id, $response_key ) = @_;

    my $quest_output_dir = $self->config->get('QUEST_OUTPUT_DIRECTORY');

    if ( !( -r $quest_output_dir ) ) {
        $self->logger->error("Cannot read quest response from '$quest_output_dir'");
        return;
    }

    my $input_basename = File::Spec->catfile( $quest_output_dir, "${config_id}_${response_key}" );

    return $self->_load_metadata($input_basename);

}

=head2 $self->save_anon_metadata($config_id, $response_key, $metadata)

Save metadata to an anonomous dataset. That is a dataset that is not stored in
the userbase.

=over

=item $config_id

The id of the questionnaire that the metadata is related to.

=item $response_key

The key that the user will use to identify the response.

=item $metadata

A hash reference of the metadata to store. The values in that has should be
array references, even for single values.

=item return

Returns true if the metadata was save successfully. Dies on error.

=back

=cut

sub save_anon_metadata {
    my $self = shift;

    my ( $config_id, $response_key, $metadata ) = @_;

    my $quest_output_dir = $self->config->get('QUEST_OUTPUT_DIRECTORY');

    if ( !( -w $quest_output_dir ) ) {
        $self->logger->error("Cannot write quest response to '$quest_output_dir'");
        return;
    }

    my $output_basename = File::Spec->catfile( $quest_output_dir, "${config_id}_${response_key}" );
    my $config = $self->config_for_id($config_id);
    my $ownertag = $config->{tag};

    return $self->_save_metadata($metadata, $output_basename, $ownertag);

}

=head2 $self->load_dataset_metadata($userbase_ds_id)

Load the metadata for a dataset that is stored in the userbase.

=over

=item $userbase_ds_id

The C<ds_id> from the userbase.

=item return

Returns the metadata as a hash reference.

=back

=cut

sub load_dataset_metadata {
    my $self = shift;

    my ($userbase_ds_id) = @_;

    my ($dataset_path, $dataset_name) = $self->dataset_path($userbase_ds_id);

    if ( !$dataset_path ) {
        return;
    }

    return $self->_load_metadata($dataset_path);

}

=head2 $self->save_dataset_metadata($config_id, $userbase_ds_id, $metadata)

Save metadata to a dataset that is stored in the userbase.

=over

=item $config_id

The id of the questionnaire that the metadata is related to.

=item $userbase_ds_id

The C<ds_id> from the userbase for the dataset.

=item $metadata

The metadata as a hash reference. The values should be array references even for single values.

=item return

=back

=cut

sub save_dataset_metadata {
    my $self = shift;

    my ( $config_id, $userbase_ds_id, $metadata ) = @_;

    my ($dataset_path, $metabase_ds_name) = $self->dataset_path($userbase_ds_id);

    if ( !$dataset_path ) {
        return;
    }

    my $config = $self->config_for_id($config_id);
    my $ownertag = $config->{tag};
    return $self->_save_metadata($metadata, $dataset_path, $ownertag, $metabase_ds_name );

}

=head2 $self->_save_metadata($metadata, $dataset_path, $ownertag )

Helper method for storing metadata and info for a dataset.

=over

=item $metadata

The metadata to store as a hash reference.

=item $dataset_path

The path on disk where the metadata should be stored.

=item $ownertag

The ownertag that should be used for metadata.

=item $metabase_ds_name (optional)

The ds name as found in the metabase. This is only relevant for datasets and
not anonymous metadata not tied to a specific dataset.

=item return

=back

=cut

sub _save_metadata {
    my $self = shift;

    my ($metadata, $dataset_path, $ownertag, $metabase_ds_name) = @_;

    my (undef, $containing_dir, undef) = File::Spec->splitpath($dataset_path);
    if( !(-w $containing_dir)){
        die "Cannot write to '$containing_dir'";
    }

    my $dataset = $self->load_dataset($dataset_path);

    # As the metadata form may not necessarily contain all metadata we need to add
    # all the current metadata to the metadata to save.
    my %current_metadata = $dataset->getMetadata();
    my %merged_metadata = ( %current_metadata, %$metadata );
    $metadata = \%merged_metadata;

    # use a DateTime object to get the timezone correct
    my $datestamp = DateTime->from_epoch( epoch => time(), time_zone => 'local' );

    my %info = $dataset->getInfo();
    $info{datestamp} = $datestamp->strftime('%Y-%m-%dT%H:%M:%SZ');
    $info{metadataFormat} = 'MM2';
    $info{ownertag} = $ownertag;

    # Changing the name of a dataset is potentially a very bad idea. Since the dataset name
    # is also used to locate the metadata XML files on disk. Allowing changing
    # the dataset name works under the following two assumptions:
    # 1. The dataset name cannot be changed for datasets that are edited through the
    #    dataset administration interface. This is only enforced by not having the
    #    dataset name as part of the form.
    # 2. The file location and dataset name is not related for dataset that are edited
    #    outside of the dataset administration interface.
    #
    if( exists $metadata->{name} ){
        my $new_dataset_name = delete $metadata->{name};
        my $applic_id = $self->config->get('APPLICATION_ID');
        if( defined $new_dataset_name ){

            # remove potential applic_id
            if( $new_dataset_name =~ /$applic_id\/(.*)$/ ){
                $new_dataset_name = $1;
            }

        } else {
            # make a crappy random dataset name.
            $new_dataset_name = int(rand(1_000_000))
        }
        $new_dataset_name = $applic_id . '/' . $new_dataset_name;
        $info{name} = $new_dataset_name;
    }

    # we don't have dataset name so we use the one provided
    if( (!exists $info{name} || $info{name} eq '/') && defined $metabase_ds_name ){
        $info{name} = $metabase_ds_name;
    }

    # the creation data can only be set the first time and cannot be updated later
    $info{creationDate} = $info{datestamp} = $datestamp->strftime('%Y-%m-%dT%H:%M:%SZ') if !exists $info{creationDate};

    if( exists $metadata->{wms_info}){
        my $wms_info = delete $metadata->{wms_info};
        $wms_info = '' if !defined $wms_info;
        $dataset->setWMSInfo($wms_info);
    }

    if( exists $metadata->{projection_info} ){
        my $projection_info = delete $metadata->{projection_info};
        $projection_info = '' if !defined $projection_info;
        $dataset->setProjectionInfo($projection_info);
    }

    # we must convert the meta data to a format that Metamod::Dataset understands
    while( my ($key, $value) = each %$metadata ){

        # empty fields are set to undef by Data::FormValidator
        $value = '' if !defined $value;

        if( ref $value ne 'ARRAY' ){
            $metadata->{$key} = [ $value ];
        }
    }

    $dataset->removeMetadata();
    $dataset->addMetadata($metadata);
    $dataset->setInfo(\%info);
    $dataset->writeToFile($dataset_path);

    return 1;

}

=head2 $self->_load_metadata($dataset_path)

Helper method for loading the metadata for a dataset.

=over

=item $dataset_path

The location on disk where the dataset is stored. This can refere to a location
that does not yet exist in the case of a new dataset.

=item return

The metadata as a hash reference.

=back

=cut

sub _load_metadata {
    my $self = shift;

    my ($dataset_path) = @_;

    my $dataset = $self->load_dataset($dataset_path);

    my %metadata = $dataset->getMetadata();
    while( my( $key, $value) = each %metadata ){
        if( 1 == @$value){
            $metadata{$key} = $value->[0];
        }
    }

    my %info = $dataset->getInfo();
    %metadata = (%metadata, %info);

    my $wms_info = $dataset->getWMSInfo();
    $metadata{wms_info} = $wms_info if $wms_info;

    my $projection_info = $dataset->getProjectionInfo();
    $metadata{projection_info} = $projection_info if $projection_info;

    return \%metadata;

}

=head2 $self->load_dataset($dataset_path)

Load the dataset as a C<Metamod::Dataset> object. In the case of the dataset
not yet existing a new empty dataset will be created.

=over

=item $dataset_path

The path on disk where the XML metadata files are stored.

=item return

Returns a C<Metamod::Dataset> object.

=back

=cut

sub load_dataset {
    my $self = shift;

    my ($dataset_path) = @_;

    my $dataset;
    if ( -r "${dataset_path}.xmd" ) {
        $dataset = Metamod::Dataset->newFromFile($dataset_path);
    } else {
        $self->logger->debug("Could not find read the file from '$dataset_path'. Creating new dataset");
        $dataset = Metamod::Dataset->new();
    }

    return $dataset;

}

=head2 $self->dataset_path($userbase_ds_id)

=over

=item $userbase_ds_id

The C<ds_id> of the dataset from the userbase.

=item return

Returns the path to where the XML metadata files are stored on disk.

=back

=cut

sub dataset_path {
    my $self = shift;

    my ($userbase_ds_id) = @_;

    my $userbase_ds = $self->user_db->resultset('Dataset')->find($userbase_ds_id);
    if ( !defined $userbase_ds ) {
        $self->logger->error("Could not find dataset with id '$userbase_ds_id' in the userbase");
        return;
    }

    my $metabase_ds_name = $userbase_ds->a_id() . "/" . $userbase_ds->ds_name();
    my $filepath = $self->config->getDSFilePath($metabase_ds_name);

    return ($filepath, $metabase_ds_name);
}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
