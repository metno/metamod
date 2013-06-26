use strict;
use warnings;

use MetamodWeb;

my $app = MetamodWeb->apply_default_middlewares(MetamodWeb->psgi_app);
$app;

