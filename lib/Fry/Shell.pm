#!/usr/bin/perl
#declarations
	package Fry::Shell;
	use strict qw/vars subs/;
	#use warnings;
	use base 'Class::Data::Global';
	use Term::ReadLine;
	our $VERSION = '0.02';
	our @ISA;
	our ($term);my $mcount =0;
	my $debug = 0;
	#use Data::Dumper;
#basic methods
	sub _default_data {
		return {
			global=>{
				_conf_file=>$ENV{HOME}."/.shell.yaml",
				_parse_mode=>'n',
				_flag=>{},
				_fh=>'STDOUT',
				_alias_cmds=>{qw/h help \p perl_exe q quit/},
				_alias_vars=>{qw/p _parse_mode/},
				_alias_flags=>{qw/m menu/},
				_alias_subs=>{},
				_alias_parse=>{n=>'parse_normal', m=>'parse_menu'},
				_option_value=>{},
				prompt=>'Lame-o-prompt',
				lines=>[],
			}
		}
	}
	sub sh_init {
		my ($class,%config) = @_;
		my %arg;
		
		#load module's default data
		$class->load_class_data(__PACKAGE__);

		#process conf_file
		if (exists $config{conf_file}) {
			$class->_conf_file($config{conf_file});
			delete $config{conf_file}; 
		}	
		#loads shellwide config file
		$class->read_conf;

		#process load_libs option
		#create _conf if not found
		$class->check_or_mk_global(_conf=>{libs=>''});
		if (exists $config{load_libs}) {
			my @list;
			if (ref($config{load_libs}) eq "ARRAY") {
				@list = @{$config{load_libs}};
			}	
			elsif(not ref($config{load_libs})) {
				@list = $config{load_libs}
			}
			else {warn "load_libs not passed correct reference" }

			push(@{$class->_conf->{libs}},@list);
			delete $config{load_libs};
		}

		#loads libs,defines class data + config data 
		$class->load_libs;

		#td: load plugins

		#initialize global data
		$class->init_global;

		#init ReadLine
		$term =  Term::ReadLine->new('gdbi');

		if (exists $config{prompt}) {
			$class->prompt($config{prompt});
			delete $config{prompt}
		}	

		#load script data
		for (keys %config) {
			#keys:alias,option_value,_alias_parse,_alias_*
			#adjust option names to match accessor names
			my $accessor = (/^alias_|option_/) ? "_".$_ : $_;
			$class->add_to_hash($accessor,$config{$_});
		}

		#make global vars from option_value{vars}
		my %varhash = map {$_,'undef' } (values %{$class->_alias_vars});
		$class->check_or_mk_global(%varhash);

		#Load data from commandline
		#supports default option value setting
		$class->setoptions($class->_option_value);

	}
	sub main_loop {
		my $class = shift;
		my ($letter,@args);

		#initialize shell
		if (ref $_[0] eq "HASH") {
			$class->sh_init(%{shift()});
		}

		#start loop
		($letter,@args) = $class->once(@_);
		#while ($letter ne "q") {
		while ($class->_alias_cmds->{$letter} ne "quit") {
			($letter,@args) = $class->once;
		}
	}
	sub once {
		my $class= shift;
		my %alias = %{$class->_alias_cmds};
		my ($choice,@args);

		#input: if @_ defined, skips prompting
			my @answer = (@_) ? @_ : $class->input;

		#parse
			@answer = $class->check_for_options(@answer);
			#parse hash table
			my $currentparse = $class->_parse_mode;
			my $method = $class->_alias_parse->{$currentparse};
			if (defined $method) {
				($choice,@args) = $class->$method(@answer);
			}
			elsif ($class->can($currentparse)) {($choice,@args) = $class->$currentparse(@answer)}

		#execute choice
			if ($alias{$choice} eq "quit") { return $choice }
			elsif (exists $alias{$choice}) {
				$class->${\$alias{$choice}}(@args);
			} 
			elsif ($class->can($choice)) { $class->$choice(@args); }
			else { $class->loop_default($choice,@args) }

		$class->end_loop;

		#h:reset _parse_mode and associated flag
		$mcount++ if ($class->_parse_mode eq "m");
		if ($mcount > 1 && $class->_parse_mode eq "m") {
			$class->_parse_mode("n");
			$class->_flag->{menu}=0;
			$mcount = 0;
		}
		return ($choice,@args);
	}
	sub help {
		my $class= shift;
		while (my ($k,$v) = each %{$class->_alias_cmds}) {
			print {$class->_fh} "$k\t$v\n";
		}
	}
	sub perl_exe {
		my $class = shift;
		eval "@_";
	}
	#INTERNAL METHODS

	#for accessor hashes
	sub add_to_hash {
		my ($class,$accessor,%temphash) = (shift(),shift(),%{shift()});  
		while (my ($k,$v) = each %temphash){
			if (exists $class->$accessor->{$k}) {
				warn "in accessor $accessor: overriding ",$class->$accessor->{$k}," with $v\n"; 
			}	
			$class->$accessor->{$k}= $v,
		} 
	}
	sub debug ($) {
		print "@_" if ($debug);

	}	
	sub load_libs {
		my $class =shift;		
		for my $p (@{$class->_conf->{libs}}) {
			my $module = "GH::Shell::Lib::$p";


			#import module to call &_default_data
			eval "require $module"; die $@ if $@;
			#load dependencies first
			if ($module->can('_default_data') && exists ($module->_default_data->{depend})) {
				for (@{$module->_default_data->{depend}}) {
					my $fullname = "GH::Shell::Lib::$_";

					#load if not in path
					unless(grep(/^$fullname$/,@{$class."::ISA"}) > 0) {
						$class->load_lib("$fullname");
					}	
				}	
			}
			$class->load_lib($module);
			
		}
	}
	sub load_lib {
		my ($class,$module) = @_;

		$class->load_module($module);

		$class->load_class_data($module) if ($module->can('_default_data'));

		#set config data
		$class->read_lib_conf($module);
	}
	sub load_module {
		my ($class,$module) = @_;
		no strict 'refs';

		debug "loading lib $module\n";
		my $oldmodule = __PACKAGE__;
		eval "package $module; require $module; package $oldmodule";
		die $@ if $@;
		push(@{$class."::ISA"},$module);
	}	
	sub load_class_data {
		my ($class,$module) = @_;
		debug "load $module\'s class data\n";
		#class data
		$class->mk_many_global(%{$module->_default_data->{global}});
		$module->mk_many(%{$module->_default_data->{local}});

		#aliases
		#w: deref undef hash
		if (exists $module->_default_data->{alias}) {
			my %aliashash = %{$module->_default_data->{alias}};
			while (my ($k,$v) = each %aliashash) {
				$class->add_to_hash("_alias_$k",$v);
			} 
		}
	}
	sub read_lib_conf {
		my ($class,$module) =@_;
		no strict 'refs';

		#using YAML
		$module =~ /::(\w+)$/;
		if (-e $class->_conf->{conf_dir}.$1) {
			$class->setmany(%{YAML::LoadFile($class->_conf->{conf_dir}.$1)});
		}
	}
	sub read_conf {
		my $class = shift;
		#warn "config file ". $class->_conf_file. " doesn't exist", 
		return unless ( -e $class->_conf_file); 
		my %var;	

		eval {require YAML}; 
		#require file
		if ($@) {
			warn "Global config file currently depends on YAML. To change
			soon. $@\n";
		}
		else {
			%var = %{YAML::LoadFile($class->_conf_file)};
			$class->mk_cdata_global(_conf=>\%var);
		}

		if ($debug) {
			require Data::Dumper;
			print Dumper(\%var);
		}
	}
	sub parse_normal {
		shift; return @_;
	}
	sub parse_menu {
		#d: creates @cmd_beg,@entry and @save from @args
		my ($class,@args) = @_;
		my (@entry,@save,$i);
		my @cmd_beg = shift (@args);

		if ($args[0] ne "") {
			#push anything that isn't a num choice to @cmd_beg
			while (($args[$i] !~ /\b\d+\b/) && ($args[$i] !~ /\b\d+-\d+,?/) && @args > 0) {
				push (@cmd_beg, shift(@args));
			}
		}
		#@entry-contains num choices
			while (($args[$i] =~ /\b\d+\b/) || ($args[$i] =~ /\d-\d,?/)) {
				push(@entry,$args[$i]);
				shift(@args);
				$i++;
			}

		#save chosen lines of @lines into @save
		foreach (@entry) { @save = $class->parse_num($_,@{$class->lines})}

		if (@args > 0) { return (@cmd_beg,@save,@args);	}
		else {return (@cmd_beg,@save,@args); }
	}
	sub input {
		my $class = shift;
		my $prompt = ($class->_flag->{menu}) ? "[menu] ". $class->prompt : $class->prompt; 
		#w/o rl
		#print "\n",$class->prompt;
		#my $entry = <STDIN>  or die "what the heck! no entry?";

		print "\n";
		my $entry = $term->readline($prompt) || die "term failed : $@";
		$term->addhistory($entry);
		chomp(my @args = split(/ /,$entry));
		return @args;
	}
	sub check_for_options {
		my $class = shift;
		my ($optref,@command) = $class->parse_options(@_);

		$class->setoptions($optref);

		#f: renable to change tb+col,disabled due to some errors
		#redefine db connection based on new param
		#$class->setdb;

		#split @command on whitespace to make up for an incorrectly made
		#@command
		return split(/ /,"@command");
	}
	sub parse_options {
		#d: sets %opt as if it were a regular %o from commandline
		my $class =shift;
		my %opt;

		#split just in case input is scalar
		@_ = split(/ /,"@_");

		while ($_[0] =~ /^-\w/) {

			#shift off '-'
			my $option = substr($_[0],1);

			#variables and subs + flag = 0
			if ($option =~ /=/) {
				my ($key,$value) = split(/=/,$option); $opt{$key} = $value;
			}
			#flags
			else { $opt{$option} =1 }

			shift;
		} 
		return (\%opt,@_);
	}
	sub setoptions {
		my ($class,$option_value) = @_;
		my (%arg);
		if ($debug) { print Dumper $option_value};

		while (my ($k,$v) = each %$option_value){
			my $key_count=0;

			if (exists $class->_alias_vars->{$k}) {
			 	my $varname = $class->_alias_vars->{$k};
				$class->$varname($v); 
				$key_count++;
			}
			if (exists $class->_alias_flags->{$k}) {
				my $flagname = $class->_alias_flags->{$k};
				$class->_flag->{$flagname} = $v;
				$key_count++;
			}
			if (exists $class->_alias_subs->{$k}) {
				my $subname = $class->_alias_subs->{$k};
				$class->$subname($v);
				$key_count++;
			}

			if ($key_count > 1) { warn "option $k was set $key_count times" }
				
		}

		#default rules equating the parse mode parse_menu with the flag 'm'
		if ($class->_flag->{menu}) {$class->_parse_mode("m")}
		$class->_flag->{menu} = 1 if ($class->_parse_mode eq "m");
		$class->set_rules;
	}
	sub parse_num {
		my $class = shift;
		my @save;my $e;my $count; 
		my ($entry,@choose) = (@_);

		my @entries = split(/,/,$entry);
		foreach $e (@entries) {
			if ($e =~ /-/) {
				my ($min,$max) = split("-",$e);
				for( $a = $min;$a <= $max;$a++) {
					$save[$count]=$choose[$a-1];  #note that -1 is there for the offset b/n the arrays
					$count++;
				}
			}
			else { $save[$count]=$choose[$e-1]; $count++;} #note that -1 is there for the offset b/n the arrays
		}
		return @save;
	}
	#redefinable
	sub set_rules { }
	sub init_global { }
	sub loop_default {
		my $class = shift;
		 print {$class->_fh} "Yo buddy, your command: '",join(' ',@_),"' isn't valid.\n"; 
	}
	sub end_loop {
	}
