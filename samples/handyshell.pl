#!/usr/bin/perl

package MyShell;
use base 'Fry::Shell';

##Config variables-these are all optional but I'm sure you'll want to make your own flavor
#set shell prompt
my $prompt = "handyshell: ";
#this is a hash of alias to actual function names
my %alias = (qw/e execute/);

#main
	__PACKAGE__->sh_init(prompt=>$prompt,alias_cmds=>\%alias);
	__PACKAGE__->main_loop(@ARGV);

#functions
	#Attention: this function executes whatever you give it as a system command
	sub execute {
		my $class = shift;
		#create menu items from system command
		chomp(my @lines = `@_`);

		#save these items to be chosen
		$class->lines(\@lines);
		#print out choices
		my $i;
		for (@lines) {
			$i++;
			print "$i: " if ($class->_parse_mode eq "m");
			print "$_\n";	
		}
	}
	sub cd {
		my $class =shift;
		chdir(@_);
	}
	sub loop_default {
		my $class = shift;
		#execute chosen menu items with given command
		system(@_);
	}


__END__	

=head1 NAME

handyshell.pl  - A handy shell which number aliases filenames

=head1 DESCRIPTION 

This script demonstrates the parse_menu mode of Fry::Shell.
The parse_menu mode associates a number with the previous command's output and converts
the given numbers

=head1 Try it
	
	1. Assuming that you're in a *nix environment, execute handyshell.pl to enter
		the shell.
	2. Type 'ls' (and Enter).  You should see the results of 'ls'. Since
		you didn't specify any of the predefined commands, the shell defaulted to
		executing &loop_default. This script redefines &loop_default by passing any
		commmand as a system call. Hence, typing 'ls' executes as in any regular shell.
	3. Type '\lc' or 'list_commands' to see a list of available commands and their aliases.	
	4. Perhaps you're unsure of how to use &print_global_data. You can type 'h print_global_data' or 'help_usage
	print_global_data' to get a usage regular expression on that command.
	5. Type '-m e ls'. You should see a numbered output of 'ls' with one file per row. This numbered list is a menu 
		of files. You can now execute a command on these files by number.

			The '-m' is a flag telling the shell to associate the output of this command with numbers for
			the next command cycle. The 'e' is an alias for 'execute'. &execute does two main
			things: it correctly numbers the output and saves the output to the
			&lines accessor.
	6. Now, the cool part. Type 'ls' followed by a list of numbers to act on
		(ie ls 1-3,6). Use a comma to delimit the list and a '-' to specify a range of
		numbers.  You should have listed only the specified files.
	
=head1 Uses

	This parsing mode is handy for dealing with a group of files that have a few exceptions. Yes, you can
	deal with these exceptions via regular expressions and auto-completion but
	not always painlessly for your fingers.
	Some uses I've put this handyshell to are:
		deleting several files from a directory (I do this when weeding out new mp3s)
		moving around several files (on new mp3s of course)
		using 'find' or 'slocate' to create the menu and then scp over files

=head1 AUTHOR

Me. Gabriel that is. If you want to bug me with a bug: cldwalker@chwhat.com
If you like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.
