#!/usr/bin/perl
#declarations
	package Fry::Shell;
	use strict qw/vars subs/;
	use warnings;
	use base 'Class::Data::Global';
	use Term::ReadLine;
	our $VERSION = '0.08';
	our @ISA;
	our ($term);
	my $mcount =0;
	my $debug = 1;
	eval { require Data::Dumper};
	$Data::Dumper::Indent = 0;
	$Data::Dumper::Purity = 1;


	sub _default_data {
		return {
			global=>{
				_conf_file=>$ENV{HOME}."/.shell.yaml",
				_parse_mode=>'n',
				_flag=>{},
				_fh=>'STDOUT',
				_alias_cmds=>{qw/h help_usage \p perl_exe q quit \ld list_global_data
				       \pd print_global_data \sd set_global_data \lo list_options
					   \lc list_commands \h help_description/},
				_alias_vars=>{qw/p _parse_mode/},
				_alias_flags=>{qw/m menu/},
				_alias_subs=>{},
				_alias_parse=>{n=>'parse_normal', m=>'parse_menu'},
				_option_value=>{},
				prompt=>'Lame-o-prompt',
				lines=>[],
				help_data=>{},
			},
			help=>{ 
				help_usage=>{d=>'Prints usage of function(s)',u=>'<@commands>'},
				help_description=>
					{d=>'Prints brief description of function(s)',u=>'<@commands>'},
				perl_exe=>
					{d=>'Executes arguments as perl code with eval',u=>'$perl_code'},
				list_options=>,
					{d=>'Lists loaded options and their aliases',u=>''},
				list_commands=>
					{d=>'Lists loaded commands and their aliases',u=>''} ,
				set_global_data=>
					{ d=>'Set a global data accessor equal to any data structure since it is evaled',
					u=>'$accessor $data_structure'},
				print_global_data=> 
					{ d=>'Print global data accessors and their values',
					u=>'@global_data'},
				list_global_data=>
					{d=>'List global data accessors',u=>''}
			}
		}
	}