1;

__END__	

=head1 NAME

name - Fry::Shell

=head1 Basic Example

	package MyShell;
	use base 'Fry::Shell';

	#set shell prompt
	my $prompt = "Clever prompt: ";

	#this hash maps aliases to shell commands which call class methods
	my %alias = (qw/e echo/);

	MyShell->sh_init(prompt=>$prompt,alias_cmds=>\%alias);

	#function definitions 
	sub echo {
		my $class = shift;
		print "Nah! @_\n";
	}

	#begin shell loop
	MyShell->main_loop(@ARGV);

=head1 DESCRIPTION 

Fry::Shell is a simple and flexible way of creating a commandline application for a group of
functions. Unlike other light-weight commandline applications (or shells), this module supports
auto loading libraries of functions and thus encourages creating shells tailored to a module. This
module comes with a couple of libraries centered around Class::DBI.

The module's simplicity is in the set up.  First inherit the module's functions
with' use base'. Then call two methods, &sh_init to customize
the application and either &main_loop (for a shell app) or &once (for a
command app) to start it.

The flexible aspect comes from all internal and user-defined functions being class methods and
global data being accessors. This means that it is quite easy to subclass and redefine the behavior
and data of the shell.  Also it is possible to define your own parsing mode simply by setting an
option at the commandline (ie '-p=a $command').

