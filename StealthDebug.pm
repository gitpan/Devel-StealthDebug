
package Devel::StealthDebug;

require Exporter;
@ISA=qw(Exporter);

@EXPORT=();					# put the public function here
@EXPORT_OK=();				# to unable a non-stealth interface


use strict;
use Carp;
use Filter::Simple;

our $SOURCE		= 0;
our $VERSION	= '1.001'; 	# Beware ! 1.1.2 sould be 1.001002 	
our $TABLEN		= 2;

our $Emit		= 'carp';
our $Counter	= 1;

my %Wait_Cond;

sub import {
	shift;

	while (my $imported = shift @_) {
		if ($imported eq 'SOURCE') {
			my $file = shift @_;
			open SOURCE,"> $file"; 
			$SOURCE = 1;
		}

		if ($imported eq 'emit_type') {
			$Emit = shift @_;
			if ($Emit =~ m:/:) {
				my $tfh;
				open($tfh,">>$Emit") or die $!;	# replace filename by filehandle.
				select($tfh);$|++;
				$Emit=$tfh;
			}
		}
	}
}

sub emit {
	if ($Emit eq 'carp') {	
		carp @_;
	} elsif ($Emit eq 'croak') {
		croak @_;
	} elsif ($Emit eq 'print') { 
		print @_;
	} elsif (ref $Emit =~ /CODE/) { 
		&$Emit(@_);
	} else {						# Otherwise it's a filehandle
		print $Emit @_;
	}
}

sub emit_type {
	my $orig = shift;
	my $emit = shift;

	if ($emit =~ /(carp|croak|print)/) {
		return "\$Devel::StealthDebug::Emit = $emit;$orig"
	}
}

sub add_assert {
	my $orig = shift;
	my $cond = my $cond2 = shift;

	$cond2   =~ s/\'/\\\'/g;
	return "die '($cond2) condition failed' if !($cond);$orig";
}

sub add_emit {
	my $orig = shift;
	my $text = shift;

	$text   =~ s/^"(.*)"$/$1/;
	$text   =~ s/\"/\\\"/g;
	return "Devel::StealthDebug::emit \"$text\";$orig";
}

sub add_dump  {
	my $orig = shift;
	my $ref  = shift;

	$Counter++;
	my $output;

	return "Devel::StealthDebug::emit Devel::StealthDebug::dumpvalue($ref,0);$orig";
}

sub dumpvalue {
	my $type 	= shift;
	my $tab		= shift;
	my $ref     = ref $type;

	if 			($type =~ /^($ref=)?HASH/) {
		return     dump_hash($type,$tab+$TABLEN,'');
	} elsif 	($type =~ /^($ref=)?ARRAY/) {
		return     dump_array($type,$tab+$TABLEN,'');
	} elsif 	($type =~ /^($ref=)?SCALAR/) {
		return     dump_scalar($type,$tab+$TABLEN,'');
	} else {
		return    dump_scalar($type,$tab+$TABLEN,'');
	}
}

sub dump_hash {
	my $var 	= shift;
	my $tabn 	= shift;
	my $output	= shift;
	
	my $tab 	 = " " x $tabn;
	$output		.= "$tab\n";
	$tab 		.= " ";

	for my $elem (keys %$var) {
		$output .= "$tab$elem => ";
		$output .= dumpvalue($var->{$elem},$tabn);
	}
	
	return $output;
}

sub dump_scalar {
	my $scalar 	= shift;
	my $tabn 	= shift;
	my $output	= shift;

	$output		.= "$scalar\n";
	
	return $output;
}

sub dump_array {
	my $var 	= shift;
	my $tabn 	= shift;
	my $output	= shift;
	
	my $i;

	my $tab 	 = " " x $tabn;
	$output 	.= "$tab\n";
	$tab		.= " ";

	for my $elem (@$var) {
		$output .= $tab;
		$output .= $i++;
		$output .= " => ";
		$output .= dumpvalue($elem,$tabn);
	}
	return $output;
}

sub add_when {
	my $orig    = shift;
	my $var		= shift;
	my $op  	= shift;
	my $value	= shift;

	push @{$Wait_Cond{$var}},[$op,$value];
	return "$orig";
}

sub add_watch {
	my $orig    = shift;
	my $comment = shift;
	my $var     = my $var2 = shift;

	$var2	    =~ s/[\$\@\%]//;

	if ($orig =~ m/(=|\+\+|--)/) {
		$orig =~ s/\s*my(\s*[\@\$\%]$var2)/$1/i;
	} else { 
		$orig = '' 
	}

	return "tie $var,'Devel::StealthDebug','$var';$orig$comment";
}

