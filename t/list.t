#!/usr/bin/perl
use Test::More tests=>18;
use strict;
use lib 'lib';
use base 'Fry::List';
#use lib 't/testlib';
$SIG{__WARN__} =  sub { return ''}; 

#test data;
	my $bart = {qw/id bart a b status son/};
	my $bart2 = {qw/id bart a B status son/};
	my $lisa = {qw/id lisa a l status daughter/};
	my $lisa2 = {qw/id lisa a L status daughter/};

#setup;
my $cls = __PACKAGE__;
$cls->new(%$bart);
$cls->new(%$lisa);
##TESTS

#new internals
	$cls->setHashDefaults($bart,{qw/friend Milhouse/});
	is($bart->{friend},'Milhouse','&setHashDefaults');
	delete $bart->{friend};

	my $nonid = {qw/name Marge status mother/};
	$cls->setId(marge=>$nonid);
	is($nonid->{id},'marge','&setId');

	$cls->manyNew(bart2=>$bart2,lisa2=>$lisa2);
	is_deeply([$cls->getObj(qw/lisa2 bart2/)],[$lisa2,$bart2],'&manyNew');
	$cls->unloadObj(qw/bart2 lisa2/);

#object operations
	is_deeply($cls->obj('bart'),$bart,'&obj retrieve');
	$cls->obj(lisa=>$lisa2);
	is_deeply($cls->obj('lisa'),$lisa2,'&obj set');
	$cls->obj(lisa=>$lisa);

	$cls->new(qw/id blah/);

	$cls->unloadObj('blah');
	#td:?
	#is($cls->objExists('blah'),0,'&unloadObj + &objExists');
	is_deeply([$cls->getObj(qw/lisa bart dumbo/)],[$lisa,$bart],'&getObj + objExists');

	#setObj
	$cls->setObj(lisa=>$lisa2,bart=>$bart2);
	is_deeply([$cls->obj('bart'),$cls->obj('lisa')],[$bart2,$lisa2],'&setObj');
	$cls->setObj(lisa=>$lisa,bart=>$bart);

#attribute operations
	is($cls->get(qw/bart status/),'son','&get');
	$cls->set(qw/bart status punk/);
	is($cls->get(qw/bart status/),'punk','&set');
	is_deeply([$cls->getMany(qw/a bart lisa/)],[qw/b l/],'&getMany');

	#setMany
	$cls->setMany('a',qw/bart B lisa L/);
	is_deeply([$cls->getMany(qw/a bart lisa/)],[qw/B L/],'&setMany');
	$cls->setMany('a',qw/bart b lisa l/);


#other
	is_deeply([sort $cls->listIds],[qw/bart lisa/],'&listIds');
	is_deeply([sort $cls->listAlias],[qw/b l/],'&listAlias');
	is_deeply([sort $cls->listAliasAndIds],[qw/b bart l lisa/],'&listAliasAndIds');
	is($cls->findAlias('b'),'bart','&findAlias given alias');
	is($cls->findAlias('bart'),'bart','&findAlias given id');
	is($cls->anyAlias('bart'),'bart','&anyAlias given id');

	#pushArray
	my @enemies = (qw/skinner nelson/);
	$cls->pushArray(qw/bart enemies/,@enemies); 
	is_deeply($cls->get(qw/bart enemies/),\@enemies,'&pushArray');
	delete $cls->obj('bart')->{enemies};

