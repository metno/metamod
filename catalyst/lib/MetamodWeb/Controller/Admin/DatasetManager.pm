package MetamodWeb::Controller::Admin::DatasetManager;

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

BEGIN {extends 'MetamodWeb::BaseController::Base'; }

use Metamod::Config;
use Metamod::Dataset;
# use Data::Dump;

=head1 NAME

<package name> - <description>

=head1 DESCRIPTION

=head1 METHODS

=cut

=head2 auto

=cut

sub auto :Private {
    my ( $self, $c ) = @_;

    # Controller specific initialisation for each request.
}

=head2 index

=cut

sub dataset_manager : Path("/admin/dsmanager") :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(template => 'admin/dataset_manager.tt');
    $c->stash(current_view => 'Raw');
    $c->stash(dsmanager_url => $c->uri_for('/admin/dsmanager'));
    my $config = $c->stash->{ mm_config };
    my $params = $c->req->parameters;
    my $regexp_value = "";
    if ($params->{'exp'} and $params->{'regexp'}) {
       $regexp_value = $params->{'regexp'};
    }
    $c->stash(regexp_value => $regexp_value);
    my $newtag = "";
    if ($params->{'owner'} and $params->{'newtag'}) {
       $newtag = $params->{'newtag'};
    }
    $c->stash(newtag => $newtag);
    my $select_html = "";
    foreach my $select_status ("All","Selected","Unselected") {
       my $chk = "";
       if (! $params->{'which'} and $select_status eq "All") {
          $chk = "checked ";
       } elsif ($params->{'which'} and $params->{'which'} eq $select_status) {
          $chk = "checked ";
       }
       $select_html .= $select_status .
                       ': <input type="radio" name="which" ' .
                       $chk.'value="'. $select_status .'" />' .
                       '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    }
    $c->stash(select_html => $select_html);
    my @columns = qw/ds_id ds_name ds_status ds_ownertag ds_filepath/;
    my $resultset = $c->model('Metabase::Dataset')->search({ds_parent => 0}, {columns => \@columns, order_by => 'ds_id'});
    my @wholetable = ();
    while (my $row = $resultset->next) {
       my $rowstring = "";
       my $checked = "";
       my %vals = $row->get_columns;
       my $dsid = $vals{'ds_id'};
       if ($params->{'all'}) {
          $checked = " checked";
       } elsif ($params->{'flip'}) {
          if (! $params->{'d' . $dsid}) {
             $checked = " checked";
          }
       } elsif ($params->{'d' . $dsid}) {
          $checked = " checked";
       } elsif ($regexp_value ne "" and $vals{'ds_name'} =~ $regexp_value) {
          $checked = " checked";
       }
       my $show = 1;
       my $type = "checkbox";
       if ($params->{'which'} and $params->{'which'} eq "Selected" and $checked eq "") {
          $show = 0;
          $type = "hidden";
       }
       if ($params->{'which'} and $params->{'which'} eq "Unselected" and $checked ne "") {
          $show = 0;
          $type = "hidden";
       }
       if ($show) {
          $rowstring .= '<tr><td bgcolor="#f5f5dc">';
       }
       if ($type eq "checkbox" or $checked eq " checked") {
          $rowstring .= '<input type="'. $type .'"' . $checked . ' name="d'. $dsid .
                        '" value="' . $dsid .'" />';
       }
       if ($show) {
          $rowstring .= '</td>';
       }
       if ($vals{'ds_status'} == 1) {
          $vals{'ds_status'} = "active";
       } else {
          $vals{'ds_status'} = "deleted";
       }
       if ($show) {
          foreach my $col (@columns) {
             $rowstring .= '<td>' . $vals{$col} . '</td>';
          }
          $rowstring .= '</tr>';
       }
       if ($checked eq " checked" and ($params->{'mdel'} or $params->{'activate'} or $params->{'owner'})) {
          my $filepath = $vals{'ds_filepath'};
          my $dsobj = Metamod::Dataset->newFromFile($filepath);
          unless ($dsobj) {
             die "cannot initialize dataset for $filepath";
          }
          my %dset_values = $dsobj->getInfo;
          if ($params->{'mdel'}) {
             $dset_values{'status'} = "deleted";
          }
          if ($params->{'activate'}) {
             $dset_values{'status'} = "active";
          }
          if ($params->{'owner'}) {
             $dset_values{'ownertag'} = $newtag;
          }
          $dsobj->setInfo(\%dset_values);
          $dsobj->writeToFile($filepath);
       }
       push @wholetable, $rowstring;
    }
    $c->stash(wholetable => \@wholetable);
}

#
# Remove comment if you want a controller specific begin(). This
# will override the less specific begin()
#
#sub begin {
#    my ( $self, $c ) = @_;
#}

#
# Remove comment if you want a controller specific end(). This
# will override the less specific end()
#
#sub end {
#    my ( $self, $c ) = @_;
#}


__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
