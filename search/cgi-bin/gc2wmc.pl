#!/usr/bin/perl -w
use strict;
use LWP::UserAgent;
use XML::LibXSLT;
use XML::LibXML;
use CGI;
use Data::Dumper;

####################
# info from metamod
#
my @p_layers = qw(lat lon);
my @p_styles = qw(BOXFILL/ferret BOXFILL/greyscale);
my $wmcns = "http://www.opengis.net/context";

################
# init
#
our $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();

my $q = CGI->new;
my $setup_url = $q->param('setup') or die "Missing setup file URL";

printf STDERR "*** setup = '%s'\n*** url = '%s'\n", $setup_url || '-', $q->param('url') || '-';

####################
# webservice client
#
sub getXML {
    my $url = shift or die "Missing URL";
    printf STDERR "GET %s\n", $url;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(100);
    #$ua->env_proxy;

    my $response = $ua->get($url);

    if ($response->is_success) {
        #print STDERR $response->content;
        return $parser->parse_string($response->content);
    }
    else {
        die $response->status_line;
    }
}

#################################
# read setup document
#
my $setup = getXML($setup_url);
my $sxc = XML::LibXML::XPathContext->new( $setup->documentElement() );
$sxc->registerNs('s', "http://www.met.no/schema/metamod/ncWmsSetup");
#print STDERR $setup->toString;
my %bbox = ();
foreach ($sxc->findnodes('/*/s:displayArea/@*')) {
    my ($k, $v) = ($_->localname, $_->getValue);
    $bbox{ $k } = $v; #( $v != 0 ) ? $v : "'$v'";
}
#print STDERR Dumper( \%bbox );

#################################
# transform Capabilities to WMC
#
my $getcap = $q->param('url') || $setup->documentElement->getAttribute('url') or die "Missing URL";
printf STDERR "XML: %s\n", $getcap;
$getcap .= '?service=WMS&version=1.3.0&request=GetCapabilities';
my $stylesheet = $xslt->parse_stylesheet( $parser->parse_file('cc-wmc.xsl') );
my $results = $stylesheet->transform( getXML($getcap), XML::LibXSLT::xpath_to_string(%bbox) );
my $xc = XML::LibXML::XPathContext->new( $results->documentElement() );
$xc->registerNs('v', $wmcns);
$xc->registerNs('w', "http://www.opengis.net/wms"); # only used to work around bug in XSL
my ($layerlist) = $xc->findnodes('/*/v:LayerList');


##############
# sort styles
#
#foreach my $stylelist ($xc->findnodes("v:Layer/v:StyleList", $layerlist)) {
#
#    my $newstyles = $results->createElementNS($wmcns, 'StyleList');
#    foreach my $sname ( @p_styles ) {
#        #move priority styles
#        foreach ($xc->findnodes("w:Style[w:Name = '$sname']", $stylelist)) {
#            $newstyles->appendChild( $stylelist->removeChild($_));
#        }
#    }
#    #move rest of styles
#    foreach ($xc->findnodes("w:Style", $stylelist)) {
#        $newstyles->appendChild( $stylelist->removeChild($_));
#    }
#    # replace old (empty) styles list with new sorted
#    $stylelist->addSibling($newstyles);
#    $stylelist->unbindNode;
#
#}


######################
# sort layers & styles
#
my $newlayers = $results->createElementNS($wmcns, 'LayerList');

# loop thru layers in setup file
foreach ( $sxc->findnodes('/*/s:layer') ) {
    my $lname = $_->getAttribute('name');
    my $style = $_->getAttribute('style') || '';
    # find matching layer nodes in Capabilities
    foreach my $layer ($xc->findnodes("v:Layer[v:Name = '$lname']", $layerlist)) {
        foreach ( $xc->findnodes("v:StyleList/w:Style[w:Name = '$style']", $layer) ) { # FIXME: wrong namespace
            # move preferred style node to top of list
            my $pn = $_->parentNode;
            $pn->insertBefore( $pn->removeChild($_), $pn->firstChild);
        }
        # move priority layer to new list
        $newlayers->appendChild( $layerlist->removeChild($layer) );
    }
}

# move rest of layers to new list
foreach ($xc->findnodes("v:Layer", $layerlist)) {
    $newlayers->appendChild( $layerlist->removeChild($_));
}

# replace old (empty) layer list with new sorted
$layerlist->addSibling($newlayers);
$layerlist->unbindNode;


#############
# output XML
#
print $q->header('application/xml');
my $out = $stylesheet->output_as_bytes($results);
$out =~ s| xmlns="http://www.opengis.net/wms"||g; # hack... fix in xsl
$out =~ s|( xmlns:xlink="http://www.w3.org/1999/xlink"){2}|$1|g;
# another hack to work around bug suddenly appearing for no logical reason
print $out;

