package Fry::Lib;
use strict;
use base 'Fry::List';
use base 'Fry::Base';
my $list = {};

sub list { return $list }
#shell interface
	sub runLibInits ($@) {
		my ($cls,@lib) = @_;

		for my $l (@lib) {
			$cls->_require($l);
			my $sub = "$l\::_initLib";
			$cls->_shellClass->_obj->$sub() if ($l->can('_initLib'));
			#$l->_initLib($cls->_shellClass->_obj) if ($l->can('_initLib'));
		}
	}
	sub fullName {
		my($cls,@libs) = @_;
		return map {
			#$cls->_die("Fry::Lib is the root path and should not be specified in short lib names") 
			#if (/^Fry::Lib/);
			s/^/Fry::Lib:/ if (/^:/);
		       	$_ } @libs
	}
1;

__END__	

=head1 NAME

Fry::Lib - Class for shell libraries. 

=head1 DESCRIPTION 

A Fry::Lib object has the following attributes:

	Attributes with a '*' next to them are always defined.

	*id($): Unique id which is full name of module.
	*vars(\@): Contains ids of variables in its library.
	*opts(\@): Contains ids of options in its library.
	*cmds(\@): Contains ids of commmands in its library.
	class($): Class autoloaded by library.
	depend(\@): Modules which library depends on.

=head1 CLASS METHODS

	runLibInits(@libs): Calls &_initLib of libraries if they exist.
	fullName(@libs): Converts aliased libraries that begin with ':' to their full path in Fry::Lib.

=head1 SEE ALSO

	Libraries section of Fry::Shell.

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
