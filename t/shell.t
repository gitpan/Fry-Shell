#!/usr/bin/perl

use Test::More 	tests=>23;
use strict;

use base 'Fry::Shell';
use Data::Dumper;

my $prompt = "Once again?: ";
my %choices = (e=>'execute',p=>'print');
my %alias_vars = (qw/b bigbutt/);
my %alias_subs = (qw/M multiply/);
my %alias_flags = (qw/c cool/);
sub multiply {
	my $class = shift;
	$class->lines->[0] = $_[0];
}	

#main
	#sh_init
	eval{__PACKAGE__->sh_init(prompt=>$prompt,alias_cmds=>\%choices,alias_vars=>\%alias_vars,alias_subs=>\%alias_subs,
	alias_flags=>\%alias_flags,alias_parse=>{qw/M mysterymode/},option_value=>{qw/b yeah c 1 M 14/},conf_file=>'/home/bozo/bin/t/.shell.yaml')};
	ok(! $@, '&sh_init executes');

	#default vars
	for (qw/_alias_cmds prompt _alias_subs _alias_vars _alias_flags _option_value _alias_parse lines _flag _parse_mode _fh/) {
		can_ok(__PACKAGE__,$_);
	}		

	#default fns
	for (qw/help loop_default/) {
		eval {__PACKAGE__->$_};
		ok(! $@ , "method $_ executes");
	}	
	#checks alias
	is(__PACKAGE__->_alias_cmds->{'e'},"execute","aliasing works");

	#setoptions
		#global var
		print "global var made:\n";
		if (can_ok(__PACKAGE__,'bigbutt')) {
			is(__PACKAGE__->bigbutt,'yeah','checking global var');
		}

		#global flag
		is(__PACKAGE__->_flag->{cool},1,'checking global flag');

		#function
		is(__PACKAGE__->lines->[0],14,'checking option function');

	#parse_*	
	__PACKAGE__->lines([qw/one cow fart equals thirty human farts/]);
	my @results = __PACKAGE__->parse_menu(qw/scp -ra 2-5,7/);
	is("@results","scp -ra cow fart equals thirty farts","checking parse functions");
	
	#check menu
	eval{__PACKAGE__->once('-m help')};
	ok(! $@, '&once executes');
	is(__PACKAGE__->_parse_mode,"m","parse_mode set correctly with -m");
	#check parse mode set correctly
	is_deeply(__PACKAGE__->_alias_parse,{qw/m parse_menu n parse_normal M mysterymode/});

	#plugin,loadclassdt
	#loads right @ISA,read confs into var,loa
	
