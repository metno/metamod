package MetamodWeb::Schema::Userbase::Result::Usertable;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("usertable");
__PACKAGE__->add_columns(
  "u_id",
  {
    data_type => "integer",
    default_value => "nextval('usertable_u_id_seq'::regclass)",
    is_nullable => 0,
    size => 4,
  },
  "a_id",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
  "u_name",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_email",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 0,
    size => 9999,
  },
  "u_password",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_institution",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_telephone",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_session",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
  "u_loginname",
  {
    data_type => "character varying",
    default_value => undef,
    is_nullable => 1,
    size => 9999,
  },
);
__PACKAGE__->set_primary_key("u_id");
__PACKAGE__->add_unique_constraint("usertable_pkey", ["u_id"]);
__PACKAGE__->has_many(
  "datasets",
  "MetamodWeb::Schema::Userbase::Result::Dataset",
  { "foreign.u_id" => "self.u_id" },
);
__PACKAGE__->has_many(
  "infouds",
  "MetamodWeb::Schema::Userbase::Result::Infouds",
  { "foreign.u_id" => "self.u_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-09-15 14:15:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ol3eBbTy1PkS1D/vtd0DCg

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

__PACKAGE__->has_many(
  "infou",
  "MetamodWeb::Schema::Userbase::Result::Infou",
  { "foreign.u_id" => "self.u_id" },
);

__PACKAGE__->has_many(
  "roles",
  "MetamodWeb::Schema::Userbase::Result::Userrole",
  { "foreign.u_id" => "self.u_id" },
);

use Data::Dumper;
use Digest;
use Carp;
use Metamod::Utils qw(random_string);

use constant ROLETYPES => qw(admin upload subscription);

=head2 $self->merge_roles

Set roles in list to 0 unless already set to 1

=cut

sub merge_roles {
    my ($self, $list) = @_;
    $$list{$_} ||= 0 foreach ROLETYPES;
    #print STDERR "Merge " . Dumper $list;
    return $list;
}

=head2 $self->get_roles

Return a hash over all possible roles, set to 0 or 1 as for current user

=cut

sub get_roles {
    my $self = shift;
    my %roles = ();
    %roles = map { $_->get_column('role') => 1 } $self->roles;
    $self->merge_roles(\%roles);
    #print STDERR Dumper \%roles;
    return \%roles;
}

=head2 $self->set_roles

Takes a ref to a hash with roles, setting those who are true and deletes all others

=cut

sub set_roles {
    my ($self, $roles) = @_;
    print STDERR "Setting " . Dumper $roles;
    foreach ( $self->roles ) {
        $_->delete; # first delete all roles
    }
    foreach my $role (keys %$roles) {
        croak "Unknown role '$role'" unless grep /^$role$/, ROLETYPES;
        next unless $$roles{$role}; # skip 0's
        #print STDERR "/////// $role //////\n";
        $self->roles->create(
            {
                u_id => $self->get_column('u_id'),
                role => $role
            }
        );
    }
}

=head2 $self->update_password($password)

Hash the supplied password and update the password.

=over

=item $password

The password in clear text that should be hashed and stored in the database.

=item return

Returns the row object.

=back

=cut

sub update_password {
    my $self = shift;

    my ($password) = @_;

    my $pass_digest = Digest->new('SHA-1')->add($password)->hexdigest();

    return $self->update( { u_password => $pass_digest } );

}

=head2 $self->reset_password()

Reset the users password with a new random password. This function will
generate the new random password, hash it and store it in the database.

=over

=item return

Returns the new random password in clear text.

=back

=cut

sub reset_password {
    my $self = shift;

    my $random_pass = random_string();

    $self->update_password($random_pass);

    return $random_pass;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

# You can replace this text with custom content, and it will be preserved on regeneration
1;
