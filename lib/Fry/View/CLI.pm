package Fry::View::CLI;
use strict;

our ($o); 
sub setup {$o = $_[1]}
sub view ($@) { 
	my ($cls,@data) = @_;
	no strict 'refs'; 
	print { $o->Var('fh') } "@data" ;
}
sub list ($@) {
	my ($cls,@lines) = @_;
	my ($i,$output);

	for (@lines) {
		$i++;
		$output .=  "$i: " ; #if ($class->_flag->{menu});
		$output .=  "$_\n";	
	}
	$o->view($output);
}
sub hash ($\%\%) {
	my ($cls,$data,$opt) = @_;
	my $output;

	#while (my ($k,$v) = each %$data) {
	for my $k (($opt->{sort}) ? sort keys %$data : keys %$data) {
		$output .= "$k: ";
		#$v =~ s/^|$/'/g if ($opt->{quote});
		$data->{$k} =~ s/^/'/g if ($opt->{quote});
		$data->{$k} =~ s/$/'/g if ($opt->{quote});
		$output .= $data->{$k}."\n";
	}
	$o->view($output);
}
sub arrayOfArrays($@) {
	my ($cls,@data) = @_;
	my $output;
	for my $row (@data) {
		$output .= join($o->Var('field_delimiter'),@$row) . "\n";
	}
	$o->view($output);
}
sub objAoH ($@) {
	my ($cls,$data,$col) = @_;
	my $output;
	my $i;

	for my $row  (@$data) {
		if ($o->Flag('menu')) { $i++; $output .= "$i: "; }
		$output .= join ($o->Var('field_delimiter'),map {$row->$_} @$col) ."\n" ;
	}
	$o->view($output);
}
1;

__END__	

=head1 NAME

Fry::View::CLI - Default View plugin for Fry::Shell displaying to the commandline.

=head1 CLASS METHODS

	view(@): General view method called by all other view methods.	
	list(@): Displays an array one value per line. 
	hash(\%arg\%options): Displays a hashref, a key-value pair per line. Also takes
		an options hash which can be passed a quote flag to quote values.
	arrayofArrays(@): Displays an array of arrays with an array per line separated by the
		variable field_delimiter.


=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