=head1 Setup

There are two types of applications you can define, command and shell. A command application is run at the
normal shell prompt once and exits. To set one up you could do:

	__PACKAGE__->sh_init(prompt=>$prompt,alias_cmds=>\%alias);
	__PACKAGE__->once(@ARGV);

A shell application creates its own shell environment and runs until explicitly exited.
Usually, you combine this with a command application and do:

	__PACKAGE__->sh_init(prompt=>$prompt,alias_cmds=>\%alias);
	__PACKAGE__->main_loop(@ARGV);

=head1 Using the Shell	

Assuming you've set up the basic example above, what can you do in your shell?
By default you have three shell commands always available: &help,&perl_exe and &quit.  They also
have default aliases of 'h','\p' and 'q' which you can redefine. Naturally &quit exits the shell.
&help lists available shell commands and their aliases. &perl_exe executes given perl code. This is
a handy way of loading libraries and setting class data if no other way exists. 

To create your own shell commands you should define methods in your script's
namespace. Since shell functions are called as methods, the first argument must
always be shifted as shown above. For class methods, the first argument is the
class as shown above.  The remainder and perhaps a good part of shell commands
you'll use will come from libraries.

=head1 Public Class Methods
	
	sh_init()
	sh_init(%parameters)
		Note: all the parameters are optional.

		To see the default values for any of these options look at
		&_default_data in this module.

		__PACKAGE__->sh_init(prompt=>$prompt,alias_cmds=>\%alias_cmds);

		prompt($): shell prompt for a shell application

		alias_cmds(\%)
			hashref of aliases to shell commands ie for an entry such
			as p=>print, typing 'p hello' in the shell would execute __PACKAGE__->print('hello')

		The next three parameters define aliases for options specified at the
		commandline. See the OPTIONS section below for more detail. 

		alias_vars(\%): maps letters to global variables
			%alias_vars=(qw/t tb d db D dbname/);
			t maps to $class->table

		alias_flags(\%): maps an option to the global hashref $class->_flag, used for
		flipping booleans

		alias_subs(\%): maps option to subref, an option's value is passed to the
		sub, usually used for setting variables

		option_value(\%): mapping the option letters to their commandline values,used
		only for a command application
			%option_value = (qw/b mozilla e vim/);

		alias_parse(\%): hashref mapping a parse letter to a parse function, you
			define new parse modes by adding an entry here.
			%alias_parse = (qw/q quickmode/);

		conf_file($): specifies a global configuration file

			This file contains a hashref of parameters that are read into the
			accessor &_conf . To specify a list of libraries to autoload,
			define them with the libs key.  
		
		load_libs($)	
		load_libs([@]): loads libraries in addition to ones specified in the global config
			file, the arguments are the module's package name minus "Fry::Shell::Lib"

			For example, to load the library module 'Fry::Shell::Lib::Handy' you
			pass 'Handy'.

	main_loop()
	main_loop(@input)
		__PACKAGE__->main_loop(@ARGV);

		This method starts the shell's main loop. If you pass it an @ than you're also
		enabling it as a command application.

	once()	
	once(@input)
		__PACKAGE__->once(@ARGV);

		This runs through one iteration of the loop. It consists of three main
		actions: getting the input,parsing it and executing it. If an argument
		isn't given then it will prompt for one.

