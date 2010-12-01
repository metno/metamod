package MetamodWeb::ActionRole::DumpQueryLog;

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

use Moose::Role;
use Try::Tiny;
use namespace::autoclean;

after 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    my $beautifier;
    try {
        require SQL::Beautify;
        $beautifier = SQL::Beautify->new();
    } catch {
        $c->log->info('SQL::Beautify is not installed. Cannot beautify SQL');
    };

    my $query_log = $c->stash->{ query_log };
    my $ana = DBIx::Class::QueryLog::Analyzer->new({ querylog => $query_log });

    my $queries = $ana->get_totaled_queries();
    while( my ( $sql, $info ) = each %$queries ){

        if( $beautifier){
            $beautifier->query($sql);
            $sql = $beautifier->beautify();
        }

        my $log_msg = <<END_MSG;
SQL:
$sql
count: $info->{ count }
time_elapsed: $info->{ time_elapsed }
END_MSG

        $c->log->debug( $log_msg );
    }

};

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;