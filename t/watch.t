use Test::More   tests => 12;
#use Devel::StealthDebug SOURCE => '/tmp/source.txt';
use Devel::StealthDebug;
use File::Temp "tempfile";

close STDERR;
my ($fh,$fn)= tempfile() or die $!;
open (STDERR, "> $fn") or die $!;

my %testhash;#!watch(%testhash)!
my @testarray;#!watch(@testarray)!
my $testscalar;#!watch($testscalar)!
my $dummy;

$testhash{test1} = 1;
$testhash{test1}++;
$dummy = $testhash{test1} ;

$testarray[1] = 1;
$testarray[1]++;
$dummy = $testarray[1];

$testscalar = 1;
$testscalar++;
$dummy = $testscalar;

close STDERR;

open (STDIN,"< $fn");
$out=<STDIN>;
like($out , qr/STORE \(\%testhash{test1} \<\- 1\)/);
$out=<STDIN>;
like($out , qr/FETCH \(\%testhash{test1} -> 1\)/);
$out=<STDIN>;
like($out , qr/STORE \(\%testhash{test1} <- 2\)/);
$out=<STDIN>;
like($out , qr/FETCH \(\%testhash{test1} -> 2\)/);
$out=<STDIN>;
like($out , qr/STORE \(\@testarray\[1\] <- 1\)/);
$out=<STDIN>;
like($out , qr/FETCH \(\@testarray\[1\] -> 1\)/);
$out=<STDIN>;
like($out , qr/STORE \(\@testarray\[1\] <- 2\)/);
$out=<STDIN>;
like($out , qr/FETCH \(\@testarray\[1\] -> 2\)/);
$out=<STDIN>;
like($out , qr/STORE \(\$testscalar <- 1\)/);
$out=<STDIN>;
like($out , qr/FETCH \(\$testscalar -> 1\)/);
$out=<STDIN>;
like($out , qr/STORE \(\$testscalar <- 2\)/);
$out=<STDIN>;
like($out , qr/FETCH \(\$testscalar -> 2\)/);
close STDIN;
