use Test;
use Benchmark;
use Mail::POPRelay;
use Mail::POPRelay::Daemon;
use strict;

BEGIN { print "( Testing )\n";plan tests => 5 }

my $begin = new Benchmark;

ok(1);

my $rc;
$rc = system("perl -Iblib/lib -c bin/poprelay_cleanup 2> /dev/null");
ok(!$rc);

$rc = system("perl -Iblib/lib -c bin/poprelay_ipop3d 2> /dev/null");
ok(!$rc);

$rc = system("perl -Iblib/lib -c bin/poprelay_vpopd 2> /dev/null");
ok(!$rc);


print "Aligning to lunar nachos ";
foreach (1..4) {
	sleep(1);
	print '.';
};
ok(1);
print "Right ascension of lunar nachos is at ", scalar localtime time, ", success!\n";

my $end = new Benchmark;
print timestr(timediff($end, $begin)), "\n";

# $Id: test.pl,v 1.4 2002/02/13 04:18:49 keith Exp $
