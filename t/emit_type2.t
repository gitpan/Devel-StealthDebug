use Test::More   tests => 1;
use Devel::StealthDebug emit_type => '/tmp/mydebug';

my $foo;

eval {
	$foo = 42;#!emit(emit to file)!
	$foo++;
};
sleep 1;
open FIN,"</tmp/mydebug";
my @file = <FIN>;
close FIN;

my $file = join "",@file;

like($file,qr/emit to file/);
