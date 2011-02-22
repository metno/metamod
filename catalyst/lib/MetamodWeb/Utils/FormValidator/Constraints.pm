package MetamodWeb::Utils::FormValidator::Constraints;

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

use strict;
use warnings;

use Log::Log4perl qw(get_logger);
use Try::Tiny;
use XML::LibXML;

=head1 NAME

MetamodWeb::Utils::FormValidator::Constraints - Data::FormValidator constraint functions that can be used in form profiles.

=head1 DESCRIPTION

The module implements "new" style C<Data::FormValidator> constraints. See the
documentation of each constraint for details.

All these constraint functions are based on closures to be sure you understand
closures before changing them.

=head1 FUNCTIONS/METHODS

=cut

=head2 xml($schema)

Create a constraint function that validates that the value is both valid XML
and that it conforms to the supplied schema.

=over

=item $schema

The path to a XSD schema.

=item return

Returns a constraint functions that will validate a field according to the schema.

=back

=cut
sub xml {
    my ($schema) = @_;

    my $xsd_validator = XML::LibXML::Schema->new( location => $schema );
    my $parser        = XML::LibXML->new();

    my $validator = sub {
        my ($dfv, $value) = @_;

        return 1 if !$value;

        my $dom = try {
            $parser->parse_string($value);
        } catch {

            # probably a abuse of name_this(), but cannot find any other way to set
            # a informative error message
            $dfv->name_this("Not valid XML: $_");
            return;
        };

        return if !defined $dom;

        get_logger()->debug('Here');
        my $success;
        my $error = try {
            $xsd_validator->validate($dom);
            $success = 1;
        } catch {

            # probably a abuse of name_this(), but cannot find any other way to set
            # a informative error message
            $dfv->name_this("XML failed schema validation: $_");
        };

        return $success;
    }

}


=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut
1;