package MetamodWeb::Schema::Userbase::ResultSet::Infods;

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

use base 'MetamodWeb::Schema::Resultset';

use Log::Log4perl qw( get_logger );
use Try::Tiny;
use XML::LibXML;

my $logger = get_logger('metamod.userbase');

=head2 $self->create_or_update_projection_xml( $ds_id, $projection_xml )

Create or update the PROJECTION_XML information for a specified dataset. This
function provided validation of the XML before it is inserted into the database.

If the provided XML is not valid and does not conform to the XSD schema it will
throw and exception.

=over

=item $ds_id

The C<ds_id> of the dataset that the information should be connected to.

=item $projection_xml

The XML to insert.

=item return

Returns the C<DBIx::Class> row object for the new or updated row.

=back

=cut

sub create_or_update_projection_xml {
    my $self = shift;

    my ( $ds_id, $projection_xml ) = @_;

    die 'Projection xml cannot be undef' if !defined $projection_xml;

    try {
        $self->validate_projection_xml($projection_xml);
    }
    catch {
        $logger->error("Tried to store invalid XML for projection: $_");
        die "Projection XML is either not valid XML or does not satisfy XSD. See log for details";
    };

    my $infods = $self->search( { ds_id => $ds_id, i_type => 'PROJECTION_XML' } )->first();

    if ( !defined $infods ) {
        return $self->create( { ds_id => $ds_id, i_type => 'PROJECTION_XML', i_content => $projection_xml } );
    } else {
        return $infods->update( { i_content => $projection_xml } );
    }

}

=head2 $self->validate_projection_xml($projection_xml)

Validate an XML string is valid XML and that it conforms to the XSD schema for
projections.

This method throws and exception if the XML is not valid.

=over

=item $projection_xml

The XML to validate.

=item return

Returns 1 on success. On failure it will throw an exception.

=back

=cut

sub validate_projection_xml {
    my $self = shift;

    my ($projection_xml) = @_;

    my $xsd_validator = $self->projection_validator();
    return $self->_validate_xml( $xsd_validator, $projection_xml );

}

=head2 $self->projection_validator()

=over

=item return

The XSD validator for projection XML.

=back

=cut

sub projection_validator {
    my $self = shift;

    if ( $self->{_projection_validator} ) {
        return $self->{_projection_validator};
    }

    my $config      = Metamod::Config->new();
    my $schema_file = $config->get("TARGET_DIRECTORY") . '/common/schema/fimexProjections.xsd';
    my $validator   = XML::LibXML::Schema->new( location => $schema_file );

    $self->{_projection_validator} = $validator;
    return $validator;

}

=head2 $self->create_or_update_wms_xml( $ds_id, $wms_xml )

Create or update the WMS_XML information for a specified dataset. This
function provided validation of the XML before it is inserted into the database.

If the provided XML is not valid and does not conform to the XSD schema it will
throw and exception.

=over

=item $ds_id

The C<ds_id> of the dataset that the information should be connected to.

=item $wms_xml

The XML to insert.

=item return

Returns the C<DBIx::Class> row object for the new or updated row.

=back

=cut

sub create_or_update_wms_xml {
    my $self = shift;

    my ( $ds_id, $wms_xml ) = @_;

    die 'WMS xml cannot be undef' if !defined $wms_xml;

    try {
        $self->validate_wms_xml($wms_xml);
    }
    catch {
        $logger->error("Tried to store invalid XML for WMS setup: $_");
        die "WMS setup is either not valid XML or does not satisfy XSD. See log for details";
    };

    my $infods = $self->search( { ds_id => $ds_id, i_type => 'WMS_XML' } )->first();

    if ( !defined $infods ) {
        return $self->create( { ds_id => $ds_id, i_type => 'WMS_XML', i_content => $wms_xml } );
    } else {
        return $infods->update( { i_content => $wms_xml } );
    }

}

=head2 $self->validate_wms_xml($wms_xml)

Validate an XML string is valid XML and that it conforms to the XSD schema for
WMS setup.

This method throws and exception if the XML is not valid.

=over

=item $projection_xml

The XML to validate.

=item return

Returns 1 on success. On failure it will throw an exception.

=back

=cut

sub validate_wms_xml {
    my $self = shift;

    my ($wms_xml) = @_;

    my $xsd_validator = $self->wms_validator();
    return $self->_validate_xml( $xsd_validator, $wms_xml );

}

=head2 $self->wms_validator()

=over

=item return

The XSD validator for WMS setup XML.

=back

=cut

sub wms_validator {
    my $self = shift;

    if ( $self->{_wms_validator} ) {
        return $self->{_wms_validator};
    }

    my $config      = Metamod::Config->new();
    my $schema_file = $config->get("TARGET_DIRECTORY") . '/common/schema/ncWmsSetup.xsd';
    my $validator   = XML::LibXML::Schema->new( location => $schema_file );

    $self->{_projection_validator} = $validator;
    return $validator;
}

sub _validate_xml {
    my $self = shift;

    my ( $xsd_validator, $xml ) = @_;

    my $parser = $self->xml_parser();

    # throws exception on error
    my $dom = $parser->parse_string($xml);

    return if !defined $dom;

    # throws exception on error
    $xsd_validator->validate($dom);

    return 1;

}

sub xml_parser {
    my $self = shift;

    if ( $self->{_xml_parser} ) {
        return $self->{_xml_parser};
    }

    my $parser = XML::LibXML->new();
    $self->{_xml_parser} = $parser;
    return $parser;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
