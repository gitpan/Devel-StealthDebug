use Test::More   tests => 2;
use File::Temp "tempfile";
use Devel::StealthDebug emit_type=>'print';

close STDOUT;
my ($fh,$fn) = tempfile() or die $!;
open (STDOUT, "> $fn") or die $!;

#my $sentinel = "emit should'nt execute(commented line)"; #!emit(print ko)!
my $donothing = 'whatever'; #!emit(print ok)!
my $guru = 'Tilly'; #!emit(thanks $guru)!
close STDOUT;

open (STDIN,"< $fn");
my $out	= <STDIN>;
close STDIN;

like($out, qr/print ok/);
like($out, qr/thanks Tilly/);