=head1 Class Methods to Redefine

	You can redefine these in your application's namespace.

	end_loop: This subroutine executes at the end of every shell loop. Redefine it with
	anything you want done at the end of a loop. A good place to set class
	data to default values for every loop iteration.

		sub end_loop {
			my $class = shift;
			$class->save($really_important_info);
		}

	init_global: This subroutine executes at the beginning of &sh_init. Redefine it for any
	application initializations ie creating global data.

		sub init_global {
			my $class = shift;
			$class->setmany(dog=>'snoopy',cat=>'sylvester');
		}

	loop_default: This subroutine executes if no valid command is given. By default this sub
	returns an error message of invalid entry. It is passed	an array containg the command and
	its arguments.
		
		sub loop_default {
			my $class = shift;
			print "Hey bub, don't be trying none of that $_[0] around here.\n";
		}
	
	set_rules: This sub is called after commandline options are set but before
	the shell command is executed. If you want to equate the setting of a
	variable with a flag this would be the place. For example,if you had to
	type -v='painfully_long_name' wouldn't it be nice to simply type '-V'?

		sub set_rules {
			my  $class = shift; 
			if ($class->_flag->{menu}) {$class->_parse_mode("m")}
			#$class->_flag->{menu} = 1 if ($class->_parse_mode eq "m");
		}	

		This example is the default rules hardcoded before &set_rules is
		called. This rule associates sets the current parsing mode to 'm' if the flag
		menu is set. Thus on the commandline instead of setting the
		current parse mode with '-p=m' you can type an even shorter '-m' to
		set the menu flag. This example only saves you two typed letters (But
		it is an option I use often). 