#public methods
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

		#init ReadLine
		$term =  Term::ReadLine->new('gdbi');

		$class->load_script_data(%config);

		#load option data

			#make global vars from option_value{vars}
			my %varhash = map {$_,'undef' } (values %{$class->_alias_vars});
			$class->check_or_mk_global(%varhash);

			#Load data from commandline
			#supports default option value setting
			$class->setoptions($class->_option_value);

		#td: default library initializations after all data set
		$class->default_lib_actions;
	}
	sub load_script_data {
		my ($class,%config) = @_;

		if (exists $config{prompt}) {
			$class->prompt($config{prompt});
			delete $config{prompt}
		}	

		if (exists $config{global}) {
			$class->set_or_mk_global(%{$config{global}});
			delete $config{global};
		}	

		if (exists $config{help}) {
			$class->add_to_hash('help_data',$config{help});
			delete $config{help}
		}

		#load script data
		for (keys %config) {
			#keys:alias,option_value,_alias_parse,_alias_*
			#adjust option names to match accessor names
			my $accessor = (/^alias_|option_/) ? "_".$_ : $_;
			$class->add_to_hash($accessor,$config{$_});
		}
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
			if (($alias{$choice} or '') eq "quit") { return $choice }
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
#shell functions	
	sub help_usage {
		my $class = shift;
		my @functions;

		#?: defined wouldn't would work
		if (@_ == 0) {
			@functions = sort keys %{$class->help_data}
		}	
		else { @functions = @_}

		print "Note: wrap <> around optional chunks\n\n";

		for (@functions) {
			my $usage = (exists $class->help_data->{$_}->{u}) 
			? $class->help_data->{$_}->{u} : "*none defined*" ;	
		       print "$_ $usage\n"; 
		}	

		@functions = undef;
	}
	sub help_description {
		my ($class,@functions) = @_;

		if (@functions == 0) {
			@functions = sort keys %{$class->help_data}
		}	

		for (@functions) {
			my $description = (exists $class->help_data->{$_}->{d}) 
			? $class->help_data->{$_}->{d} : "*none defined*" ;	
			print "$_ : $description\n",
		}	
	}
	sub perl_exe {
		my $class = shift;
		eval "@_";
	}
	sub list_commands{
		shift->list_hash("cmds");
	}
	sub list_options {
		shift->list_hash("options");
	}
	sub set_global_data {
		my $class = shift;
		my $accessor = shift;
		eval "$class->$accessor(@_)";
	}	
	sub print_global_data {
		my $class = shift;

		eval {require Data::Dumper};
		if ($@) { warn "Data::Dumper needed for this function";return}

		my @data = (not defined $_[0]) ? sort @$Class::Data::Global::names :
		@_; 
		for (@data) {
			print Data::Dumper->Dump([$class->$_],[$_]);
			print "\n";
		}
	}
	sub list_global_data {
		my $class = shift;
		my $i;
		my @sortednames = sort @$Class::Data::Global::names;
		for  (@sortednames) {
			$i++;
			print "$i: $_\n";
		}	
		$class->lines(\@sortednames) if ($class->_flag->{menu});
	}	

	#INTERNAL METHODS

	#for accessor hashes
	sub add_to_hash {
		my ($class,$accessor,$hashref) = @_;
		my %temphash = (defined $hashref) ? %$hashref : ();

		while (my ($k,$v) = each %temphash){
			if (exists $class->$accessor->{$k}) {
				warn "in accessor $accessor: overriding ",$class->$accessor->{$k}," with $v\n"; 
			}	
			$class->$accessor->{$k}= $v,
		} 
	}
	sub list_hash {
		my ($class,$hashname) = @_;

		my %flathash = (options=>
			{%{$class->_alias_vars},%{$class->_alias_subs}, %{$class->_alias_flags}},
			cmds=>$class->_alias_cmds);

		for my $k (sort keys %{$flathash{$hashname}}) {
			print "$k\t",$flathash{$hashname}{$k},"\n";
		}	
	}	
	sub debug ($) {
		print "@_" if ($debug);

	}	
	sub load_libs {
		my $class =shift;		

		for my $p (@{$class->_conf->{libs}}) {

			die  "Fry::Lib is the root path and should not be specified in libs" if ($p
				=~ /Fry::Lib/i);
			my $module = "Fry::Lib::$p";

			#import module to call &_default_data
			eval "require $module"; die $@ if $@;

			#td: should change to hard coded method so loaded modules don't get
			#initialized more than once
			#load dependencies first
			if ($module->can('_default_data') && exists ($module->_default_data->{depend})) {
				for (@{$module->_default_data->{depend}}) {
					my $fullname = "Fry::Lib::$_";

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
		$class->check_or_mk_global(%{$module->_default_data->{global}});
		$class->add_to_hash(help_data=>$module->_default_data->{help});
		#$module->mk_many(%{$module->_default_data->{local}});

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
			%var = %{YAML::LoadFile($class->_conf_file) || {}};
			$class->mk_cdata_global(_conf=>\%var);
		}

		if ($debug) {
			require Data::Dumper;
			print Data::Dumper::Dumper(\%var),"\n";
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
		#td: fix uninitialized warning
		no warnings;

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
		if ($debug) { print Data::Dumper::Dumper($option_value),"\n"};

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
		#td: fix unitialized warning
		no warnings;

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
	sub default_lib_actions {
		my $class = shift;

		#td: only calls function for given module,don't climb @ISA
		for my $module (@{$class."::ISA"}) { 
			$module->_init_lib if ($module->can('_init_lib'));

		}	
	}
	sub set_rules { }
	sub loop_default {
		my $class = shift;
		 print {$class->_fh} "Yo buddy, your command: '",join(' ',@_),"' isn't valid.\n"; 
	}
	sub end_loop {
	}
1;

__END__	

=head1 NAME

Fry::Shell - Create commandline application with plugin libraries.

=head1 Basic Example

	package MyShell;
	use base 'Fry::Shell';

	#set shell prompt
	my $prompt = "Clever prompt: ";

	#this hash maps aliases to shell commands which call class methods
	my %alias = (qw/e echo/);

	MyShell->sh_init(prompt=>$prompt,alias_cmds=>\%alias);

	#begin shell loop
	MyShell->main_loop(@ARGV);

	#function definitions 
	sub echo {
		my $class = shift;
		print "Nah! @_\n";
	}

=head1 VERSION	

This document describes version 0.08.

=head1 DESCRIPTION 

Fry::Shell is a simple and flexible way of creating a commandline application for a group of
functions. Unlike other light-weight commandline applications (or shells), this module supports
auto loading libraries of functions and thus encourages creating shells tailored to a module.

The module's simplicity is in the set up.  First inherit this module's functions
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
By default you have nine shell commands always available: three which perform
action on global data (&set_global_data,&print_global_data,&list_global_data),
four which provide help (&help_usage, &help_description,&list_options,
&list_commands), &perl_exe which executes given perl code and &quit.
See handyshell.pl under samples directory for a tutorial on using them.

To create your own shell commands you should define methods in your script's
namespace. Since shell functions are called as methods, the first argument must
always be shifted as shown above. For class methods, the first argument is the
class as shown above.  The remainder and perhaps a good part of shell commands
you'll use will come from libraries.

=head1 Public Class Methods

=over 4	

=item B<sh_init()>

=item B<sh_init(%parameters)>

	__PACKAGE__->sh_init(prompt=>$prompt,alias_cmds=>\%alias_cmds);

Note: all the parameters are optional.
The default values for these paramters is in 
&_default_data. Here they are:

=over 4

=item B<prompt($)>: shell prompt for a shell application

=item B<alias_cmds(\%)>: hashref of aliases to shell commands 

Ie for an entry such as p=>print, typing 'p hello' in the shell would execute
__PACKAGE__->print('hello')

=item The next three parameters define aliases for options specified at the
commandline. See the OPTIONS section below for more detail. 

=item B<alias_vars(\%)>: maps letters to global variables

	%alias_vars=(qw/t tb d db D dbname/);
	t maps to $class->table

=item B<alias_flags(\%)>: maps an option to the global hashref $class->_flag, used for
flipping booleans

=item B<alias_subs(\%)>: maps option to subref, an option's value is passed to the
sub, usually used for setting variables


=item B<option_value(\%)>: mapping the option letters to their commandline values,used
only for a command application

	%option_value = (qw/b mozilla e vim/);

=item B<alias_parse(\%)>: hashref mapping a parse letter to a parse function, you
define new parse modes by adding an entry here.  

	%alias_parse = (qw/q quickmode/);

=item B<conf_file($)>: specifies a global configuration file

This file contains a hashref of parameters that are read into the
accessor &_conf . To specify a list of libraries to autoload,
define them with the libs key.  
		
=item B<load_libs($)>

=item B<load_libs([@])>: loads libraries in addition to ones specified in the global config
	file, the arguments are the module's package name minus "Fry::Lib"

	For example, to load the library module 'Fry::Lib::Handy' you
	pass 'Handy'.

=item B<help(\%)>: defines help for shell functions to be used by &help_usage
and &help_description

	help=>{ 
		help_usage=>{d=>'Prints usage of function(s)',u=>'[@commands]'},
	}	

The keys of this hashref are the names of the functions. Each function takes
a hashref with keys 'd' and 'u' for description and usage help respectively. 
Usage is given as perl regular expressions by default. For readibility, optional
chunks can be wrapped in '< >'

=item B<global(\%)>: sets given global data accessors,useful when defining
script level data for a library 

	global=>{db=>'postgres',dbname=>'template1'}

=back	

=item B<main_loop()>

=item B< main_loop(@input)>

This method starts the shell's main loop. If you pass it an @ than you're also
enabling it as a command application.

	__PACKAGE__->main_loop(@ARGV);

=item B<once()>

=item B<once(@input)>

This runs through one iteration of the loop. It consists of three main
actions: getting the input,parsing it and executing it. If an argument
isn't given then it will prompt for one.

	__PACKAGE__->once(@ARGV);

=back	

=head1 Default Shell Functiosn

These are default shell functions which deal mainly with the shell and its configurations.

=over 4

=item B<help_usage(@commands)>: Prints usage of shell function(s), if no argument given
prints usage of all functions

=item B<help_description(@commands)>: Prints brief description of function(s), if no argument
given prints all descriptions 

=item B<perl_exe($perl_code)>: Executes arguments as perl code with eval

=item B<list_options()>: Lists loaded options and their aliases

=item B<list_commands()>: Lists loaded commands and their aliases

=item B<set_global_data($accessor $data_structure)>: Set a global data accessor equal to any data structure since it is evaled

=item B<print_global_data(@global_data)>: Print global data accessors and their values

=item B<list_global_data()>: List global data accessors

=back

=head1 Class Methods to Redefine

You can redefine these in your application's namespace.

=over 4

=item B<end_loop>: This subroutine executes at the end of every shell loop. Redefine it with
	anything you want done at the end of a loop. A good place to set class
	data to default values for every loop iteration.

	sub end_loop {
		my $class = shift;
		$class->save($really_important_info);
	}

=item B<loop_default>: This subroutine executes if no valid command is given. By default this sub
	returns an error message of invalid entry. It is passed	an array containg the command and
	its arguments.
		
	sub loop_default {
		my $class = shift;
		print "Hey bub, don't be trying none of that $_[0] around here.\n";
	}
	
=item B<set_rules>: This sub is called after commandline options are set but before
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

=back

=head1 Commandline Parsing and Parsing Modes

By default, a commandline is parsed as follows:

1. The whole commandline is passed to &parse_options which returns a
hashref mapping options to values and an array of the  rest of the commandline.

2.This hashref is used by &setoptions to set the options.

3. The next white-space separated word is a method name or an alias of
one.

4. Now this is where parse modes come into play. The rest of the commandline,usually arguments to
the above method, is parsed by an entry in the global hash table, &_alias_parse. The current parse
mode's key or alias is saved in the &_parse_mode accessor. By default it's value is 'n' which maps
to &parse_normal. &parse_normal does nothing but return what it's given.

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

- the parse function should receive the whole commandline 
as input and return the arguments to be passed to shell function

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

	3. Library modules' default class data are loaded with &load_class_data,
		followed by loading a user's custom config file for a library with &read_lib_conf.
		If a module has dependent library the dependency's data is loaded first. 

	4. Class data from the script is loaded using &add_to_hash.

	5. Class data from commandline options is loaded using &setoptions. 

=head1 Configuration files

A config file is one big hashref containing variable name and value pairs.
By default the global config file is serialized in YAML. If YAML can't be
loaded then it will resort to requiring the hashref $conf from the config
file.

=head1 Writing Libraries
	
Fry::Shell encourages creating and sharing libraries of (hopefully useful) functions.
By having Fry::Shell handle basic shelling, shells around often-used modules
could grow more easily. 

Only your functions are needed for a library to work. However, if you want to
pass on any customization of your shell then you'll define &_default_data.
&_default_data returns a hash with any of the following keys:

=over 4

=item B<depend([@])>: lists other libraries that this library depends on.

Dependent modules and its class data are loaded before the library module. 
Naturally you could load any dependent modules with 'use' or 'use
base'. Loading it via this key changes the @ISA hierarachy from the
application's perspective, placing base modules before dependent
modules.

=item B<global(\%)>: defines global class data

global class data is visible to all modules in the shell

=item B<alias(\%)>: this specifies aliases you use with options, shell functions
	and parse modes ,you can have ony of the following as keys:
	
	cmds(\%): adds to the accessor  _alias_cmds
	subs(\%): " "  _alias_subs 
	vars(\%): " " _alias_vars
	flags(\%): " " _alias_flags
	parse(\%): " " _alias_parse

=item B<help(\%)>: defines help for shell functions to be used by &help_usage
and &help_description

Has the same structure as the help parameter for &sh_init. See above in the Public
Class Methods section.

=back

=head1 Suggested Modules

A few functions depend on external modules. These modules are optional and their respective
functions fail safely:
	
	&print_global_data: Data::Dumper	
	&read_conf: YAML

=head1 See Also
	
L<Class::Data::Global> for global class data questions.

For similar light shells, see L<Term::Shell>,L<Shell::Base> and
L<Term::GDBUI>.

For big-mama shells look at L<Zoidberg> and L<PSh>.

See the samples directory for sample scripts.

=head1 ToDo	

	Oh so much:
		- global config file: allow it to be a perl data structure,
		support setting global data
		- Redesign to allow plugin architecture for loading data, readline, storing
		data, printing data. By making any external modules plugins, one can
		have a minimal shell and install external modules as desired.
		- support libraries which have object methods, currently only class methods supported  
		- autocompletion support
		- better library plugin support

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.

=head1 BUGS

Although I've written up decent tests there are some combinations of
configurations I have not tried. If you see any bugs tell me so I can make
this module rock solid.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.
