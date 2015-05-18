package Metamod::DBIxSchema::Resultset;

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

use base 'DBIx::Class::ResultSet';

use Metamod::Config;

=head1 NAME

Metamod::DBIxSchema::Resultset - Base class for results sets.

=head1 DESCRIPTION

This module extends the standard C<DBIx::Class::ResultSet> with some additional
methods that can be used for all result sets in MetamodWeb.

=head1 FUNCTIONS/METHODS

=cut

=head2 $self->fulltext_search($search_text)

Create a PostgreSQL fulltext search expression that can be used as part of a
DBIx::Class search conditon.

For instance

  my $search_text = 'dummy'
  my $dataset_rs = $model->resultset('Dataset');
  my $result_rs = $dataset_rs->search( fulltext_column_name => $dataset_rs->fulltext_search($search_text));

=over

=item $search_text

The search text that will be used for searching. In simple mode, the text will be split on
spaces and then search expression that is created will AND them together in
PostgreSQL syntax. For instance if searching for "hirlam ice" we get the search
text "hirlam & ice" sent to PostgreSQL.

In advanced mode, all words must be separated by one of the operators AND, OR or NOT, optionally with parenthesis.
Complete phrases can be used enclosed in <i>single</i> quotes (not double).
Wildcards (*) are allowed at the end of a word, but not elsewhere.

=item return

Returns the correct PostgreSQL syntax as a reference to a scalar. A reference
to a scalar is so that C<DBIx::Class> interprets it as a raw SQL.

=back

=cut

sub fulltext_search {
    my $self = shift;

    local ($_) = @_;

    if (/ AND | OR | NOT | [&|!()*] /x) { # allow mnemonic operators
        s/[^:]\K[*]/:*/g; # allow * wildcard w/o preceding colon
        s/\bAND\b/&/g;
        s/\bOR\b/|/g;
        s/\bNOT\b/!/g;
        s|[_]||g;
        #print STDERR "++++++++++++++REGEX: $_\n";
        my $quoted_text = $self->quote_sql_value($_);
        #print STDERR "BOOL: $_ => $quoted_text\n";
        return \"@@ to_tsquery( 'english', $quoted_text )";
    } else {
        #s/^\s+//; # remove leading and trailing spaces
        #s/\s+$//; # to avoid malformed SQL
        #my @search_words = split /\s+/;
        #$_ = join ' & ', @search_words;
        s|[_]||g;
        my $quoted_text = $self->quote_sql_value($_);
        #print STDERR "PLAIN: $_ => $quoted_text\n";
        return \"@@ plainto_tsquery( 'english', $quoted_text )";
    }
}


=head2 $self->quote_sql_value($value)

Quote a concrete value correctly. This function is used when you cannot use
normal SQL binding since the query has to contain raw SQL. For instance when
generating PostgreSQL specific SQL.

=over

=item $value

The value to quote.

=item return

The value which has now been quoted.

=back

=cut

sub quote_sql_value {
    my $self = shift;

    my ( $value ) = @_;

    my $dbh         = $self->result_source->schema->storage->dbh;
    my $quoted_value = $dbh->quote($value);

    return $quoted_value;

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