sub check_when_cond {
	my $object = shift;
	my $value  = shift;
	my $index  = shift;
 
	my $ok;
	for my $cond (@{$Wait_Cond{$object->{name}}}) {
		{
			local ($@, $!);
			$ok = eval "\$object->{value} $$cond[0] $$cond[1]";
		}
	
		if ($ok) {
				emit "$object->{name}$$cond[0]$$cond[1] !";
		}
	}
}

FILTER {
	#
	# Make it consistent and CLEAN !
	# (Of course if it could work...)
	#
	# Should we really forbid pure comment lines
	#
   	s/^(?!#)(.*?#.*?!assert\((.+?)\)!)/add_assert($1,$2)/meg;
 	s/^(?!#)(.*?)(#.*?!watch\((.+?)\)!)/add_watch($1,$2,$3)/meg;
 	s/^(?!#)(.*?)(#.*?!emit\((.+?)\)!)/add_emit($1,$3)/meg;
 	s/^(?!#)(.*?)(#.*?!dump\((.+?)\)!)/add_dump($1,$3)/meg;
 	s/^(?!#)(.*?(#.*?!when\((.+?),(.+?),(.+?)\)!))/add_when($1,$3,$4,$5)/meg;
 	s/^(?!#)(.*?(#.*?!emit_type\((.+?)\)!))/emit_type($1,$3)/meg;
	if ($SOURCE)	{ print SOURCE  "$_\n" }  ; 
	s/(.)/$1/mg;
}; 

sub TIESCALAR {
	my $class	= shift;
	my $name	= shift;
	my %object;

	$object{name}=$name;
	bless \%object,$class;
}

sub FETCH {
	my $object = shift;
	my $index  = shift;

	if ($object->{name} =~ /^\@/) {
		carp  "FETCH ($object->{name}\[$index\] -> ",$object->{value}[$index],")";
		return $object->{value}[$index];
	} elsif ($object->{name} =~ /^\$/) {
		carp  "FETCH ($object->{name} -> ",$object->{value},")";
		return $object->{value};
	} elsif ($object->{name} =~ /^\%/) {
		carp  "FETCH ($object->{name}\{$index\} -> ",$object->{value}{$index},")";
		return $object->{value}{$index};
	} else {
		carp  "Strange FETCH"
	}
}

sub FETCHSIZE {
	my $object = shift;
	my $value  = shift;

	$#{$object->{value}}=$value;
	carp  "FETCHSIZE ($object->{name})($value)";
}

sub STORE {
	my $object = shift;
	my $value  = pop;
	my $index  = shift;

	if ($object->{name} =~ /^\@/) {
		$object->{value}[$index]=$value;
		check_when_cond($object,$value,$index);
		carp "STORE ($object->{name}\[$index\] <- $object->{value}[$index])";
		return $object->{value}[$index];
	} elsif ($object->{name} =~ /^\$/) {
		$object->{value}=$value;
		check_when_cond($object,$value,$index);
		carp "STORE ($object->{name} <- $object->{value})";
		return $object->{value};
	} elsif ($object->{name} =~ /^\%/) {
		$object->{value}{$index}=$value;
		check_when_cond($object,$value,$index);
		carp "STORE ($object->{name}\{$index\} <- $object->{value}{$index})";
		return $object->{value}{$index};
	}
}

sub CLEAR {
	my $object = shift;
	
	$object->{value}=[];
	carp "CLEAR ($object->{name})";
}

sub TIEARRAY {
	my $class	= shift;
	my $name 	= shift;
	my %object;

	$object{name} = $name;
	$object{value}= [];
	bless \%object,$class;
}

sub TIEHASH {
	my $class	= shift;
	my $name 	= shift;
	my %object;

	$object{name} = $name;
	$object{value}= {};
	bless \%object,$class;
}

sub DELETE {
	my $object	= shift;
	my $key 	= shift;

	delete $object->{value}{$key};
	carp "DELETE ($object->{name})($key)";
}

sub EXISTS {
	my $object	= shift;
	my $key 	= shift;;

	carp "EXISTS ($object->{name})($key)";

	return 0	if $object->{value}{$key};
	return 1;
}

sub FIRSTKEY {
	my $object = shift;
	my $toreseteach = keys %{$object->{value}};

	$object->{lastkey} = each %{$object->{value}};
	carp "FIRSTKEY ($object->{name})(",$object->{lastkey},")";
	return $object->{lastkey}
}

sub NEXTKEY {
	my $object	= shift;
	my $key		= shift;
	my $lastkey = shift;

	carp "NEXTKEY ($object->{name})($key)($lastkey)";
	return each %{$object->{value}}
}

sub DESTROY {
	my $object = shift;

	carp "DESTROY ($object->{name})";
}


sub STORESIZE {
	my $object	= shift;
	my $count 	= shift;

	carp "STORESIZE ($object)($count)";
}

sub PUSH {
	my $object = shift;
	my @list   = @_;

	push @{$object->{value}},@list;
	carp "PUSH ($object)(@list)";
}

sub POP {
	my $object = shift;
	my $value = pop  @{$object->{value}};

	carp "POP ($object)($value)";
}

sub SHIFT {
	my $object = shift;
	my $value = shift  @{$object->{value}};

	carp "SHIFT ($object)($value)";
}

sub UNSHIFT {
	my $object  = shift;
	my @list	= @_;

	unshift  @{$object->{value}},@list;
	carp "SHIFT ($object)(@list)";
}

sub SPLICE {
	my $object	= shift;
	my $offset	= shift;
	my $length	= shift;
	my @list	= @_;

	return splice @{$object->{value}},$offset,$length,@list
}

sub EXTEND {
	my $object = shift;
	my $count  = shift;

	# Nothing to do ?
	carp "EXTEND (",$object->STORESIZE,")";
}

1;

__END__

=head1 NAME

Devel::StealthDebug - Simple non-intrusive debug module

=head1 SYNOPSIS

# in user's code:

Use Devel::StealthDebug;

... #!assert(<cond>)!

      will die at this line if <cond> is not verified...

... #!watch(<var_name>)!

      will carp each access to <var_name> 
      (Idea from Srinivasan's monitor module)

... #!emit(<double_quoted_string_to_be_printed>)!

      will 'emit' the string
	  Depending on emit_type it will print, carp, croak or add to a file

	  carp is the default value for emit_type
	  
... #!dump(<ref to a variable to be dumped>)!

      will emit the variable's structure

... #!when(<var_name>,<op>,<value>)!

      will emit when <var_name> will pass the condition described by 
	  <op><value>. Currently, only works for 'watched' scalar... 

... #!emit_type(carp|croak|print)!

      Define the emit's behaviour 

	  Can also be set on the use line :
	  use Devel::StealthDebug emit_type => 'croak';

	  Note if you set it this way you gain an additional feature : emit to file
	  use Devel::StelthDebug emit_type => '/path/to/file';

	  'carp' is the default value


=head1 ABSTRACT

This module will allow you to debug your code in a non-intrusive way.

=head1 DESCRIPTION

=head2 The Story

This module started as a joke called "Psychorigid.pm".
Following a discussion with a JAVA zealot (hi Gloom) I coded a short
module using Filter::Simple to show that strong type checking
and other missing features could be added easily to Perl thanks to filters.

The code posted on www.perlmonks.org produced insightful comments
(as always on perlmonks ! Go there it's a GREAT place for any Perl lover)
One of them was emphazing the fact that any feature making the debugging
easier is a good thing.
I then decided to play with Filter::simple to make a useful module.
I quickly coded a dirty module to do the job, which stood unused on my hardisk
for months.
I entually decided that It could be a good thing to release my first 
module, I did some clean-up, wrote some documentation and : voila !

=head2 Why another debug module ?

A simple search on CPAN will lead you to several other useful modules 
making debugging easier. (for example Carp::Assert)
Why did I decide to reinvent the wheel ? Especially when some of the already
existing wheel are well crafted. Simply beccause I wanted to explore a new
kind of interface.

I wanted a simple and I<non-intrusive> way to make the first stages of
coding easier and safer.
(By non-intrusive I mean without modyfing the code)

Ideally I wanted to switch-on (via 'use Debug;') a battery of checks
without modyfying my code, and then use it in production with only the
use line commented out. 

I could have used the usual embeded tests triggered by a variable
(usually $DEBUG)  but I didn't want to pollute the code logic with the 
debugging statements and I also wanted to play with the wonderful 
Filter::Simple module.

Furthermore I've tried to group (and when possible enhance) in this modules
several features dissiminated (or simply missing) in several modules.

=head1 AUTHOR

Arnaud (Arhuman) ASSAD <arhuman@hotmail.com>

=head1 COPYRIGHT

Copyright (c) 2001,2002 Arnaud ASSAD. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.
