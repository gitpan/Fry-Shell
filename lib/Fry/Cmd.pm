package Fry::Cmd;
use strict;
use base 'Fry::List';
use base 'Fry::Base';
my $list = {};

sub list { return $list }

	sub cmdChecks ($$@) {
		my ($cls,$cmd,@args) = @_;
		$cmd = $cls->anyAlias($cmd);
		if ($cls->objExists($cmd) && exists $cls->obj($cmd)->{req}) {
			my $module ="";
			for $module (@{$cls->obj($cmd)->{req}}) {
				eval "require $module";
				if ($@) {
					$cls->_shellClass->setFlag('skipcmd'=>1);
					#warning issue
					#$o->_warn("Required module $module not found. Skipping command\n").
					return ;
				}	
			}	
		}
	}
	sub argAlias ($$$) {
		my ($cls,$cmd,$args) = @_;
		if ($cls->objExists($cmd) && exists $cls->obj($cmd)->{aa}) { 
			@$args = $cls->obj($cmd)->{aa}->($cls->_shellClass->obj,@$args);
		}
	}	
	sub checkArgs ($$@) {
		my ($cls,$cmd,@args) = @_;

		#$cmd = $cls->anyAlias($cmd);
		if ($cls->objExists($cmd) && exists $cls->obj($cmd)->{arg}) {
			my @argtypes = (ref $cls->obj($cmd)->{arg} eq "ARRAY") ?
			@{$cls->obj($cmd)->{arg}} : $cls->obj($cmd)->{arg} ;
			for my $arg (@argtypes) {
				my ($datatype,$usertype) = split(//,$arg,2);
				#print "$datatype,$usertype\n";
				my $testsub = "t_$usertype";
				my @testarg;
				if ($datatype eq "\$") {@testarg = shift @args}
				elsif ($datatype eq "@") { @testarg = @args; }
				elsif ($datatype eq "%"){ @testarg = keys %{{@args}} }
				#elsif ($datatype eq "\$"

				if (! $cls->_shellClass->_obj->can($testsub)) {
					$cls->_shellClass->_obj->_warn("Testsub $testsub not found for user-defined type $usertype .\n")
				}	
				#test case defined
				else {
					if (! $cls->_shellClass->_obj->$testsub(@testarg)) {
						#$cls->_warn(join(' ',@testarg),": invalid $usertype type(s)\n");
						warn(join(' ',@testarg),": invalid $usertype type(s)\n");
						$cls->_shellClass->setFlag(skipcmd=>1);
						return 0
					}
				}
				return 1
				#$o->testArgType($datatype,$usertype,\@args);
			}
		}
	}
	sub runCmd ($$@){
		my ($cls,$cmd,@args) = @_;

		$cmd = $cls->anyAlias($cmd);
		#print "c: $cmd,a: @args\n";

		if ($cls->objExists($cmd) && exists $cls->obj($cmd)->{_sub}) {
			return $cls->obj($cmd)->{_sub}->(@args);
		}
		#autodetect
		#elsif ($cls->Var('cmd_class')->can($cmd)) { return $cls->Var('cmd_class')->$cmd(@args) }	
		elsif ($cls->_shellClass->_obj->can($cmd)) { return $cls->_shellClass->_obj->$cmd(@args) }	
		#else { return $o->loopDefault($cmd,@args); }
		else { return $cls->_shellClass->_obj->loopDefault($cmd,@args); }
	}
1;

__END__	

=head1 NAME

Fry::Cmd - Class for shell commands.

=head1 DESCRIPTION

A command object has the following attributes:

	Attributes with a '*' next to them are always defined.

	*id($): Unique id which is usually the name of subroutine associated with it.
	a($): Command alias.
	d($): Description help for command.
	u($): Usage help for command.
	*_sub(\&): Coderef which points to subroutine to execute when command is
		run. If not explicitly set,it's set to a default of 'sub {$o->$cmd(@_) }'
		where $cmd is the command's id.
	arg($): Use this attribute if you want to validate the command's
		arguments. Describe expected input type with a data structure symbol and
		name. See Argument Checking below.

=head1 Argument Checking

To validate your command's arguments you define an arg attribute. This attribute describes the
expected input with a symbol and a unique name for argument type. Currently valid symbols are $,%,@
to indicate scalar,hash and array data structures respectively.  An expected hash of a type means
that its keys must be of that type.  Each input type must have a test subroutine of the name t_$name
where $name is its name. Tests are called by the shell object. Tests that pass return a 1 and those
that fail return 0.

For example, lets look at the command printVarObj in Fry::Lib::Default. This command has an arg
value of '@var'. This means that the arguments are expected to be an array of type var. The var
type's test subroutine is &t_var and it is via this test that printVarObj's arguments will be
validated.

The arg attribute also offers the possibility to autocomplete a command's arguments
with the plugin Fry::ReadLine::Gnu. For autocompletion to work you must have a subroutine named
cmpl_$name where $name is the name of the user-defined type. The subroutine is called by the shell
object and should return a list of possible completion values. The autocompletion subroutine for
the previous subrouting would be cmpl_var.

You can turn off argument checking in the shell with the skiparg option.

=head1 CLASS METHODS

	cmdChecks($cmd,@args): Checks to run on command before executing it.
	checkArgs($cmd,@args): If args attribute is defined runs tests on user-defined arguments.
		If tests don't pass then warning is thrown and command is skipped.
	runCmd($cmd,@args): Runs command with given arguments. Checks for aliases.

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
