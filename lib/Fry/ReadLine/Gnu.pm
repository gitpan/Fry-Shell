package Fry::ReadLine::Gnu;
use Term::ReadLine;
use Term::ReadLine::Gnu;
use strict;
our ($term,$o);
sub setup {
	$o = $_[1];
	$term = Term::ReadLine::Gnu->new('fry');
	$term->Attribs->{completion_function} = sub { complete($o,@_)};
	#$term->add_defun('test',sub {print "bloh\n";},ord "\ct");
	#use Data::Dumper;
	#print Dumper $term->rl_get_keymap();
}
sub prompt {
	my ($class,$prompt) = @_;
	$o->view("\n");
	my $entry = $term->readline($prompt) || "";#|| $o->_die("term failed : $@");
	$term->addhistory($entry);
	return $entry;
}
sub complete {
	my ($o,$text,$line,$start,$end) = @_;

	#won't complete existing word unless given matches start w/ existing word
	#options
	if ($line =~ /-\w*$/) {
		return map {s/^/-/;$_} $o->listAll('opt');
	}
	#cmds that match return of previous cmd 
	#first cmd in chunk
	elsif (substr($line,0,$start) =~ /(^|\|)\s*$/) {
		return ($o->List('cmd'));
	}
	#args of cmd
	elsif ($line =~ /([^-]\w+)\s*/) {
		my $cmd = $1;
		$cmd = $o->findCmdAlias($cmd);
		if ($o->cmdObj($cmd) && exists $o->cmdObj($cmd)->{arg}) {
			#w: chopargtype
			my $argtype = substr($o->cmdObj($cmd)->{arg},1);
			#print "cmd: $cmd,$argtype\n";
			my $sub = "cmpl_$argtype";
			if ($o->can($sub)) { return $o->$sub }
			else { $o->_warn("No autocompletion defined for this command's
					arguments\n"); return }
		}
	}
	#filename autocompletion 
	return $term->Attribs->completion_matches($text,$term->Attribs->{filename_completion_function}); 
}
1;

__END__	

=head1 NAME

Fry::ReadLine::Gnu - ReadLine plugin for Fry::Shell which uses Term::ReadLine::Gnu.

=head1 DESCRIPTION 

Supports command history and autocompletion of options and commands. If a command has an arg
attribute and defines an autocompletion subroutine then a command's expected arguments can be
autocompleted. A completion subroutine must have the name cmpl_$arg where $arg is the name of
the arg attribute. If autocompletion is called and none of the above autocompletion cases are
detected then it defaults to autocompleting filenames. 

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
