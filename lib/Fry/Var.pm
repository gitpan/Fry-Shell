package Fry::Var;
use strict;
use base 'Fry::List';
use base 'Fry::Base';
my $list = {};

#sub _hash_default { return {qw/scope global/} }
sub list { return $list }

1;

__END__	

=head1 NAME

Fry::Var - Class for shell variables.

=head1 DESCRIPTION 

This module's objects store configuration data for the shell and its libraries. Since a shell's
configuration includes the current classes used for each shell component, Fry::Var is used often along
with Fry::Base to communicate between shell component classes. A Fry::Var object is the simplest of
shell component classes containg only id and value attributes. All values are scalar (ie
hashref or arrayref) since all var objects are stored in a hash.

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
