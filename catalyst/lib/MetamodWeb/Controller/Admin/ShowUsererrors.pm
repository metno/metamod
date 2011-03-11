package MetamodWeb::Controller::Admin::ShowUsererrors;
 
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

BEGIN {extends 'Catalyst::Controller'; }

use Metamod::Config;
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
 
sub show_usererrors : Path("/admin/usererrors") :Args(0) {
    my ( $self, $c ) = @_;
 
    $c->stash(template => 'admin/show_usererrors.tt');
    $c->stash(current_view => 'Raw');
    my $config = $c->stash->{ mm_config };
    my $localurl = $config->get("LOCAL_URL");
    $c->stash(localurl => $localurl);
    my $baseurl = $config->get("BASE_PART_OF_EXTERNAL_URL");
    $c->stash(baseurl => $baseurl);
    my $webrundir = $config->get("WEBRUN_DIRECTORY");
    my $uerrdir = $webrundir . "/upl/uerr";
    opendir(UERRDIR,$uerrdir) || die "Could not open directory $uerrdir: $!\n";
    my %fileshash = ();
    foreach my $fname (readdir(UERRDIR)) {
       if ($fname =~ /\.html$/) {
          my @statarr = stat($uerrdir . '/' . $fname);
          if (scalar @statarr == 0) {
             die "Could not stat $fname\n";
          }
          my $epochtime = $statarr[9];
          my @utctime = gmtime $epochtime;
          my $year = 1900 + $utctime[5];
          my $month = $utctime[4] + 1;
          my $day = $utctime[3];
          my $hour = $utctime[2];
          my $minute = $utctime[1];
          my $datetime = sprintf('%04d-%02d-%02d %02d:%02d',$year,$month,$day,$hour,$minute);
          $fileshash{$fname} = $datetime;
       }
    }
    closedir(UERRDIR);
    my @filesarr = sort {$fileshash{$a} cmp $fileshash{$b}} keys(%fileshash);
    my @wholetable = ();
    foreach my $fname (@filesarr) {
       unshift @wholetable, {datetime => $fileshash{$fname}, filename => $fname};
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
