#!/usr/bin/perl

use Test::More 	tests=>15;
use strict;

use base 'Fry::Shell';
use Data::Dumper;

my $prompt = "Once again?: ";
my %choices = (e=>'execute',p=>'print');
my %alias_vars = (qw/b bigbutt/);
my %alias_subs = (qw/M multiply/);
my %alias_flags = (qw/c cool/);
my $help = {execute=>{d=>'Does something',u=>''}};

my @accessors = (qw/_alias_cmds prompt _alias_subs _alias_vars _alias_flags _option_value _alias_parse lines _flag _parse_mode/);
my @redefine_fns =  (qw/set_rules loop_default end_loop/);

sub multiply {
	my $class = shift;
	$class->lines->[0] = $_[0];
}	

#main
	#sh_init
	eval{__PACKAGE__->sh_init(prompt=>$prompt,alias_cmds=>\%choices,help=>$help,
		alias_vars=>\%alias_vars,alias_subs=>\%alias_subs, alias_flags=>\%alias_flags,
		alias_parse=>{qw/M mysterymode/},option_value=>{qw/b yeah c 1 M 14/},
		conf_file=>'/home/bozo/bin/t/.shell.yaml')};
	ok(! $@, '&sh_init executes');

	#default fns
		can_ok(__PACKAGE__, @redefine_fns) && print "\tredefine functions defined\n";

	#&load_class_data
		#global data defined
		can_ok(__PACKAGE__,@accessors) && print "\tmain accessors defined\n";
		#&add_to_hash: help set
		is(__PACKAGE__->help_data->{perl_exe}->{u},'$perl_code','&help_data set');
		#td: one alias set

	#&read_conf:conf file set via yaml or require
	

	#td: load_libs defined
		#&load_libs: dependent library loads first
		#&load_module: correct @ISA
		#&read_lib_conf

	#help defined from script
	is(__PACKAGE__->help_data->{execute}->{d},'Does something','&help_data set');

	#other parameters defined from script
	#ie bigbutt, alias_parse
	is(__PACKAGE__->prompt,'Once again?: ','script parameter prompt set correctly');
	is(__PACKAGE__->_alias_cmds->{'e'},"execute","aliasing works");


	#setoptions
		#option var
		if (can_ok(__PACKAGE__,'bigbutt')) {
			is(__PACKAGE__->bigbutt,'yeah','checking global var');
		}

		#option flag
		is(__PACKAGE__->_flag->{cool},1,'checking global flag');

		#option function
		is(__PACKAGE__->lines->[0],14,'checking option function');

	#parse_*	
	__PACKAGE__->lines([qw/one cow fart equals thirty human farts/]);
	my @results = __PACKAGE__->parse_menu(qw/scp -ra 2-5,7/);
	is("@results","scp -ra cow fart equals thirty farts","checking parse functions");
	
	#check menu
	eval{__PACKAGE__->once('-m help_usage help_usage')};
	ok(! $@, '&once executes');
	is(__PACKAGE__->_parse_mode,"m","parse_mode set correctly with -m");
	#check parse mode set correctly
	is_deeply(__PACKAGE__->_alias_parse,{qw/m parse_menu n parse_normal M mysterymode/});


#TODO
	#&list_to_hash, default commands (ie \pd and Dumper)

	#rare/advanced: multiletter options,redefine default aliases, &setoptions
	#data flow followed
	
