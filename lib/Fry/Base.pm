package Fry::Base;
use strict;
use base 'Fry::Error';
my ($varClass);

	sub _varClass {
		$varClass = $_[1] if (@_ > 1);
		return $varClass;
	}
	sub _shellClass { return $_[0]->_varClass->get('shell_class','value') }
	sub Var { return  $_[0]->_varClass->get($_[1], 'value') }
1;
__END__	

=head1 NAME

Fry::Base - Base class providing minimal set of handy methods and used to communicate between shell components.

=head1 DESCRIPTION 

This class provides a minimal set of handy methods made available to most Fry::* modules. Among these are &_varClass which contains the Variable class.
The Variable class facilitates communication between classes since it contains almost all of the shell's configuration information.
This class also inherits from Fry::Error and thus provides its error subs.

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
