package MetamodWeb::Controller::API;

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
use Metamod::SearchUtils;
use Metamod::Config;

use namespace::autoclean;
use JSON;
use Data::Dumper;

use constant TRUE  => JSON::true;
use constant FALSE => JSON::false;

=head1 NAME

MetamodWeb::Controller::API - Controller for data search & retrieval API

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

BEGIN { extends 'MetamodWeb::BaseController::Base'; }

my $j = JSON->new->utf8;
#$j->pretty(1);
$j->indent(1);
$j->canonical(1); # make sure hashes are sorted consistently

sub auto :Private {
    my ( $self, $c ) = @_;

    # get search categories list
    # faking MetamodWeb::Utils::UI::Search::search_categories here, getting results as array instead of DBIx::Class objects
    my @cats = $c->model('Metabase::Searchcategory')->search( {}, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' })->all;
    $c->stash( searchcategories => \@cats );
    my $conf = $c->stash->{mm_config};
    if ($c->request->headers->header('x-forwarded-for')) {
        $c->stash( basepath => $conf->get('BASE_PART_OF_EXTERNAL_URL').$conf->get('LOCAL_URL') );
    } else {
        $c->stash( basepath => $c->request->base->as_string );
    }

}

# TODO: expand sc_fnc

sub searchcategories :Path('/api/searchcategories') :Args {
    my ($self, $c) = @_;
    #my $format = lc(shift)||'json';
    $c->response->content_type("application/json");
    $c->response->body( $j->encode( $c->stash->{searchcategories}) );
}


# TODO: include children, search by parent

sub search :Path('/api/search') :Args(0) {
    my ( $self, $c ) = @_;
    my $config = $c->stash->{mm_config};

    eval {

        my $search_utils = Metamod::SearchUtils->new( { config => $config } );
        my $param = $c->req->query_params;
        #print STDERR Dumper $param;
        my $search_criteria = $search_utils->selected_criteria( $c->stash->{searchcategories}, $param );
        $search_criteria->{ds_parent} |= 0 unless $param->{ds_id};
        $search_criteria->{ds_status} |= 1 unless $param->{ds_id};
        #print STDERR Dumper $search_criteria;

        my $rs = $c->model('Metabase::Dataset');
        my @datasets;

        if ($param->{ds_id}) { # lookup by id
            my $ds = $rs->find($param->{ds_id}) or die "Dataset not found";
            my $data = _read_dataset($ds);
            push @datasets, $data;
            if ($param->{all}) {
                for (@{$data->{children}}) {
                    my $ds = $rs->find($_) or die "Dataset not found";
                    push @datasets, _read_dataset($ds);
                }
            }
        } else { # search by criteria
            my $result = $rs->metadata_search(
                ownertags => $config->split('DATASET_TAGS'),
                search_criteria => $search_criteria,
                all_levels => ( $param->{all}||0 ),
                rows_per_page => ( $param->{rows}||20 ),
            );
            while (my $ds = $result->next) {
                push @datasets, _read_dataset($ds);
            }
        }

        $c->response->content_type('application/json');
        # return the document in utf encoding
        $c->response->body( $j->encode( \@datasets ) );
    };

    if( $@ ){
        $self->logger->warn("Error in dataset output: $@");
        $c->detach( 'Root', 'error', [404, $@] );
    }

}

sub _read_dataset {
    my $ds = shift or die;
    # primary columns
    my %fields = $ds->get_columns;
    # fetch metadata
    my $md = $ds->metadata();
    foreach my $k (keys %$md) {
        my @val = @{ $md->{$k} };
        $fields{$k} = @val > 1 ? \@val : $val[0];
    }
    #$ds->num_children,
    $fields{children} = [ map( $_->ds_id, $ds->child_datasets->all ) ];
    return \%fields;
}

sub searchkeys :Path('/api') :Args(1) {
    my ( $self, $c, $key ) = @_;
    my $param = $c->req->query_params;
    my (%sc_index, @keys);
    $sc_index{$_->{sc_idname}} = $_ foreach @{$c->stash->{searchcategories}};
    #print STDERR Dumper \%sc_index;
    if (my $sc = $sc_index{$key}) {
        if ($sc->{sc_type} eq 'basickey') {
            @keys = $c->model('Metabase::Basickey')->search( { sc_id => $sc->{sc_id} },
                { result_class => 'DBIx::Class::ResultClass::HashRefInflator' })->all;
        } elsif ($sc->{sc_type} eq 'tree') {
            my $rs = $c->model('Metabase::Hierarchicalkey');
            my @flat_keys = $rs->search( { sc_id => $sc->{sc_id} },
                { result_class => 'DBIx::Class::ResultClass::HashRefInflator' })->all;
            my %hk_index;
            $hk_index{$_->{hk_id}} = $_ foreach @flat_keys;
            foreach (@flat_keys) {
                if ($_->{hk_parent} == 0 || $param->{flat}) {
                    push @keys, $_;
                } else {
                    my $parent = $hk_index{$_->{hk_parent}};
                    if (exists $parent->{sublevels}) {
                        push @{$parent->{sublevels}}, $_;
                    } else {
                        $parent->{sublevels} = [ $_ ];
                    }
                }
            }

        } else {
            die;
        }

        $c->response->content_type('application/json');
        $c->response->body( $j->encode( \@keys ) );
    } else {
        die;
    }

}

sub projections :Path('/api/projections') :Args(0) {
    my ( $self, $c ) = @_;
    my $config = $c->stash->{mm_config};
    my $projs = $config->split('WMS_PROJECTIONS');
    $c->response->content_type('application/json');
    $c->response->body( $j->encode( $projs ) );
}

=head2 api-docs

Swagger API metadata - top level

=cut

my %apis = (
    "/api" => "Search API",
    "/dataset" => "Download XML dataset documents",
    #"/gc2wmc" => "WMC document generator from WMS GetCapabilities",
    #"/multiwmc" => "WMC document generator from several datasets",
    #"/qtips" => "CGI query string parameter as XML",
);

sub api_docs :Path('/api-docs') :Args(0) {
    my ($self, $c) = @_;
    my $swag = {
        "apiVersion" => "v0",
        "swaggerVersion" => "1.2",
    };

    my @res;
    push @res, { "path" => $_, "description" => $apis{$_} } for keys %apis;
    $swag->{apis} = \@res;

    print STDERR Dumper $c->request;
    $c->response->content_type('application/json');
    $c->response->body( $j->encode( $swag ) );
}

=head2 /api-docs/dataset

Swagger metadata for XML download

=cut

sub api_docs_dataset :Path('/api-docs/dataset') :Args(0) {
    my ($self, $c) = @_;

    my $swag = {
        "apiVersion" => "v0",
        "swaggerVersion" => "1.2",
        "basePath" => $c->stash->{basepath},
        "resourcePath" => "/dataset",
        "produces" => ["application/xml"],
        "apis" => [
            {
                "path" => "/dataset/{id}/{format}",
                "operations" => [
                    {
                        "method" => "GET",
                        "summary" => "Get dataset XML documents in MM2, DIF, ISO, RSS or WmsSetup formats",
                        "type" => "string",
                        "nickname" => "dataset",
                        "parameters" => [
                            {
                                "name" => "id",
                                "description" => "Dataset id",
                                "required" => TRUE,
                                "type" => "integer",
                                "paramType" => "path",
                                "allowMultiple" => FALSE
                            },
                            {
                                "name" => "format",
                                "description" => "Output format/data",
                                "required" => TRUE,
                                "type" => "string",
                                "paramType" => "path",
                                "allowMultiple" => FALSE,
                                "enum" => [ "xml", "wmsinfo", "rss" ]
                            },
                        ],
                        "responseMessages" => [
                            {
                                "code" => 400,
                                "message" => "An error in the request"
                            },
                            {
                                "code" => 404,
                                "message" => "No data was found"
                            }
                        ]
                    }
                ]
            },
        ]
    };

    $c->response->content_type('application/json');
    $c->response->body( $j->encode( $swag ) );
}

=head2 /api-docs/api

Swagger API metadata for search API

=cut

sub api_docs_api :Path('/api-docs/api') :Args(0) {
    my ($self, $c) = @_;

    my $swag = {
        "apiVersion" => "v0",
        "swaggerVersion" => "1.2",
        "basePath" => $c->stash->{basepath},
        "resourcePath" => "/api",
        "produces" => ["application/json"],
        "apis" => []
    };

    push @{$swag->{apis}}, _api_elem('projections', "List supported projections for map search");
    push @{$swag->{apis}}, _api_elem('searchcategories', "List searchcategories from the database");

    my $search = {
        "path" => "/api/search",
        "operations" => [
            {
                "method" => "GET",
                "summary" => "Search for datasets",
                "type" => "string",
                "nickname" => "search",
                "parameters" => [
                    {
                        "name" => "ds_id",
                        "description" => "Dataset id (NOT IMPLEMENTED)",
                        "required" => FALSE,
                        "type" => "integer",
                        "paramType" => "query",
                        "allowMultiple" => FALSE
                    },
                    {
                        "name" => "all",
                        "description" => "Include child datasets in search",
                        "required" => FALSE,
                        "type" => "integer",
                        "paramType" => "query",
                        "allowMultiple" => FALSE
                    },
                ],
                "responseMessages" => [
                    {
                        "code" => 400,
                        "message" => "An error in the request"
                    }
                ]
            }
        ]
    };

    my %descr = (
        fulltext => "text search with boolean operators (see PostgreSQL docs)",
        date_interval => "Date in YYYY-MM-DD format (my be shortened)",
        map_search => 'Geographical coordinates in "east,south,west,north,projection" format (projection is EPSG code number)',
    );
    for my $sc (@{$c->stash->{searchcategories}}) {
        #print STDERR Dumper $sc;
        my $id = $sc->{sc_idname};
        my ($name) = $sc->{sc_fnc} =~ /name: ([^;]+)/;
        my $getparams = $search->{operations}->[0]->{parameters};
        # push to dataset args
        if ($sc->{sc_type} eq 'basickey') {
            push @{$swag->{apis}}, _api_elem($sc->{sc_idname}, $name);
            push @$getparams, _api_param($id, "/api/$id bk_id (comma separated)", "integer", TRUE);
        } elsif ($sc->{sc_type} eq 'tree') {
            push @{$swag->{apis}}, _api_elem($sc->{sc_idname}, $name, ['flat', 'If true, do not print as tree']);
            push @$getparams, _api_param($id, "/api/$id bk_id (comma separated)", "integer", TRUE);
        } elsif ($sc->{sc_type} eq 'date_interval') {
            push @$getparams, _api_param('date_from', $descr{$sc->{sc_type}}, "string", FALSE);
            push @$getparams, _api_param('date_to', $descr{$sc->{sc_type}}, "string", FALSE);
        } else {
            push @$getparams, _api_param($id, $descr{$sc->{sc_type}}, "string", FALSE);
        }
    }
    push @{$swag->{apis}}, $search;

    my $j = JSON->new->utf8;
    #$j->pretty(1);
    $j->indent(1);

    $c->response->content_type('application/json');
    $c->response->body( $j->encode( $swag ) );
}

sub _api_param {
    my ($name, $desc, $type, $multi) = @_;
    my %param = (
        name => $name,
        "description" => $desc,
        "required" => FALSE,
        "type" => $type||"integer",
        "paramType" => "query",
        "allowMultiple" => defined $multi ? $multi : FALSE,
    );
    return \%param;
}

sub _api_elem {
    my ($id, $desc, $params) = @_;
    my %key = (
        path => "/api/$id",
        operations => [
            {
                "method" => "GET",
                "summary" => $desc,
                "type" => "string",
                "nickname" => $id,
                "responseMessages" => [
                    {
                        "code" => 400,
                        "message" => "An error in the request"
                    }
                ]
            }
        ]
    );
    $key{operations}->[0]->{parameters} = _api_param(@$params) if $params;
    return \%key;
}


__PACKAGE__->meta->make_immutable;

=head1 LICENSE

GPLv2 L<http://www.gnu.org/licenses/gpl-2.0.html>

=cut

1;
