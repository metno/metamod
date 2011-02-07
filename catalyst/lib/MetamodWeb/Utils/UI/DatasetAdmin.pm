package MetamodWeb::Utils::UI::DatasetAdmin;

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

use JSON;
use Moose;
use namespace::autoclean;

use warnings;

extends 'MetamodWeb::Utils::UI::Base';

=head1 NAME

MetamodWeb::Utils::UI::DatasetAdmin - Utility functions for building the dataset admin UI.

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->user_datasets()

Get the list of datasets owned by the currently logged in user.

=over

=item return

A reference to a list of DBIx::Class rows objects for the datasets that the user owns.

=back

=cut

sub user_datasets {
    my $self = shift;

    my $user_id = $self->c->user()->u_id();
    my @datasets = $self->user_db->resultset('Dataset')->search( { u_id => $user_id } )->all();

    return \@datasets;

}

=head2 $self->user_files()

Get the list of files uploaded by the currently logged in user.

=over

=item return

A reference to a list of DBIx::Class rows objects for the files that the user has uploaded.

=back

=cut

sub user_files {
    my $self = shift;

    my $user_id = $self->c->user()->u_id();
    my @files = $self->user_db->resultset('File')->search( { u_id => $user_id } )->all();

    return \@files;

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

    my ( $config_file ) = @_;

    if( !( -r $config_file ) ){
        die "Could not read configuration file '$config_file'";
    }

    open my $CONFIG_FILE, '<', $config_file;
    my $config_content = do { local $/, <$CONFIG_FILE> };

    my $config = from_json( $config_content );

    return $config;

}

=head2 $self->gcmdlist($quest_element)

Get the gcmd option list for a questionnaire element of type gcmdlist.

=over

=item $quest_element

The questionnaire element to get the list for. The element is expected to be a
hash reference with the required key 'value' which hold the relative filename
of the file with all the list elements. The filename should be relative to the
base target directory. In addition the keys 'exclude' and 'include' are
supported which will remove or add elements respectively.

=item return

A reference to a list with all the keywords.

=back

=cut
sub gcmdlist {
    my $self = shift;

    my ( $quest_element ) = @_;

    my $file = $quest_element->{ value };
    my $base_dir = $self->config->get('QUEST_CONFIG_DIRECTORY');
    my $full_path = "$base_dir/$file";
    if( !(-r $full_path ) ){
        die "Cannot find file '$full_path'";
    }

    open my $LIST_FILE, '<', $full_path;
    my @gcmdlist = <$LIST_FILE>;
    chomp(@gcmdlist);

    # remove comments
    @gcmdlist = grep { !( /^\s*#/ ) } @gcmdlist;

    if( exists $quest_element->{exclude}){
        foreach my $name (@{ $quest_element->{ exclude } } ){
            @gcmdlist = grep { !( /^$name/ ) } @gcmdlist;
        }
    }

    if( exists $quest_element->{include} ){
        push @gcmdlist, @{ $quest_element->{include} };
    }

    return \@gcmdlist;

}

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
    my %labels = ();
    foreach my $element (@$quest_config){

        my $name = $element->{ name };

        # elements without names are not form input and can be ignored
        next if !$name;

        # existance is enough for marking required fields
        if( exists $element->{ mandatory } ){
            push @required, $name;
        } else {
            push @optional, $name;
        }

        $labels{ $name } = $element->{label};
    }

    my %form_profile = (
        required => \@required,
        optional => \@optional,
        labels => \%labels,
    );

    return \%form_profile;

}

__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