=head1 Commandline Parsing and Parsing Modes

	By default, a commandline is parsed as follows:
		1. The whole commandline is passed to &parse_options which returns a
		hashref mapping options to values and an array of the  rest of the commandline.
		2.This hashref is used by &setoptions to set the options.
		3. The next white-space separated word is a method name or an alias of
		one.
		4. Now this is where parse modes come into play. The rest of the commandline,usually arguments to the above method, is
		parsed by an entry in the global hash table, &_alias_parse. The current
		parse mode's key or alias is saved in the &_parse_mode accessor. By default it's value is
		'n' which maps to &parse_normal. &parse_normal does nothing but return what it's given.

		The only other default parsing mode available is &parse_menu.
		&parse_menu substitutes any numbers of the form /\d+|\d+-\d+/ ie
		4,5-9 with elements from the &lines accessor (with the first element
		being one). A good way of using this is to print a
		a numbered menu of items to feed the next command
		and save the items to &lines. On the next loop iteration the numbers
		will be replaced with the chosen items and the transformed arguments
		will be fed to the current shell command.

		To make your own parse mode: 
			- define an entry in the &_alias_parse global hashref
			- make the class method you named as follows: it will receive the
			whole commandline and return a \% of options mapped to their
			values and a white-space split array containing the rest of the line

		See handyshell.pl under the samples directory to see &parse_menu in action.

