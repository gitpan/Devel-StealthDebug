use Test::More   tests => 9;
use File::Temp "tempfile";
use Devel::StealthDebug emit_type => 'print';

close STDOUT;
my ($fh,$fn)= tempfile() or die $!;
open (STDOUT, "> $fn") or die $!;

my %var;
$var{scalar}=3;
$var{array}=[1,2,3];
$var{hash}={a=>'b',b=>'c',c=>'d'};

my $donothing='whatever'; #!dump(\%var)!;
close STDOUT;
open (STDIN,"< $fn");
my $out	=<STDIN>;
$out	=<STDIN>;
like($out , qr/   array =>/);  
$out	=<STDIN>;
like($out , qr/     0 => 1/);
$out	=<STDIN>;
like($out , qr/     1 => 2/);
$out	=<STDIN>;
like($out , qr/     2 => 3/);
$out	=<STDIN>;
like($out , qr/   hash =>/);     
$out	=<STDIN>;
like($out , qr/     a => b/);
$out	=<STDIN>;
like($out , qr/     b => c/);
$out	=<STDIN>;
like($out , qr/     c => d/);
$out	=<STDIN>;
like($out , qr/   scalar => 3/);
close STDIN;
