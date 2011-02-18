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

use JSON;
use File::Spec;
use Log::Log4perl qw(get_logger);

use Metamod::Config;
use Metamod::Dataset;

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

    my @required = ();
    my @optional = ();
    my %labels   = ();
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

        $labels{$name} = $element->{label};
    }

    my %form_profile = (
        required => \@required,
        optional => \@optional,
        labels   => \%labels,
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

    my %quest_configurations = (
        'metadata' => {
        config_file => $self->c->path_to('quest_config.json'),
        title       => 'Metadata editor',
        tag         => $self->config->get('QUEST_OWNERTAG'),
        }
    );

    my @configurations = split("\n", $quest_config);
    foreach my $line (@configurations){

        chomp($line);
        next if !$line;

        my ($config_id, $config_file, $tag, @title) = split " ", $line;
        my $title = join " ", @title;

        $quest_configurations{$config_id} = { config_file => $config_file, tag => $tag, title => $title };

    }

    return \%quest_configurations;
}

sub load_anon_metadata {
    my $self = shift;

    my ( $config_id, $response_key ) = @_;

    my $quest_output_dir = $self->config->get('QUEST_OUTPUT_DIRECTORY');

    if ( !( -r $quest_output_dir ) ) {
        $self->logger->error("Cannot read quest response from '$quest_output_dir'");
        return;
    }

    my $input_basename = File::Spec->catfile( $quest_output_dir, "${config_id}_${response_key}" );
    if ( !( -e "${input_basename}.xmd" ) ) {
        return {};
    }

    my $dataset = Metamod::Dataset->newFromFile($input_basename);

    my %metadata = $dataset->getMetadata();
    return \%metadata;

}

sub save_anon_metadata {
    my $self = shift;

    my ( $config_id, $response_key, $metadata ) = @_;

    my $quest_output_dir = $self->config->get('QUEST_OUTPUT_DIRECTORY');

    if ( !( -w $quest_output_dir ) ) {
        $self->logger->error("Cannot write quest response to '$quest_output_dir'");
        return;
    }

    my $output_basename = File::Spec->catfile( $quest_output_dir, "${config_id}_${response_key}" );
    my $dataset;
    if ( !( -e "${output_basename}.xmd" ) ) {
        $dataset = Metamod::Dataset->new();
    } else {
        $dataset = Metamod::Dataset->newFromFile($output_basename);
    }

    $dataset->removeMetadata();
    $dataset->addMetadata($metadata);
    $dataset->writeToFile($output_basename);

}

sub load_dataset_metadata {
    my $self = shift;

    my ($userbase_ds_id) = @_;

    my $dataset_path = $self->dataset_path($userbase_ds_id);

    if ( !$dataset_path ) {
        return;
    }

    my $dataset = $self->load_dataset($dataset_path);

    return if !defined $dataset;

    my %metadata = $dataset->getMetadata();
    return \%metadata;

}

sub save_dataset_metadata {
    my $self = shift;

    my ( $userbase_ds_id, $metadata ) = @_;

    my $dataset_path = $self->dataset_path($userbase_ds_id);

    if ( !$dataset_path ) {
        return;
    }

    my $dataset = $self->load_dataset($dataset_path);

    $dataset->removeMetadata();
    $dataset->addMetadata($metadata);

    $dataset->writeToFile($dataset_path);

    return 1;

}

sub load_dataset {
    my $self = shift;

    my ($dataset_path) = @_;

    my $dataset;
    if ( -r $dataset_path ) {
        $dataset = Metamod::Dataset->newFromFile($dataset_path);
    } else {
        $self->logger->info("Could not find read the file $dataset_path");
        return;
    }

    return $dataset;

}

sub dataset_path {
    my $self = shift;

    my ($userbase_ds_id) = @_;

    my $userbase_ds = $self->user_db->resultset('Dataset')->find($userbase_ds_id);
    if ( !defined $userbase_ds ) {
        $self->logger->error("Could not find dataset with id '$userbase_ds_id' in the userbase");
        return;
    }

    my $metabase_ds_name = $userbase_ds->a_id() . "/" . $userbase_ds->ds_name();
    my $metabase_ds = $self->meta_db->resultset('Dataset')->find( $metabase_ds_name, { key => 'dataset_ds_name_key' } );
    if ( !defined $metabase_ds ) {
        $self->logger->error("Could not find dataset with ds_name '$metabase_ds_name' in the metabase");
        return;
    }

    return $metabase_ds->ds_filepath();

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
