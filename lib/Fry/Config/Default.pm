package Fry::Config::Default;
	sub read {
		my ($class,$file) = @_;
		our $conf = {};
		do $file;
		return $conf;
	}
1;

__END__	

=head1 NAME

Fry::Config::Default - Default Config plugin for Fry::Shell.

=head1 CLASS METHODS

read($file): Requires the variable $conf from the specified file.
A valid config file could be :

	$conf =  {
		vars=>{
			prompt=>'Have you read your prompt lately?:',
			pager=>'more'
		}
	};

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
