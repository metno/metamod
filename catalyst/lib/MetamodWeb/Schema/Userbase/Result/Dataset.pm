package MetamodWeb::Schema::Userbase::Result::Dataset;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( "InflateColumn::DateTime", "Core" );
__PACKAGE__->table("dataset");
__PACKAGE__->add_columns(
    "ds_id",
    {
        data_type     => "integer",
        default_value => "nextval('dataset_ds_id_seq'::regclass)",
        is_nullable   => 0,
        size          => 4,
    },
    "u_id",
    { data_type => "integer", default_value => undef, is_nullable => 0, size => 4 },
    "a_id",
    {
        data_type     => "character varying",
        default_value => undef,
        is_nullable   => 0,
        size          => 9999,
    },
    "ds_name",
    {
        data_type     => "character varying",
        default_value => undef,
        is_nullable   => 0,
        size          => 9999,
    },
);
__PACKAGE__->set_primary_key("ds_id");
__PACKAGE__->add_unique_constraint( "dataset_a_id_key", [ "a_id", "ds_name" ] );
__PACKAGE__->add_unique_constraint( "dataset_pkey", ["ds_id"] );
__PACKAGE__->belongs_to( "u_id", "MetamodWeb::Schema::Userbase::Result::Usertable", { u_id => "u_id" }, );
__PACKAGE__->has_many( "files",  "MetamodWeb::Schema::Userbase::Result::File",   { "foreign.ds_id" => "self.ds_id" }, );
__PACKAGE__->has_many( "infods", "MetamodWeb::Schema::Userbase::Result::Infods", { "foreign.ds_id" => "self.ds_id" }, );
__PACKAGE__->has_many(
    "infouds",
    "MetamodWeb::Schema::Userbase::Result::Infouds",
    { "foreign.ds_id" => "self.ds_id" },
);

# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-09-15 14:15:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MPgVgO1BnAdnjhhK2y4YLg

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

=head2 $self->get_info_ds

Get info rows for dataset (only those relevant for editing - e.g. not wmsinfo)

=cut

sub get_info_ds {
    my $self = shift;
    my $dataset = {};

    my $ds_id = $self->get_column('ds_id');
    $$dataset{'ds_name'} = $self->get_column('ds_name');

    foreach my $type ( qw(DSKEY CATALOG LOCATION) ) {
        if ( my $info = $self->infods()->find({ ds_id => $ds_id, i_type => $type }) ) {
            $$dataset{lc $type} = $info->get_column('i_content');
        }
    }

    return $dataset;
}

=head2 $self->set_info_ds($params)

Set info rows for dataset

=over

=item $para

Ref to hash with info to set, e.g. from CGI params (keys in lower case)

=item return

The dataset id

=back

=cut

sub set_info_ds {
    my $self = shift;
    my $para = shift or croak "Missing params";

    my $ds_id = $self->get_column('ds_id');
    my $rs = $self->infods;

    #die "Bad key" if length($$para{dskey}) > 10;

    foreach ( qw(DSKEY CATALOG LOCATION) ) {
        #printf STDERR "** %s = \"%s\"\n", $_, $val;
        my $val = $$para{lc $_};
        my $infods = $rs->search( { ds_id => $ds_id, i_type => $_ } )->first();
        if ( !defined $infods ) {
            $rs->create( { ds_id => $ds_id, i_type => $_, i_content => $val } );
        } else {
            $infods->update( { i_content => $val } );
        }
    }

    return $ds_id;
}

=head2 $self->dataset_key($new_key?) B<[DEPRECATED]>

Get or set the dataset key for dataset. If a $new_key is not provided it will
just get the current key.

=over

=item $new_key (optional)

A new dataset key.

=item return

The dataset key for the dataset.

=back

=cut

sub dataset_key {
    my $self = shift;

    my ($new_key) = @_;

    # test of argument length instead of checking for undef so that the value
    # can be reset
    if ( @_ == 0 ) {

        my $info_ds = $self->infods()->search( { i_type => 'DSKEY' } )->first();

        return if !defined $info_ds;

        return $info_ds->i_content();
    } else {

        # i_content is not allowed to be null so just return
        return if !defined $new_key;

        my $info_ds = $self->infods()->search( { i_type => 'DSKEY' } )->first();
        if ( defined $info_ds ) {
            $info_ds->update( { i_content => $new_key } );
        } else {
            $self->infods()->create( { i_type => 'DSKEY', i_content => $new_key } );
        }

        return $new_key;
    }
}

=head2 $self->validate_dskey($key) B<[DEPRECATED]>

Check if dataset key is valid (always true if no key set).

=cut

sub validate_dskey {
    my $self = shift;
    my $key = shift;

    my $dskey = $self->dataset_key();
    printf STDERR " '%s' = '%s'? %d\n", $key, $dskey, ($key eq $dskey);
    return 1 unless $dskey; # blank key = access all areas
    return !$dskey || ($key eq $dskey);
}

=head2 $self->projection_xml($new_projection?)

Get or set the projection XML for the dataset. If $new_projection is not
provided it will just return the current value.

=over

=item $new_projection (optional)

The new projection XML.

=item return

The projection XML for the dataset.

=back

=cut

sub projection_xml {
    my $self = shift;

    my ($new_projection) = @_;

    # test of argument length instead of checking for undef so that the value
    # can be reset
    if ( @_ == 0 ) {

        my $info_ds = $self->infods()->search( { i_type => 'PROJECTION_XML' } )->first();

        return if !defined $info_ds;

        return $info_ds->i_content();
    } else {

        # i_content is not allowed to be null so just return
        return if !defined $new_projection;

        my $infods_rs = $self->_infods_resultset();
        $infods_rs->create_or_update_projection_xml( $self->ds_id(), $new_projection );

        return $new_projection;
    }
}

=head2 $self->wms_xml($new_wms_setup?)

Get or set the WMS setup XML for the dataset. If $new_wms_setup is not
provided it will just return the current value.

=over

=item $new_wms_seyup (optional)

The new WMS setup XML.

=item return

The WMS setup XML for the dataset.

=back

=cut

sub wms_xml {
    my $self = shift;

    my ($new_wms_setup) = @_;

    # test of argument length instead of checking for undef so that the value
    # can be reset
    if ( @_ == 0 ) {

        my $info_ds = $self->infods()->search( { i_type => 'WMS_XML' } )->first();

        return if !defined $info_ds;

        return $info_ds->i_content();
    } else {

        # i_content is not allowed to be null so just return
        return if !defined $new_wms_setup;

        my $infods_rs = $self->_infods_resultset();
        $infods_rs->create_or_update_wms_xml( $self->ds_id(), $new_wms_setup );

        return $new_wms_setup;
    }

}

sub _infods_resultset {
    my $self = shift;

    return $self->result_source()->schema()->resultset('Infods');

}

1;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
