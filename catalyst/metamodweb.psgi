use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../common/lib";

use MetamodWeb;

my $app = MetamodWeb->apply_default_middlewares(MetamodWeb->psgi_app);
$app;

