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

use DBIx::Class::QueryLog::Analyzer;
use Moose::Role;
use Try::Tiny;
use namespace::autoclean;

=head1 NAME

MetamodWeb::ActionRole::DumpQueryLog - Moose/Catalyst action role for dumping a DBIx::Class query log.

=head1 DESCRIPTION

This module implements a Moose/Catalyst action role that when applied to an
action with C<:Does('DumpQueryLog')> will dump a C<DBIx::Class> query log with C<$c->log->debug()>

For the dumping to work you must first initialise the C<DBIx::Class> query log
with C<MetamodWeb::ActionRole::InitQueryLog> action role.

=head1 METHODS

=cut

after 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    # tracing is not enabled, so nothing to do
    return unless exists $ENV{METAMOD_DBIC_TRACE} && $ENV{METAMOD_DBIC_TRACE} == 1;

    # We use SQL::Beautify to get more readable SQL if it is available, but we
    # do not want to have SQL::Beautify as a requirement for MetamodWeb
    my $beautifier;
    try {
        require SQL::Beautify;
        $beautifier = SQL::Beautify->new();
    } catch {
        $c->log->info('SQL::Beautify is not installed. Cannot beautify SQL');
    };

    my $mb_query_log = $c->stash->{ mb_query_log };
    _print_query_log($c, $mb_query_log,$beautifier);

    my $ub_query_log = $c->stash->{ ub_query_log };
    _print_query_log($c, $ub_query_log,$beautifier);


    my $ana = DBIx::Class::QueryLog::Analyzer->new({ querylog => $mb_query_log });

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

sub _print_query_log {
    my ($c, $query_log, $beautifier) = @_;

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

}

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;