=head1 OPTIONS

An option maps to the same variable,flag or function for both a command and shell
application. The difference between the two is in the option parsing.

For a command application, parsing is usually handled by a Getopt module.
I'd recommend the following:

	use Getopt::Long;
	Getopt::Long::Configure ("bundling");
	GetOptions(\%o,'t|table=s','d|db=s','D|dbname=s','O|opts=s');

Note that %o contains a hash of the options' values which you can pass as the
option_value parameter to &sh_init.

For a shell application, parsing is handled by &parse_options which recognizes anything starting with a '-'
as an option. To set a flag you simply give the option ie '-m'. To set a variable or
function, put a '=' and option value after the option ie'-b=mozilla'.

=head1 Global Data

All of Fry::Shell's class data is handled via accessors/mutators. It is
encouraged for most plugins and libraries to do the same. These accessors hold scalar values and thus you can
put a reference to any data type in them. For example:

	$uglysheep = $class->somearray->[1];
	#This accesses the 2nd element of the arrayref that somearray() contains.

See L<Class::Data::Global> for more information on manipulating class data.

To understand in what order class data is loaded into the module look at
&sh_init. Here is an overview of the stages:

	1. Fry::Shell's class data defaults are loaded with &load_class_data

	2. The user's class data defaults are loaded from &_conf_file

	3. Library modules' default class data is loaded with &load_class_data,
		followed by loading a user's custom config file for a library with &read_lib_conf.
		If a module has dependent library the dependency's data is loaded first. 

	4. Class data from the script is loaded using &add_to_hash.

	5. Class data from commandline options is loaded using &setoptions. 

=head1 Configuration files

A config file is one big hashref containing variable name and value pairs.
By default the global config file is serialized in YAML. If YAML can't be
loaded then it will resort to requiring the hashref $conf from the config
file.

=head1 Creating libraries of functions 
	
Fry::Shell encourages creating and sharing libraries of (hopefully useful) functions.
By having Fry::Shell handle basic shelling, shells around often-used modules
could grow more easily. 

Only your functions are needed for a library to work. However, if you want to
pass on any customization of your shell then you'll define &_default_data.
&_default_data returns a hash with any of the following keys:

	depend([@]): lists other libraries that this library depends on.
		Dependent modules and its class data are loaded before the library module. 
		Naturally you could load any dependent modules with 'use' or 'use
		base'. Loading it via this key changes the @ISA hierarachy from the
		application's perspective, placing base modules before dependent
		modules.

	global(\%): defines global class data

		global class data is visible to all modules in the shell

			sub nifty_do_dad {
				my $class = shift;
				print "I got this nifty thing they call a " . $class->do_dad;
			}	
				
	alias(\%): this specifies aliases you use with options, shell functions
	and parse modes ,you can have ony of the following as keys:
		
		cmds(\%): adds to the accessor  _alias_cmds
		subs(\%): " "  _alias_subs 
		vars(\%): " " _alias_vars
		flags(\%): " " _alias_flags
		parse(\%): " " _alias_parse

=head1 See also
	
	L<Class::Data::Global> for global class data questions.
	For similar light shells, see L<Term::Shell>,L<Shell::Base> and
	L<Term::GDBUI>.
	For big-mama shells look at L<Zoidberg> and L<PSh>.
	See the samples directory for sample scripts.

=head1 ToDo	

	Oh so much:
		allow global config file to be a normal perl data structure
		redesign to allow plugin architecture for loading data, readline, storing data  
		support libraries which have object methods, currently only class methods supported  
		better library plugin support
		store and display usage and summary help lines for shell commands
		autocompletion support

=head1 AUTHOR

Me. Gabriel that is. If you want to bug me with a bug: cldwalker@chwhat.com
If you like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.
