package Fry::Error;
use strict;
use Fry::Base;
#use Carp;
	sub _warn ($@) {
		my $o = shift;		
		no strict 'refs';
		my $sub = Fry::Base->Var('warnsub');
		if ($sub eq "warn") { warn(@_); }
		else {	&{$sub}(@_); }
	}	
	sub _require ($$$) {
		my %opt =  (ref $_[-1] eq "HASH") ? %{pop @_} : ();
		my $errorsub = ($opt{warn}) ? "_warn" : "_die";
		my $cls = ref $_[0] || $_[0]; shift;
		my $class = shift;
		my $message = shift || "";
		eval "require $class"; $cls->$errorsub("$message $@") if ($@);
	}
	sub _die ($@) {
		my $o = shift;		
		no strict 'refs';
		my $sub = Fry::Base->Var('diesub');
		if ($sub eq "die") { die(@_) }
		else { &{$sub}(@_) }
	}
1;
__END__	

=head1 NAME

Fry::Error - Provides warn and die methods used by Fry::* classes.

=head1 DESCRIPTION 

This class simply provides provides centralized error throwing for Fry::* classes.
Currently all core Fry::* classes inherit from this class. Both the &_warn and &_die
methods are configured from Fry::Shell.

=head1 CLASS METHODS

_die(@message): dies via shell-configurable variable 'diesub'
_warn(@message): warns via shell-configurable variable 'warnsub'
_require($class,$message,\%opt): Requires class or else fails. By default it fails via &_die. It can
be configured to fail via &_warn by passing the hash {warn=>1} as a last argument.

=head1 TODO

Since both error-throwing methods are configurable, this class seems like it should be a plugin.
However, I'm considering implementing a more thorough class which supports levels
of debugging and error handling, similar to Log::Log4perl. I aim to keep the user-configurable warn
and die subs while providing levels of error throwing.

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
