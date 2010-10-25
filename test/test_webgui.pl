#!/usr/bin/perl

use strict;
use warnings;

use Test::More (tests => 50);
use Test::WWW::Mechanize;
use HTML::TreeBuilder;

local $\ = "\n";
local $| = 1;

my $mech = Test::WWW::Mechanize->new();

my $starturl  = "http://dev-vm140.oslo.dnmi.no/Metamod2.x/sch/";
my $errortext = qr/Your previous session was terminated because of: (.*)<\/p>/;

$mech->get_ok( $starturl );
$mech->content_unlike($errortext, "Session OK");


$mech->follow_link_ok({text => "Topics and variables"}, 
		      q(CLICK "Topics and variables"));
$mech->content_unlike($errortext, "Session OK");

#print q(CLICK "+" before Cryosphere);
find_and_click_button($mech, "Cryosphere");

#print q(CHECK "Cryosphere > Sea Ice");
find_and_tick_checkbox($mech, "Cryosphere > Sea Ice");

click_select($mech);

#print 
$mech->follow_link_ok({text => "Activity types"},
		      q(CLICK "Activity types"));
$mech->content_unlike($errortext, "Session OK");


#print q(CHECK Cruise);
find_and_tick_checkbox($mech, "Cruise");

#print q(CLICK "SELECT");
click_select($mech);

{
#   Result: FIMR_2
    my @expected = ("FIMR_2");
    my @res = find_results($mech->content());
    is_deeply(parse_results(\@res), \@expected, "Result: @expected");
}

$mech->follow_link_ok({text_regex => qr/Topics and variables/i},
		      q(CLICK "Topics and variables"));
$mech->content_unlike($errortext, "Session OK");

#print q(CLICK "CLEAR ALL");
click_clearall($mech);

$mech->follow_link_ok({text_regex => qr/Datacollection period/i},
		      q(CLICK "Datacollection period"));
$mech->content_unlike($errortext, "Session OK");

#print q(INSERT "FROM" = "2005-08-01");
$mech->field(from => "2005-08-01");

#print q(INSERT "TO" = "2005-12-31");
$mech->field(to => "2005-12-31");

#print q(CLICK "OK");
click_ok($mech);

{
#   Result: AWI_1
#           vagabond
    my @expected = qw(AWI_1 vagabond);
    my @res = find_results($mech->content());
    is_deeply(parse_results(\@res), \@expected, "Result: @expected");
}


$mech->follow_link_ok({text => "Search"},
		      q(CLICK "Search"));
$mech->content_unlike($errortext, "Session OK");

#print q(INSERT "Query-String:" = "Eric Brossier");
$mech->field(fullTextQuery => "Eric Brossier");

#print q(CLICK "OK");
click_ok($mech);

{
#   Result: vagabond
    my @expected = qw(vagabond);
    my @res = find_results($mech->content());
    is_deeply(parse_results(\@res), \@expected, "Result: @expected");
}

$mech->follow_link_ok({text => "Search"},
		      q(CLICK "Search"));

#print q(CLICK "REMOVE");
click_remove($mech);

$mech->follow_link_ok({text => "Activity types"},
		      q(CLICK "Activity types"));
$mech->content_unlike($errortext, "Session OK");

#print q(CLICK "CLEAR ALL");
click_clearall($mech);

$mech->follow_link_ok({text => "Map search"},
		      q(CLICK "Map search"));
$mech->content_unlike($errortext, "Session OK");

#print q(SELECT "Select another area:" = "Antarctic");
$mech->form_with_fields("gamap_srid");
$mech->select("gamap_srid" => 93031); #FIXME? hardcoding of values

#print q(CLICK "SWITCH MAP");
click_switchmap($mech);

#print q(CLICK IN MAP on "uppermost land tip");
$mech->click(gacoord => 0,0);
$mech->content_unlike($errortext, q(CLICK IN MAP on "uppermost land tip"));

#print q(CLICK IN MAP on "rightmost land tip");
$mech->click(gacoord => 559, 559);
$mech->content_unlike($errortext, q(CLICK IN MAP on "rightmost land tip"));

#print q(CLICK "OK");
click_ok($mech);

$mech->follow_link_ok({text_regex => qr/Datacollection period/i},
		      q(CLICK "Datacollection period"));
$mech->content_unlike($errortext, "Session OK");

click_remove($mech);

$mech->follow_link_ok({text => "Activity types"},
		      q(CLICK "Activity types"));
