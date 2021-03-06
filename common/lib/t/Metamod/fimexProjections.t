#! /usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../..";

use Test::More tests => 9;
use Data::Dumper;
use Metamod::Config;

my $config = Metamod::Config->new("$FindBin::Bin/../master_config.txt");
$config->initLogger();

use_ok('Metamod::FimexProjections');

# setting target dir so that common is below
ok(-f Metamod::FimexProjections->getFimexProjectionsSchemaPath(), "found schema");

my $obj = new Metamod::FimexProjections();
isa_ok($obj, 'Metamod::FimexProjections');

my $exampleFileName = "$FindBin::Bin/fimexProjections.xml";
my $exampleData;
{
    open my $fh, $exampleFileName
        or die "cannot read $exampleFileName: $!\n";
    local $/ = undef;
    $exampleData = <$fh>;
}

my $obj2 = new Metamod::FimexProjections($exampleData, 1);
is ($obj2->getURLRegex, '!(.*/thredds).*dataset=(.*)!', "URLRegex");
is ($obj2->getURLReplace, '$1/fileServer/data/$2', "URLReplace");
is (scalar $obj2->listProjections, 2, "listProjections number");
ok (scalar grep {/Stereo/} $obj2->listProjections, "listProjections contains Stereo");
is ($obj2->getProjectionProperty("Stereo", "toDegree"), "false", "getProjectionProperty(Stereo,toDegree)");

my $wrongXML = <<'EOT';
<fimexProjections xmlns="http://www.met.no/schema/metamod/fimexProjections"
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                  xsi:schemaLocation="http://www.met.no/schema/metamod/fimexProjections https://wiki.met.no/_media/metamod/fimexProjections.xsd">
<dataset urlRege="!(.*/thredds).*dataset=(.*)!" urlReplace="$1/fileServer/data/$2"/>
</fimexProjections>
EOT

eval {my $obj3 = new Metamod::FimexProjections($wrongXML, 1);};
ok($@, "validation fails as expected");

