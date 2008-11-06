#! /usr/bin/perl -w
# this program detects a 'XML::LibXML: unregistering node, while no nodes have been registered?' found
# on Fedora Core 5 with XML::LibXML 1.66 and XML::LibXSLT 1.62.
# not found on debian 3.1 with XML::LibXML 1.58 and XML::LibXSLT 1.57

use strict;
use warnings;
use XML::LibXML;
use XML::LibXSLT;

my $xslt = <<'EOF';
<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml" indent="yes" encoding="iso8859-1"/>

    <xsl:template match="/">
        <xsl:processing-instruction name="xml-stylesheet">href="dataset.xsl" type="text/xsl"</xsl:processing-instruction>
    </xsl:template>
</xsl:stylesheet>
EOF

my $xml = <<'EOF';
<?xml version="1.0" encoding="ISO-8859-1"?>
<dataset>
</dataset>
EOF

my $tDoc;
{
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string($xml);
    my $styleDoc = $parser->parse_string($xslt);    
    my $stylesheet = XML::LibXSLT->new->parse_stylesheet($styleDoc);
    $tDoc = $stylesheet->transform($doc);
}
print STDERR "made it here\n";
undef $tDoc;
print STDERR "after undef, look for a XML::LibXML warning after 'made it here'\n";