$mech->content_unlike($errortext, "Session OK");

#print q(CHECK "Space borne instrument");
find_and_tick_checkbox($mech, "Space borne instrument");

#print q(CLICK "SELECT");
click_select($mech);

{
#   Result: gmmicemov
    my @expected = qw(gmmicemov);
    my @res = find_results($mech->content());
    is_deeply(parse_results(\@res), \@expected, "Result: @expected");

#print q(CLICK "+" before gmmicemov link);
    find_and_click_plus_button($mech, \@res, "gmmicemov");
}


{
#   Result: gmmicemov
#              gmmicemov_20060821-20060824
#              gmmicemov_20071009-20071012
#              gmmicemov_20060322-20060325
#              gmmicemov_20051225-20051228
#              gmmicemov_20060603-20060606
    my @expected = qw(
        gmmicemov_20060821-20060824
        gmmicemov_20071009-20071012
        gmmicemov_20060322-20060325
        gmmicemov_20051225-20051228
        gmmicemov_20060603-20060606
    );
    my @res = find_results($mech->content(), 2);
    is_deeply(parse_results(\@res), \@expected, "Result: @expected");
}

$mech->follow_link_ok({text => "Metadata Search"},
		      q(CLICK "Metadata search"));
$mech->content_unlike($errortext, "Session OK");

$mech->follow_link_ok({text => "Search"},
		      q(CLICK "Search"));
$mech->content_unlike($errortext, "Session OK");

#print q(INSERT "Query-String:" = "hirlam12");
$mech->field(fullTextQuery => "hirlam12");

#print q(CLICK "OK");
click_ok($mech);
#print $mech->content;

{
    my @expected = qw(hirlam12 U2x_metamod-2fU2x-2fhirlam12);
    my @res = find_results($mech->content());
    is_deeply(parse_results(\@res), \@expected, "Result: @expected");

#    print q(CLICK "+" before hirlam12 link);
    find_and_click_plus_button($mech, \@res, "hirlam12");
}

$mech->follow_link_ok({text => "hirlam12_sf_1h_2008-07-03_06"},
		      q(CLICK "hirlam12_sf_1h_2008-07-03_06" (first link after hirlam12)));

{
    local $/;
    my $target = <DATA>;
    my $content = $mech->content;

    $target =~ s/\s//g;
    $content =~ s/\s//g;

    SKIP: {
	skip("Unsure if the date will stay the same", 1);
	cmp_ok(lc $content, "eq", lc $target, "Got expected result from Thredds");
    }
}

sub find_results {
    my ($content, $level) = @_;
    my $tree = HTML::TreeBuilder->new_from_content($content);
    my $class = "tdresult";
    if (defined $level && $level == 2) {$class .= " secondlevel"}
    my $cell = $tree->look_down(_tag => "th", class => $class);
    my $table = $cell->look_up(_tag => "table");

    my ($header, @rows) = $table->look_down(_tag => "tr");

    my @titles = map {($_->as_text)} $header->look_down(_tag => "th");

    my @results;
    for my $row (@rows) {
	my %result;
	@result{@titles} = $row->look_down(_tag => "td");
	push @results, \%result;
    }
    return @results;
}

sub cleanup_result {
    my ($tree) = @_;
    $tree = $tree->clone;

    # Remove XML-link
    my ($buttons) = $tree->look_down(_tag => "div", class => "btns");
    if ($buttons) {
	$buttons->delete();
    }

    # Remove RSS-link
    my ($rss) = $tree->look_down(_tag => "img", alt => "RSS feed");
    if ($rss) {
	$rss->parent->delete();
    }

    # Trim whitespace
    my $content = $tree->as_text;
    $content =~ s/^\s+//;
    $content =~ s/\s+$//;

    return $content;
}

sub parse_results {
    my ($results) = @_;
    my @results;
    for my $res (@$results) {
	push @results, cleanup_result($res->{Name});
    }
    return \@results;
}

sub _click {
    $_[0]->click_button(value => $_[1]);
    $_[0]->content_unlike($errortext, "Click $_[1] button");
}

sub click_select    { _click($_[0], "Select"    )}
sub click_clearall  { _click($_[0], "Clear All" )}
sub click_ok        { _click($_[0], "OK"        )}
sub click_remove    { _click($_[0], "Remove"    )}
sub click_switchmap { _click($_[0], "Switch Map")}


