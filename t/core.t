#!/usr/bin/perl

#This test script currently tests four modules: Fry::Cmd,Fry::Lib,Fry::Var and Fry::Opt.
#I'll separate 'em as needed.

use strict;
use Test::More tests=>32;
use lib 'lib';
use lib 't/testlib';
#use diagnostics;
use Fry::Var;
#use Data::Dumper;
our @ISA;
$SIG{__WARN__} =  sub { return ''}; 

BEGIN {
	package MyList;
	sub _shellClass {return 'Sh'}
	sub _varClass { return 'Fry::Var' }
}
	use base 'MyList';
#setup
	package main;
	my $cls = __PACKAGE__;

	package Sh;
	#This class imitates a shell class by setting up the basic methods a
	#core class expects: _obj,Flag,setFlag

	our $Pass = 1;
	our %flag;

	my $obj = bless {qw/obj obj/}, 'Sh';
	sub _obj {$obj}
	sub Flag { return $flag{$_[1]} }
	sub setFlag {$flag{$_[1]} = $_[2]; }
	sub t_var { shift; @main::testvar = @_ ; return $Pass}

	package main;

###Fry::Var test
#none so far
#require Fry::Var;
#push(@ISA,'Fry::Var');
#$cls->manyNew(warnsub=>{qw/id warnsub value warn/});

###Fry::Cmd tests
#pop @main::ISA;
require Fry::Cmd;
push(@ISA,'Fry::Cmd');

my %obj = (scalar=>{qw/id scalar arg $var/,_sub=>\&scalar},array=>{qw/id array arg @var/},hash=>{qw/id hash arg %var/}); 
my @args = (qw/k1 v1 k2 v2/);
my %expected = (scalar=>['k1'],array=>[qw/k1 k2 v1 v2/],hash=>[qw/k1 k2/]);
our @testvar;
my @scalar;
sub scalar {@scalar = @_ if (@_)}

main->manyNew(%obj);
print "Testing Fry::Cmd subs\n\n";

#tests pass
for my $cmd (qw/scalar array hash/) { 
	is(main->checkArgs($cmd,@args),1,'checkArgs passes');
	is_deeply([sort @testvar],$expected{$cmd},"correct arguments passed to test sub for $cmd");
	@args = (qw/k1 v1 k2 v2/);
}

#tests fail
$Sh::Pass = 0;

for my $cmd (qw/scalar array hash/) { 
	is(main->checkArgs($cmd,@args),0,'checkArgs fails');
	is_deeply([sort @testvar],$expected{$cmd},"correct arguments passed to test sub for $cmd");
	is(Sh->Flag('skipcmd'),1,'skipcmd flag set');
	@args = (qw/k1 v1 k2 v2/);
}

#&runCmd cases
main->runCmd('scalar',qw/tested cmd/);
is_deeply([sort @scalar],[qw/cmd tested/],'runCmd called with correct arguments');

###Fry::Lib tests
pop @main::ISA;
require Fry::Lib;
push(@ISA,'Fry::Lib');
my @libs = qw/:Test1 Fry::Lib::Woah/;

print "\nTesting Fry::Lib subs\n\n";

is_deeply([main->fullName(@libs)],[qw/Fry::Lib::Test1 Fry::Lib::Woah/],'&fullName');

main->runLibInits('Fry::Lib::SampleLib');
is_deeply(&Fry::Lib::SampleLib::_initLib,Sh->_obj,'&runLibInits requires library and sets shell object correctly');

###Fry::Opt tests
pop @main::ISA;
require Fry::Opt;
push(@ISA,'Fry::Opt');
my %optobj = (flag=>{qw/id flag a f type flag stop 1 tags counter/},var=>{qw/id var type var/,action=>\&actionsub},none=>{qw/id none type none noreset 1/});
my @actionsub;
sub actionsub { @actionsub = @_}

main->manyNew(%optobj);

print "\nTesting Fry::Opt subs\n\n";
#&setOptions
	main->setOptions(flag=>1);
	is(Sh->Flag('flag'),1,'&setOptions with type flag');
	main->setOptions(flag=>0);
	main->setOptions(f=>1);
	is(Sh->Flag('flag'),1,'&setOptions with option alias');

	Fry::Var->new(qw/id var value blah/);
	main->setOptions(var=>'weally');
	is(Fry::Var->obj('var')->{value},'weally','&setOptions with type var');

	main->setOptions(none=>'yep');
	is (main->get(qw/none value/),'yep','&setOptions with type none');
	
	TODO: {
	#define a working warnsub via Fry::Var
	#main->setOptions(blah=>'blah');
	ok(! main->objExists('blah'),'invalid option still nonexistent after &setOptions');
	}

#&Opt
	is(main->Opt('flag'),1,'&Opt with type flag');
	is(main->Opt('var'),'weally','&Opt with type var');
	is(main->Opt('none'),'yep','&Opt with type none');
	ok(! main->Opt('blah'),'&Opt returns undef for invalid argument');

main->setDefaults;
main->setOptions(none=>'yepper',flag=>0);
is_deeply({main->findSetOptions},{qw/flag 0 none yepper/},'&findSetOptions');

#&resetOptions
main->resetOptions;
is(main->Opt('none'),'yepper','noreset attribute works in &resetOptions');
is(main->Opt('flag'),0,'stop attribute > 0 prevents reset in &resetOptions');
#print Dumper main->list;
main->preParseCmd(flag=>0,var=>'woah');
is(main->obj('flag')->{stop},1,'stop set to 1 via counter tag and &preParseCmd');
is_deeply(\@actionsub,[main->_shellClass->_obj,'woah'],'action executed and passed arguments correctly via &preParseCmd');
