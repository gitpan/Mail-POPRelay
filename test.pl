use Test;
use Mail::POPRelay;
use Mail::POPRelay::Daemon;
use strict;

BEGIN { plan tests => 4 }

print "Ahhem; please excuse this lazily created testing facility ...\n";
print "Nachos anyone?\n";

ok(1);

my $rc;
$rc = system("perl -Iblib/lib -c bin/poprelay_cleanup 2> /dev/null");
ok(!$rc);

$rc = system("perl -Iblib/lib -c bin/poprelay_ipop3d 2> /dev/null");
ok(!$rc);

$rc = system("perl -Iblib/lib -c bin/poprelay_vpopd 2> /dev/null");
ok(!$rc);

# $Id: test.pl,v 1.2 2001/11/20 21:33:59 keith Exp $