sub _find_input {
    my ($content, $title, $type) = @_;
    my $tree = HTML::TreeBuilder->new_from_content($content);
    my $find_func;
    if (ref($title) eq "Regex") {
	$find_func = sub { $_[0]->as_text() =~ $title }
    } elsif (ref($title) eq "") {
	$find_func = sub { $_[0]->as_text() eq $title }
    } else {
	$find_func = sub { 1 };
    }

    my $node = $tree->look_down(_tag  => "span",
				$find_func);

    return unless defined $node;
    my @nodelist = reverse grep ref $_, $node->left();

    while ($node = shift @nodelist) {
	next unless ref $node;
	last if ($node->tag() eq "input" and 
		 lc $node->attr("type") eq lc $type);
    }
    return $node;
}

sub find_checkbox {
    return _find_input(@_[0,1], "checkbox");
}

sub find_button {
    return _find_input(@_[0,1], "submit");
}

sub find_and_tick_checkbox {
    my ($mech, $title) = @_;
    my $checkbox = find_checkbox($mech->content, $title);
    die "Could not find checkbox named $title" unless $checkbox;
    $mech->tick($checkbox->attr("name"), $checkbox->attr("value"));
}

sub find_and_click_button {
    my ($mech, $title) = @_;
    my $button = find_button($mech->content, $title);
    die "Could not find button named $title" unless $button;
    $mech->click_button(name => $button->attr("name"));
    $mech->content_unlike($errortext, "Session OK");
}

sub find_and_click_plus_button {
    my ($mech, $results, $title) = @_;
    my $res = parse_results($results);
    my $found = undef;
    for (my $i=0; $i<@$res; $i++) {
	if ($res->[$i] eq $title) {
	    $found=$i;
	    last;
	}
    }
    die qq(No result named "$title"\n) unless defined $found;

    my $tree = $results->[$found]->{Name}->clone;
    my $button = $tree->look_down(_tag => "input", 
				  class => "explusminus",
				  value => "+");
    die "Could not find plus-button" unless $button;
    $mech->click_button(name => $button->attr("name"));
    $mech->content_unlike($errortext, "Session OK");
}


__END__
        <!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN'
        'http://www.w3.org/TR/html4/loose.dtd'>
        <html>
        <head>
        <title> Catalog Services</title>
        <meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>
        <link rel='stylesheet' href='/thredds/tds.css' type='text/css' ></head>
        <body>
        <table width='100%'>
        <tr><td>
        <img src='/thredds/metepos.gif' alt='met.no' align='left' valign='top' hspace='10' vspace='2'>
        <h3><strong><a href='/thredds/catalog.html'>Met.no Thredds</a></strong></h3>
        <h3><strong><a href='http://www.unidata.ucar.edu/projects/THREDDS/tech/TDS.html'>THREDDS Data Server</a></strong></h3>
        </td></tr>
        </table>

        <h2> Catalog http://thredds.met.no/thredds/catalog/data/met.no/hirlam12/catalog.html</h2>
        <h2>Dataset: hirlam12/hirlam12_sf_1h_2008-07-03_06.nc</h2>
        <ul>
        <li><em>ID: </em>met.no/hirlam12/hirlam12_sf_1h_2008-07-03_06.nc</li>
        </ul>
        <h3>Access:</h3>
        <ol>
        <li> <b>OPENDAP:</b> <a href='/thredds/dodsC/data/met.no/hirlam12/hirlam12_sf_1h_2008-07-03_06.nc.html'>/thredds/dodsC/data/met.no/hirlam12/hirlam12_sf_1h_2008-07-03_06.nc</a></li>

        <li> <b>HTTPServer:</b> <a href='/thredds/fileServer/data/met.no/hirlam12/hirlam12_sf_1h_2008-07-03_06.nc'>/thredds/fileServer/data/met.no/hirlam12/hirlam12_sf_1h_2008-07-03_06.nc</a></li>
        </ol>
        <h3>Dates:</h3>
        <ul>
        <li>2010-09-13 00:00:12z <strong>(modified)</strong> </li>
        </ul>
        <h3>Viewers:</h3><ul>

        <li> <a href='/thredds/view/ToolsUI.jnlp?catalog=http://thredds.met.no/thredds/catalog/data/met.no/hirlam12/catalog.xml&amp;dataset=met.no/hirlam12/hirlam12_sf_1h_2008-07-03_06.nc'>NetCDF-Java ToolsUI (webstart)</a></li>
        </ul>
        </body>
        </html>
