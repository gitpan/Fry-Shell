#!/usr/bin/perl
#declarations
package Fry::Shell;
use strict;
use warnings;
#use diagnostics;
use Fry::Base;
use base 'Fry::Error';
#use Fry::Wrap;
our $VERSION = '0.11';
our $Count;
our @ISA;
my $shellobj;

#core data
	sub _default_data {
		return {
			opts=>{
				menu=>{qw/a m type flag tags counter/,
					action=> sub{ $_[0]->{opt}->setOptions(parsesub=>'m');
					$_[0]->{opt}->preParseCmd(parsesub=>'m')}},
				parsesub=>{qw/a p type var default n tags counter/},
				multiline=>{qw/a M type flag tags counter/},
				fh_file=>{qw/a f type var/,
					action=>sub{open(*F::FILE,'>',$_[0]->Var('fh_file')) or die "noo: $!";
					$_[0]->setVar(fh=>'F::FILE'); $_[0]->{flag}{closefh}++ }},
				pager=>{qw/a l type flag/,
					action=>sub { open(*F::PAGER,"| ".  $_[0]->Var('pager'));
					$_[0]->setVar(fh=>'F::PAGER');$_[0]->{flag}{closefh}++ }},
				skiparg=>{qw/a S type flag noreset 1/},
				autoview=>{qw/a av type flag noreset 1 default 1/},
				class_act_new=>{qw/a cn/,action=>\&classActNew}, 
				#action_class=>{qw/a C type var noreset 1/}, 
			},
			vars=>{
				alias_parse=>{n=>'parseNormal', m=>'parseMenu',e=>'parseEval'},
				defaultlib=>'Fry::Lib::Default',
				base_class=>'baseClass',
				cmd_class=>'CmdClass',
				plugin_config=>'Fry::Config::Default',
				plugin_readline=>'Fry::ReadLine::Default',
				plugin_dump=>'Fry::Dump::Default',
				plugin_view=>'Fry::View::CLI',
				defaultlibs=>[],
				parsesub=>'n',
				warnsub=>'warn',
				diesub=>'die',
				fh=>'STDOUT',
				view_options=>'',
				eval_splitter=>',,',
				field_delimiter=>',,',
				fh_file=>'',
				pager=>'less',
				mline_char=>';',
				pipe_char=>'\|\s*',
				prompt=>'!fry shell!:', 
				core_config=>$ENV{HOME}.'/.frycore',
				global_config=>$ENV{HOME}.'/.fryshellrc',
				lines=>[],
				loaded_libs=>[],
				#conf_dir=>$ENV{HOME}."/.shell/conf/",
				#global_config=>$ENV{HOME}."/.shell2.yaml",
				#td:  hash of get/set subs for opt types
				#opttype=>{},
				#loglevel=>'1',
			},
		}
	}

	sub import {
		my $class = shift;
		no strict 'refs';
		my $caller = (caller())[0];	
		#print "$class\n";
		*{"${caller}::shell"} = \&shell;
	}	
#public methods
	sub new ($%) {
		my ($class,%arg) = @_;
		$arg{_stage} = $arg{_stage} || -1;
		my %obj = (qw/lib Fry::Lib cmd Fry::Cmd var Fry::Var opt Fry::Opt/);
		$obj{flag} = {};
		$obj{obj} = {};

		my $o = bless \%obj,$class;
		*shellobj = \$o;

		$o->initCoreClasses(\%arg);

		#tell Fry::Base's about var class
		$o->{var}->_varClass($o->{var});

		return $o if ($arg{_stage} == 1);

		$o->setCoreData(\%arg);
		$o->initISA;
		return $o if ($arg{_stage} == 2);

		$o->loadPlugins(qw/plugin_readline plugin_dump plugin_view plugin_config/);


		#loadLibs
			$o->loadLibs($o->Var('defaultlib'));
			$o->loadLibs(@{$o->Var('defaultlibs')});
			$o->loadLibs(@{delete $arg{libs}}) if (exists $arg{libs});

		$o->setAllObj(%{delete $arg{load_obj}}) if (exists $arg{load_obj});

		#set options to their defaults 
		$o->{opt}->resetOptions({reset=>1});

		#td: shouldn't allow early_core_vars in this config
		$o->loadFile($o->Var('global_config'));

		delete $arg{_stage};
		#h: should check that variables don't already exist, could be a
		#problem when variables have more attr than just a value
		$o->setVarObj(%arg);
		
		$o->{lib}->runLibInits(@{$o->Var('loaded_libs')});

		#?:setCmdlineOpts
		#$o->setOptions(%{delete $arg{options}});

		return $o;
	}
	sub shell (;$) {
		my $o = shift || Fry::Shell->new;

		$o->once(@_);
		while (! $o->{flag}{quit}) {
			$o->once;
		}
	}	
	sub once ($@){
		my $o = shift;
		$Count++;
		#i:
		#print "loop $Count\n";

		$o->preLoop;	

		#input: if @_ defined, skips prompting
		my $input= (@_) ? "@_" : $o->getInput;
		return if $input eq "";	

		my @lastargs;
		my @chunks = $o->parseChunks($input);
		#info ,print Dumper \@chunks;
		for my $chunk (@chunks) {
			my ($cmd,@args) = $o->parseLine($chunk);
			#@args = (@args,@lastargs); # unless ("@lastargs" ==1);# if (not @args);

			#keep here for autodetected commands
			$cmd = $o->findCmdAlias($cmd);
			#$o->{cmd}->cmdChecks($cmd,@args);
			#$o->{cmd}->argAlias($cmd,\@args);
			$o->{cmd}->checkArgs($cmd,@args) unless ($o->{flag}{skiparg});
			@lastargs = $o->runCmd($cmd,@args) if (! $o->{flag}{skipcmd}); 
			$o->autoView($cmd,@lastargs) if ($o->{flag}{autoview})
		}
		close($o->Var('fh')) or die "can't close file: $! " if ($o->{flag}{closefh}); 

		$o->resetAll;
		$o->postLoop;
	}
	sub libObj ($$) { $_[0]->{lib}->obj($_[1]) }
	sub optObj ($$) { $_[0]->{opt}->obj($_[1]) }
	sub varObj ($$) { $_[0]->{var}->obj($_[1]) }
	sub cmdObj ($$) { $_[0]->{cmd}->obj($_[1]) }
	sub runCmd ($@) {shift->{cmd}->runCmd(@_) }
	sub initLibs ($@) {
		my ($o,@modules) = @_;
		@modules = $o->{lib}->fullName(@modules);
		$o->loadLibs(@modules);
		$o->{lib}->runLibInits(@modules);
	}
	sub loadLibs ($@) {
		my ($o,@modules) = @_;
		@modules = $o->{lib}->fullName(@modules);
		for (@modules) { $o->loadLib($_) }
	}
	sub loadFile ($$) {
		my ($o,$file) = @_;

		if (! -e $file) {
			#W:info
			#$o->_warn("Can't load file $file because it doesn't exist");
			return;
		}

		$o->_require($o->Var('plugin_config'));
		#my $conf = $o->Config->read($file) || {}; 
		my $conf = $o->Var('plugin_config')->read($file) || {}; 
		#W:debug
		$o->setAllObj(%$conf);
	}
	sub loadPlugins($@) {
		my ($o,@plugins) = @_;

		for (@plugins) {
			$o->_require($o->Var($_),"$_ require failed:");
			$o->Var($_)->setup($o) if ($o->Var($_)->can('setup'));
		}

		#log
		#$o->_require("Log::Dispatch");
		#$o->_require("Log::Dispatch::Screen");
		#$o->_require("Log::Dispatch::File");
		#$o->{plug}{log} = Log::Dispatch->new(callbacks=>\&logback);
		#$o->{plug}{log}->add( Log::Dispatch::File->new( name => 'file1', min_level
		#=> 'debug', filename => '/home/bozo/temp/logfile'));
		#$o->{plug}{log}->add(Log::Dispatch::Screen->new(name=>'screen',min_level=>'debug',stderr=>0));
		#print "d: ",$o->{plug}{log}->would_log("alert"),"\n";
	}
	sub setCmdObj ($%) {
		my ($o,%arg) = @_;
		$o->{cmd}->manyNew(%arg);
		#h: setting strange default
		for my $cmd (keys %arg) {
			$o->{cmd}->obj($cmd)->{_sub} = sub {$o->$cmd(@_) }
				if (! exists $o->{cmd}->obj($cmd)->{_sub});
			if (exists $o->{cmd}->obj($cmd)->{arg} && ! exists $o->{cmd}->obj($cmd)->{u}) {
				#$o->{cmd}->obj($cmd)->{u} ||= $o->{cmd}->obj($cmd)->{arg}
				my $arg = $o->{cmd}->obj($cmd)->{arg};
				$arg =~ s/cmd/command/;
				$arg =~ s/lib/library/;
				$arg =~ s/opt/option/;
				$arg =~ s/var/variable/;
				$o->{cmd}->obj($cmd)->{u} = $arg;
			}	
		}
		
		#if (! exists $o->{cmd}{$cmd}{_sub});
	}
	sub setOptObj ($%) { shift->{opt}->manyNew(@_); }
	sub setVarObj ($%) {
		my ($o,%arg) = @_;
		my (%empty) =  map {$_=> {} } keys %arg;
		#w:defaults set b4 value
		$o->{var}->manyNew(%empty);
		$o->setVar(%arg);
		#$o->setGenHashDefault('var',[keys %arg],{scope=>'global'});
	}
	sub setLibObj ($%) { shift->{lib}->manyNew(@_) }
	sub setAllObj ($%) {
		my ($o,%data) = @_;
		$o->setVarObj(%{$data{vars}}) if (exists $data{vars});
		$o->setOptObj(%{$data{opts}}) if (exists $data{opts});
		$o->setCmdObj(%{$data{cmds}}) if (exists $data{cmds});
	}
#private methods
	sub _obj { return $Fry::Shell::shellobj; }
	##new subs
	sub initISA ($) {
		my $o = shift;
		#actions based on core var
		my $cmdClass = $o->Var('cmd_class');
		my $baseClass = $o->Var('base_class');
		push (@ISA, $o->Var('cmd_class'),$o->Var('base_class'));	

		#done to avoid warnings in ISA searches
		eval "package $baseClass";
		eval "package $cmdClass";
		package Fry::Shell;

		#load script level class into cmdClass
		{ #change caller if this moves
		no strict 'refs';
		my $script_class = (caller(1))[0];

		#to prevent recursive ISA loop ie placing shell_class in its own @ISA
		if ($o->Var('shell_class') ne $script_class) {
			push (@{"${cmdClass}::ISA"},$script_class);
		}
		}
	}		
	sub setCoreData ($\%) {
		my ($o,$arg) = @_;
		my @early_core_vars = (qw/core_config base_class cmd_class
		plugin_config plugin_dump plugin_readline plugin_view default_lib
		default_libs/);

		$o->setVarObj(shell_class=>ref $o);
		$o->loadLib(__PACKAGE__);

		#initialize error
		eval {require Carp }; 
		if (! $@) { $o->setVar(warnsub=>'Carp::carp',diesub=>'Carp::croak')}

		#detect best plugins
			eval { require Data::Dumper};
			if (! $@ ) {$o->setVar(plugin_dump=>'Fry::Dump::DataDumper') }

			eval { require Term::ReadLine; require Term::ReadLine::Gnu};
			if (! $@ ) {$o->setVar(plugin_readline=>'Fry::ReadLine::Gnu') }

		#viaFile
		$o->loadFile(delete $arg->{core_config} || $o->Var('core_config'));

		my %corehash;
		for my $core (@early_core_vars) {
			$corehash{$core} = delete $arg->{$core} if (exists $arg->{$core})
		}
		$o->setVar(%corehash);
	}
	sub initCoreClasses ($\%) {
		my ($o,$arg) = @_;
		my %arg = %$arg;

		for (qw/lib cmd var opt/) {
			$o->{$_} = delete $arg{$_} if (exists $arg{$_})
		}
		for (qw/lib cmd var opt/) {
			$o->_require($o->{$_});
		}
	}
	##once subs
	sub autoView ($@) {
		my ($o,$cmd,@args) = @_;
		#print scalar(@args),"\n";
		#print "@_\n";
		#defined autoview
		if ($o->{cmd}->objExists($cmd) && exists $o->{cmd}->obj($cmd)->{ret}) {
			#my $o->obj($cmd)->ret
		}
		#real autoview
		else {
		if (@args > 1) {
			if (ref $args[0]) { $o->view($o->dumper(\@args)) }
			else { $o->View->list(@args) }
		}
		elsif (@args == 1) {
			if ($args[0] =~ /^[01]$/) { 
				#print return codes
			}	
			elsif (ref $args[0] eq "HASH") {
				$o->View->hash($args[0],$o->Var('view_options'));
			}
			elsif (ref $args[0] eq "ARRAY") {
				if (ref $args[0][0] eq "ARRAY") { 
					$o->View->arrayOfArrays(@{$args[0]});
				}
				else { $o->View->list(@{$args[0]}) }
			}
			elsif (! ref $args[0]) { $o->view($args[0]) }
			else { $o->view($o->dumper($args[0])) }
		}
		#should be warning
		else { $o->view("No arguments returned") }
		}
	}
	sub resetAll ($) {
		my $o = shift;
		$o->{opt}->resetOptions;
		$o->setVar(fh=>'STDOUT');
		$o->setVar(view_options=>'');
		$o->resetFlags;
	}
	sub resetFlags ($) {
		my $o = shift;
		$o->{flag}{skipcmd} = 0;
		$o->{flag}{closefh}=0;
	}
	sub parseCmd ($$) {
		my ($o,$input) = @_;

		my $parsesub = $o->Var('parsesub');
		#if parsesub is alias
		if (exists $o->Var('alias_parse')->{$parsesub} && $o->can($o->Var('alias_parse')->{$parsesub})) {
			my $fullsub = $o->Var('alias_parse')->{$parsesub};
			return $o->$fullsub($input);
		}
		elsif ($o->can($parsesub)) { return $o->$parsesub($input) }
		else { $o->_warn("current parsesub $parsesub is invalid");
			return $o->parseNormal($input);
		}
	}
	sub setPrompt($) {
		my $o = shift;
		my %opt = $o->{opt}->findSetOptions;
		my $prompt;

		#options
		if (%opt) {
		$prompt .= "[ ";
		#$prompt .= "opt: ";
			while (my ($k,$v) = each %opt) {
				$prompt .= "$k=$v ";
			}
			#$prompt .= ",";
		$prompt .= "] ";
		}

		#flags
		#$prompt .= "flag: ";
		#for (keys %{$o->{flag}}) {
		#$prompt .= "$_ " if ($o->{flag}{$_}) 
		#}	
		$prompt .= $o->Var('prompt');
	}
	sub getInput ($) {
		my $o = shift;

		my $prompt = $o->setPrompt;
		my $input = $o->Rline->prompt($prompt);
		if ($o->{flag}{multiline}) {
			my $mline_char = $o->Var('mline_char');
		       	while ($input !~ /$mline_char$/) {
				$input .= " " . $o->Rline->prompt($prompt);
			}
			$input =~ s/$mline_char$//;
			$o->parseMultiline(\$input);
		}
		return $input;
	}
	sub parseLine ($$) {
		my ($o,$input) = @_;

		my %opt = $o->parseOptions(\$input);

		$o->{opt}->setOptions(%opt);
		$o->{opt}->preParseCmd(%opt);

		#parse args
		return $o->parseCmd($input);
	}
	##parse subs
	sub parseChunks($$) {
		my ($o,$input) = @_;
		my $pipe_char = $o->Var('pipe_char');
		return split(/$pipe_char/,$input);
	}	
	sub parseMultiline($\$) {
		my ($o,$input) = @_;
		$$input =~ s/\n//g;	
	}
	sub parseOptions ($\$) {
		my ($o,$input) = @_;
		my %opt;
		#split just in case input is scalar
		my @args = split(/ /,$$input);
		#to avoid uninit pattern match of args
		no warnings;
		#could've solved w/: push(@args,'')

		while ($args[0] =~ /^-\w/) {

			#shift off '-'
			my $option = substr($args[0],1) || "";

			#variables and subs + flag = 0
			if ($option =~ /=/) {
				my ($key,$value);
				($key,$value) = split(/=/,$option); $opt{$key} = $value;
			}
			#flags
			else { $opt{$option} =1 }

			shift @args;
		}
		$$input = "@args";
		return %opt;
	}
	sub parseNormal ($$) { return split(/ /,$_[1]) }	
	sub parseEval ($$) { 
		my ($o,$input) = @_;
		my $splitter = $o->Var('eval_splitter');
		my (@noneval,@eval,$cmd);	

		if ($input =~ $splitter) {
			my ($noneval,$eval) = split(/$splitter/,$input,2);
			@noneval = $o->parseNormal($noneval);
			@eval = "$eval";
		}
		else {
			($cmd,@eval) = split(/ /,$input,2);
			@noneval = $cmd;
		}
		my $text = '@eval';
		eval "$text = (@eval)";
		#print "n:@noneval\n";
		#print "e:@eval\n";
		return (@noneval,@eval);
	}
	sub parseMenu ($$) {
		#d: creates @cmd_beg,@entry and @save from @args
		#my ($o,@args) = @_;
		my $o  = shift;
		my @args = split(/ /,shift());
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
		foreach (@entry) { @save = $o->parseNum($_,@{$o->Var('lines')})};

		if (@args > 0) { return (@cmd_beg,@save,@args);	}
		else {return (@cmd_beg,@save,@args); }
	}
	sub parseNum ($@){
		my $class = shift;
		my @save;my $e;my $count; 
		my ($entry,@choose) = (@_);
		#td: fix unitialized warning
		no warnings;
		$class->_die("Invalid argument, $entry , passed to &parse_num. Doesn't contain any numbers.")
	       	if ($entry !~ /\d/);

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
	##lib subs
	sub getLibData ($$) {
		my ($o,$module) = @_;
		#done for &_default_data
		#?: return undef if module require fails
		$o->_require($module,{'warn'=>1});
		return $module->_default_data if ($module->can('_default_data'))
	}
	sub loadLib ($$) {
		#d: fullname
		my ($o,$module) = @_;

		my $dt = $o->getLibData($module);

		#e: empty dt returned
		return if (ref($dt) ne "HASH");

		$o->loadDependencies($dt);

		$o->setAllObj(%$dt);

		{
		no strict 'refs';
		my $cmd_class = $o->Var('cmd_class');	
		push(@{"$cmd_class\::ISA"},$module) unless ($module eq __PACKAGE__);
		}
		my ($varlist,$optlist,$cmdlist) = $o->readLibObj($dt); 


		#extract other attributes
		delete $dt->{vars}; delete $dt->{cmds}; delete $dt->{opts}; delete $dt->{lib};

		$o->setLibObj ($module=>{cmds=>$cmdlist,opts=>$optlist,vars=>$varlist,%$dt});

		$o->{var}->pushArray('loaded_libs','value',$module);
	}
	sub readLibObj ($$) {
		my ($o,$dt) = @_;
		my ($varlist,$optlist,$cmdlist) = ([],[],[]);
			
			$varlist = 	[keys %{$dt->{vars}}] if (exists $dt->{vars});
			$optlist = 	[keys %{$dt->{opts}}] if (exists $dt->{opts});
			$cmdlist = 	[keys %{$dt->{cmds}}] if (exists $dt->{cmds});

		#add to Lib Obj directly via {lib}
		if (exists $dt->{lib}) {
			#push(@$varlist,@{$dt->{lib}{vars}}) if (exists $dt->{lib}{vars});
			#push(@$optlist,@{$dt->{lib}{opts}}) if (exists $dt->{lib}{opts});
			push(@$cmdlist,@{$dt->{lib}{cmds}}) if (exists $dt->{lib}{cmds});
		}
		return ($varlist,$optlist,$cmdlist);
	}
	sub loadDependencies ($$) {
		my ($o,$dt) = @_;	
		if (exists ($dt->{depend})) {
			for my $basename (@{$dt->{depend}}) {

				#load if not loaded
				unless(grep(/^$basename$/,$o->List('lib')) > 0) {
					$o->loadLib($o->{lib}->fullName($basename));
				}
			}
		}
	}
#public shell interf to libs
	sub saveArray ($@) {shift->setVar(lines=>[@_]) }
	sub Var ($$) {return $_[0]->genValue('var',$_[1]) }
	sub varMany ($@) { return shift->{var}->getMany('value',@_) }  
	sub setVar ($%) { shift->{var}->setMany('value',@_) }
	sub view ($@) { shift->View->view(@_); }
	sub dumper ($@) { shift->Dump->dump(@_); }
	#sub libList ($) {$_[0]->List('lib')}	
	sub List ($$) {$_[0]->{$_[1]}->listIds }
	sub listAll ($$) { $_[0]->{$_[1]}->listAliasAndIds }

	##obj + class methods
	sub Flag ($$){
		my $o = (ref $_[0]) ? $_[0] : $_[0]->_obj;
		return $o->{flag}{$_[1]} ;
	}
	sub setFlag ($$){
		my $o = (ref $_[0]) ? $_[0] : $_[0]->_obj;
		$o->{flag}{$_[1]} = $_[2];
	}

	sub lib ($) { return shift->{lib} } 
	sub cmd ($) { return shift->{cmd} } 
	sub var ($) { return shift->{var} } 
	sub opt ($) { return shift->{opt} } 
	##plugins
	#?: could have 'em return $o as first arg
	sub Dump ($) { return shift->Var('plugin_dump') }
	sub View ($) { return $_[0]->Var('plugin_view') }
	sub Rline ($) { return shift->Var('plugin_readline') }
	sub Config ($) { return shift->Var('plugin_config') }
#shell macros
	sub unloadGeneral ($$@) {shift->{shift()}->unloadObj(@_)}
	sub genValue ($$$) { return $_[0]->{$_[1]}->get($_[2],'value') }

	sub findCmdAlias ($$) { $_[0]->{cmd}->anyAlias($_[1]) }
#redefinable methods
	sub loopDefault ($@) {
		my $o = shift;
		no warnings;	
		#my @arg = ("@_" !~ /^\s*$/) ? @_ : '';
		#print "blah\n" if ($_[0] eq '' && @_ == 1);
		#td: uninitialized warning, can't figure out a defined/nondefined argument
		 $o->view("Yo buddy, your command: '",join(' ',@_),"' isn't valid.\n"); 
	}
	sub preLoop ($) {}	
	sub postLoop ($) {}	
#later
	sub logback {
		#d:later
		my %p = @_;
		my %loglevel = (qw/debug 0 info 1 notice 2 warning 3 error 4 critical 5 alert 6 emergency 7/);
		if ($loglevel{$p{level}} <= -1) {
			return $p{message}
		}
		else { return ""}
	}
1;

=head1 NAME

Fry::Shell - Flexible shell framework which encourages using loadable libraries of functions.

=head1 SYNOPSIS

	From the commandline: perl -MFry::Shell -eshell

	OR

	In a script:

	package MyShell;
	use 'Fry::Shell';

	#subs
	sub evalIt {
		my $o = shift;
		my $code = ($o->Flag('strict')) ? 'use strict;' : '';
		$code .= "@_";
		eval "$code";
	}
	sub listStations {
		my $o = shift;
		my @stations = ( {name=>'high energy trance/techno',ip=>'http://64.236.34.196:80/stream/1003'},
			{name=>'macondo salsa',ip=>'http://165.132.105.108:8000'},
			{name=>'new age',ip=>'http://64.236.34.67:80/stream/2004'},
		);
		$o->saveArray(map{$_->{ip}} @stations);
		return map {$_->{name}} @stations;
	}

	#set shell prompt
	my $prompt = "Clever prompt: ";

	#initialize shell and load a command and an option 
	my $sh = Fry::Shell->new(prompt=>$prompt,
		load_obj=>{cmds=>{listStations=>{a=>'lS'}},opts=>{strict=>{type=>'flag',a=>'n',default=>0}} });

	#begin shell loop
	$sh->shell(@ARGV);

	####end of example, start of other possible methods 

	#run shell once
	$sh->once(@ARGV);

	#Methods which add to shell's functionality

		$sh->setAllObj(%all);
		$sh->setLibObj(%libs);
		$sh->setOptObj(%opts);
		$sh->setCmdObj(%cmds);
		$sh->setVarObj(%vars);

		#only loads library
		$sh->loadLibs(@modules);
		#loads library and runs each library's &_initLib 
		$sh->initLibs(@modules);

		$sh->loadFile($file);

	#Shell API

		#retrieve shell component objects by id
		my $opt1 = $sh->optObj($opt);
		my $cmd1 = $sh->cmdObj($cmd);
		my $lib1 = $sh->libObj($lib);
		my $var1 = $sh->varObj($var);

		$sh->runCmd($cmd);

=head1 VERSION	

This document describes version 0.11.

=head1 NOTE

Due to major design changes, this version is incompatible with the
previous. This means the current Fry::Lib::CDBI libraries are incompatible
(doh!).  Although this code is decently tested and is apparently unbuggy, I
consider it alpha until a few design issues have been solved.  I will try to
keep the public methods (shown above) compatible with future releases.

Oh yeah, some abbreviations I use often in this module, especially in naming
subroutines:
cmd- command, lib- library,opt- option,var-variable, gen- general, attr- attribute .

=head1 DESCRIPTION 

Fry::Shell is a simple and flexible way of creating an application for a group
of functions (a shell). Unlike other light-weight shells, this module
facilitates (un)loading libraries of functions and thus encourages creating
shells tailored to several modules. Although the shell is currently only
viewable at the commandline, the framework is flexible enough to support other
views (especially a web one :). This module is mainly serving(will serve) as
the model in an MVC framework.

From a user perspective it helps to know that a shell session consists of mainly four components:
libraries (lib), commands (cmd), options (opt) and variables(var). Commands and options are the same
as in any shell environment: a command mapping to a function and an option changing the behavior of
a command ie changing variables within it or calling functions before the command. Variables
store all the configurable data, including data relating to these commands and options. Libraries
are containers for a related group of these components.

=head2 FEATURES

Here's a quick rundown of Fry::Shell's features:

	- Subclassable: almost all functions are defined as class methods making this module easily subclassable
	- Loading/unloading shell components at runtime.
	- Flexible framework for using shell features via plugins.	 
		You can even set up a bare minimum shell needing no external modules! Currently
		plugins exist for dumping data,readline support,reading shell configurations and
		viewing shell output. 
	- Commands and options can be aliased for minimal typing at the commandline.
	- Commands can have help and usage defined. 
	- Commands can have user-defined argument types. 
		One defines argument types by subroutines or tests that they should pass.
		These tests are then applied to a command's defined argument(s).
		With defined argument types, one can also define autocompletion
		routines for a command's arguments.
	- Options can modify variables.
		Since variables exist for almost every aspect of the shell, options
		can change many core shell functions. A handy example is 'parsesub'
		which names the current parse subroutine for the current line.
		Changing this var would change how the input after the options is
		parsed.
	- Options can have different behaviors defined including the ability to invoke
		subroutines when called or to maintain a value for a specified amount of iterations. 
	- Default options include 'menu' which numbers output and allows the next command to
	reference them by number.
	- Page output with preferred pager.
	- Multiline mode.
	- Comes with a decent default library,Fry::Lib::Default, to dump,list or
		unload any shell component, run system commands,evaluate perl statements
		and execute methods of autoloaded libraries.

=head1 Introduction

=head2 Setup

The two main ways to start a shell session are via &shell and &once.
The advantage of &once, at least in a commandline environment, is that it is
easily shell scriptable since it is noninteractive. To set up &once :

	my $sh = Fry::Shell->new(prompt=>$prompt);
	$sh->once(@ARGV);

To set up &shell:

	my $sh = Fry::Shell->new(prompt=>$prompt);
	$sh->shell(@ARGV);

=head2 SYNOPSIS Explained

What can you do in your shell? Run any subroutines which you define as commands (or even better
commands defined by libraries). Even if your subroutines are not defined
they can still be executed by typing the subroutine's name. In SYNOPSIS above, &evalIt is such a
subroutine.

Looking at &evalIt's innards, you see that the first argument is $o which is the shell
object.  This is due to most commands being called as an object method. You also see 
' $o->Flag("strict") ' which is a boolean flag to prepend a 'use strict' to the evaluated code. Since
we defined an option as type flag when initializing the shell, we change the flag's value when we
flip the option from the commandline (ie '-n evalIt $ref = "woah"; $foo = "ref"; print $$foo').

&listStations is a cool example of the menu option. You'll need to have a music player that can
be executed via a system call, most likely a *nix environment, and that can play shoutcast radio stations (ie xmms).
Without any options, this command simply prints a list of stations. If you use the menu option (ie
'-m lS'), the next input line is parsed differently with numbers being substituted with
corresponding positions from the variable lines. For example,'! xmms 2', would call xmms with the 2nd radio
station in the variable lines. The &saveArray call is what passed the list of ip's to the variable lines.

=head2 Using Options

Options come before commands. How they are parsed depends on &parseOptions.
By default, an option begins with a '-'. You can specify an option's alias or full name. To set
an option's value put a '=' and the option value after it ie '-menu=1'.
If no '=' comes after an option name then the option is treated as a flag and set to 1 (ie the
previous example can be written '-menu').

=head1 LIBRARIES

=head2 Using Libraries

The SYNOPSIS section contains a good example of a shell with a couple of functions. But what happens
if you expand on this and develop several more radio-playing commands and other eval-based commands?
You would probably break them up into separate shells as the shell gets crowded with too many
commands you don't need for a given session. It's at this point that a library comes in handy.

A library is simply a group of related subroutines. At its simplest you can place your functions in
a library, load the library and be able to execute any of the functions. You can load library(ies)
when initializing a shell via the libs attribute :

	Fry::Shell->new(libs=>[qw/:Lib1,Fry::Lib::Lib2/]);

or after initialization via &initLibs:

	$sh->initLibs([qw/:Lib1, Fry::Lib::Lib2/]);

Notice the shorthand ':Lib1' in both examples. This abbrevations means
Fry::Lib::Lib1 and is valid notation for &initLibs and &loadLibs.

Even if no libraries are specified, a shell loads the lib Fry::Lib::Default. Its functions enable
you to view and change the core shell components.

=head2 Writing Libraries

Libraries are usually placed under Fry::Lib. Other namespaces will work for now but are only
recommended if you can't get under the Fry::Lib namespace .  To use most shell features, you need to
define shell components in your library. Currently this is only done via &_default_data. However,
since it only returns a hashref, there are many possible ways of storing configuration data ie
databases,xml,dbm, FreezeThaw ...  

A good library example is Fry::Lib::Default.

=head3 SETUP

=head4 &_default_data

&_default_data returns a hashref that can set library attributes
and create any shell component. It consists of any of the following keys: 

	depend(\@): lists other libraries that this library depends on.

	Dependent modules and their configurations are required and read before the current library.
	This parameter can also take the abbrevation of &initLibs of a beginning colon meaning 'Fry::Lib::'.

	cmds(\%): Defines commands with each id pointing to a defined object. A command object's attributes are explained in Fry::Cmd.

		cmds=>{cmd1=>\%obj1,cmd2=>\%obj2}

	opts(\%): Defines options with each id pointing to a defined object. An option object's attributes are explained in Fry::Opt.
	vars(\%): Defines variables with each id pointing to a defined object. A variable object's attributes are explained in Fry::Var.
	lib(\%): Defines pseudo-components, in development. Can take following keys:  
		cmds(\@): Used with &objectAct to treat an autoloaded module's methods as library commands.
		
=head4 &_initLib

	This is an optional subroutine that initializes anything within the library after loading
its configuration data. Its explicitly run via &Fry::Lib::runLibInits.

=head3 Writing Library Functions

Since libraries functions are treated as shell object methods, the first
argument in any command-defined function is a shell object. With a shell
object you have many of its features available to you. The section Public Library
Interface covers all methods available to a library. I'll briefly emphasize
the essential ones: dumper,Flag,setFlag,Var,view,_die and _warn. 

Since Fry::Shell is written with a flexible view in mind, it is recommended to
pass all your output to &view.  By doing this, your functions' output can be
displayed by any plugin under Fry::View.  However, if you want to write
libraries that are as portable as possible, you'll avoid embedding view
methods. So how will you display your command's output?  Return the data
structure you want displayed in your functions. See Fry::Lib::Default for
examples. &autoView then displays the command's output.  &autoView supports
the following data structures: array, arrayref,hashref and scalar. Anything
more complicated should be dumped.

For error throwing I recommend using &_die and &_warn, which are configurable
via variables diesub and warnsub. For now they are mainly a means of
centralizing errors. For retrieving variables, use &Var for one variable and
&varMany for many. For dumping data structures,I recommend using &dumper which
calls a dump plugin's main method. Being a plugin, it provides multiple ways
to dump a data structure. The final methods that should be emphasized are
&Flag and &setFlag which retrieve and set flag values.

A dilemma you mave come across when developing more complex libraries is
portability. Perhaps you want to reuse a library's functions in other
applications. Your library will fail in other applications that don't define
shell object methods. The obvious solution is minimizing the use of shell
object methods throughout your code. Although some methods are hard to work
around (ie &_warn and &_die which you either use or don't), you can work
around the variable and flag-related methods. Define global hashes for
Fry::Shell flags and variables. Then write a wrapper around the command
setting the needed variables and flags:

	my (%flag,%var);

	sub commandMammoth {
		my $o = shift; 

		#set variables
		for my $v (qw/Pi fodder goatcheese/) {
			$var{$v} = $o->Var($v)
		}
		#set flags
		for my $f (qw/complex simple fakeit/) {
			$flag{$f} = $o->Flag($f)
		}

		#original command
		#use %flag and %var in mammothAlgorithm
		$o->mammothAlgorithm(@_);
	}

=head1 PLUGINS

Fry::Shell plugins provide flexibility for often used shell features both in functionality and in
module dependency. In making Fry::Shell as portable as possible,  the default plugins do not require
any external modules. If Data::Dumper and Term::ReadLine::Gnu are detected,their plugins are
autoupgraded. When a plugin is loaded it is required and then initialized via &setup. Plugins do not
currently have their own shell components like libraries.  There are currently four plugins: View,
ReadLine,Dump and Config.

=head2 View

View handles the view of the shell. Currently only a commandline view exists.  A view outputs to the
filehandle specified by the var 'fh' and should have special output formats for an array and a hash.
A view's methods can be accessed via the accessor View ie $o->View->list(@output).

=head2 ReadLine

ReadLine plugins are usually interfaces to Term::ReadLine::* modules. Its main method is &prompt
which reads input and returns it. These plugins are still in a state of flux and will delve
into run-time configurable autocompletions as well as command history logging.
Fry::Shell comes with three of these plugins:

	Fry::ReadLine::Default- only reads and returns, no features
	Fry::ReadLine::Basic- basic interface to Term::ReadLine
	Fry::ReadLine::Gnu- uses Term::ReadLine::Gnu and provides auto completion of
		options,commands and a command's arguments (if defined).

=head2 Dump 		

Dump renders complicated data structures viewable. As there are at least a handful of dumper modules
I thought it would be handy to offer this flexibility.  A dump's methods can be accessed via the
accessor Dump ie $o->Dump->dump(@stuff).

=head2 Config(uration)

	Config plugins read configuration data (as if you didn't know). Currently only
file configurations exist. Configurations are read when initializing the shell. There are two
configurations,a core one and a global one. The core one is read after loading data in this module's
&_default_data.  Part of the core data contains plugin classes so redefine them here. Since the core
config is read before you can specify your preferred config plugin, it will always be read by
Fry::Config::Default which requires a hashref named $conf. The global config is the place to
redefine any shell components from loaded libraries. Loading a configuration is done via a plugin's
&read.

Configurations can also be loaded at the script level via &loadFile.

	$sh->loadFile('/home/dope/.mylovelyconfig');

=head3 Config Data Structure Format

	A configuration defines a hashref similar to a library's &_default_data, no suprise since
they're both defining shell components. It consists of any of the following keys:

	cmds(\%): Defines commands with each id pointing to a defined object. A command object's attributes are explained in Fry::Cmd.
	opts(\%): Defines options with each id pointing to a defined object. An option object's attributes are explained in Fry::Opt.
	vars(\%): Defines variables with each id pointing to a defined object. A variable object's attributes are explained in Fry::Var.

=head3 Configuring Core Variables

When configuring core shell components (defined in this module's &_default data),
you'll usually modify variable values.  Here's a quick overview of core
variables and what they do (note,variables take a scalar value unless
indicated otherwise):

	defaultlib: default library loaded instead of Fry::Lib::Default
	base_class: name of class which inherits autoloaded classes
	cmd_class: name of class which inherits loaded libraries
	plugin_config: config plugin 
	plugin_readline: readline plugin
	plugin_dump: dump plugin
	plugin_view: view plugin
	defaultlibs(\@): default libraries to load
	alias_parse(\%): mapping commandline aliases to parse subroutine names
	parsesub: current parse subroutine
	warnsub: subroutine called by &Fry::Error::_war
	diesub: subroutine called by &Fry::Error::_die
	fh: current filehandle for output
	view_options(\%): contains options to be passed at
	eval_splitter: used by &parseEval to delimit where normal parsing ends and where eval parsing begins
	field_delimiter: delimits fields used by Fry::View::* modules
	fh_file: used with fh_file option to specify filename
	pager: name of preferred pager
	mline_char: regular expression indicating end of a multiline command
	pipe_char: regular expression used to delimit piping between command names on commandline
	prompt: shell prompt
	core_config: name of core config file
	global_config:name of global config file
	lines: used by the menu option
	loaded_libs(\@): currently loaded libraries

=head1 Miscellaneous	

=head2 Loading Order of Shell Components

When considering where and how to overwrite shell component values, it helps to understand in what
order they are loaded. Here it is: config of Fry::Shell library, core config, config of all other libraries,
global config,load_obj option of &new and options setting variable values.

=head2 Useful Options

Fry::Shell comes with a few handy options (defined in &_default_data): 

	parsesub: sets the current parsing subroutine, handy when needing to pass a command a
		complex data structure and want to use your own parsing syntax
	menu: sets parsesub to parseMenu thus putting the user in a menu mode
		where each output line is aliased to a number for the following
		command, explained in SYNOPSIS Explained section
	fh_file: sends command's output to specified file name
	pager: sends command's output to preferred pager
	autoview: flag which turns on/off autoview and a command's subroutine outputs for itself
	skiparg: flag which turns on/off skipping command argument checking

=head2 Defining Parsers

You can define your own parse subroutines to parse the input after options. A parse subroutine
receives its input as a string and returns the command and its arguments in an array.

	sub parseMyWay {
		my ($o,$input) = @_;
		return (split(/ |,/$input))
	}

Good examples of parse subroutines are any parse* methods. You can define your
own parse subroutines by putting them in any library to be loaded. To alias
the subroutine, add an entry to the variable alias_parse. I would recommend doing this in
a global config file. Don't forget to also place the defaults key-value pairs of alias_parse in the
redefinition.

=head2 Multiline Mode

To start a multiline session you flip the multiline option (ie '-M').
The multiline mode lasts as long as it doesn't encounter the variable
mline_char, default being ';'. Multiple lines of input are joined by a whitespace.

=head2 Using Autoloaded Libraries

This is a sweeet feature implented via &classAct and &objectAct that allow
you to load a normal module and act on its object and/or class methods.
See Fry::Lib::Default for details.

=head1 Class Methods

Public class methods have been divided into script and library interface
categories. These categories are only recommendations and a shell object's
script method could be called in a library and vice versa. A method's
arguments are described via data structure symbols @,$,% and a descriptive
name. Optional arguments are described in perl regular expression format.

=head2 Public Script Interface

Public methods that are recommended for usage in a script
which runs a shell session.

	new(%options): Creates a shell object and creates its shell components ie load
		libraries and initialize core data. It can take any variable
		name and value pairs as well as the following keys:
		
			load_obj(\%): Creates shell components via &setAllObj,see it for data
				structure format 
			libs(\@): Loads libraries after having loaded all libraries specified in
				configs.
			lib($): Uses a lib class other than Fry::Lib.
			cmd($): Uses a cmd class other than Fry::Cmd.
			opt($): Uses an opt class other than Fry::Opt.
			var($): Uses a var class other than Fry::Var.
			core_config

		Note: For further description of core variables look at the above section
		Configure Core Variables. You can pass a core variable as an option just like any
		other variable.

	shell(@input?): Starts the shell's main loop. Optional argument is input to first loop iteration.
	once(@input?): One iteration of loop. If optional argument isn't given, prompts for input.
	runCmd(@args): Executes given command and arguments.
	initLibs(@libs): Loads libraries and calls library initialization subroutines.
	loadLibs(@libs): Only loads libraries.
	loadFile($file): Reads config file via config plugin.
	loadPlugins(@vars): Loads plugins by their variable name ie plugin_config.
	setVarObj(%id_to_obj): Creates Variable objects, expected hash maps ids of
		objects to objects.
	setOptObj(%id_to_obj): Creates Option objects in same way as &setVarObj.
	setCmdObj(%id_to_obj): Creates Command objects in same way as &setVarObj.
	setLibObj(%id_to_obj): Creates Library objects in same way as &setVarObj.
	setAllObj(%id_to_obj): Creates objects for a library's shell components with the following keys:
		cmds(\%): passes argument to &setCmdObj
		opts(\%): passes argument to &setOptObj 
		vars(\%): passes argument to &setVarObj

=head2 Public Library Interface

Public methods that are recommended for usage in a library.

	saveArray(@args): Sets the lines variable for use with the menu option.
	Var($var): Returns a variable value.
	varMany(@var): Returns several variable values.
	setVar(%var_to_value): Sets variable values with hash mapping variables to values.
	List($shell_component): Returns list of object ids for given shell component
		class; valid arguments are lib,var,opt,cmd.
	listAll($shell_component): Returns list of object ids and their aliases for given shell component
		class.
	view(@arg): Calls the view plugin's &view. This is the recommended subroutine
		to print out most data.
	dumper(@arg): Calls the dump plugin's &dump for dumping a data structure.
		Note that dumping doesn't output the data structure but returns a string
		dump. To print out a dump you could do this:
		$o->view($o->dumper($gargantuanDataStructure)).
	Flag($flag): Returns a flag's value.
	setFlag($flag,$value): Sets a flag's value, which should be 1 or 0.

	Accessors for shell component classes:
		
		lib: library class
		cmd: command class
		var: variable class
		opt: option class

	Accessors for plugin classes: Returns a plugins' class name. Used to call a plugins' methods ie
	'$o->View->list(@deals);'

		Dump: dump plugin
		View: view plugin
		Rline: readline plugin
		Config: config plugin

=head2 Class Methods to Redefine

Methods recommended to redefine when creating your own Fry::Shell subclass.

	preLoop(): This subroutine executes at the beginning of every shell loop.
	postLoop(): This subroutine executes at the end of every shell loop.
	loopDefault($cmd,@arg): This subroutine executes if no valid command is given. By default this sub
		returns an error message of an invalid entry. It is passed an array containg the command and
		its arguments.

=head1 See Also
	
L<Class::Data::Global> for global class data questions.

For similar light shells, see L<Term::Shell>,L<Shell::Base> and
L<Term::GDBUI>.

For big-mama shells look at L<Zoidberg> and L<PSh>.

=head1 TO DO

There are a jazillion things I would like to do with this module.
Top priorities are writing a Devel tutorial to better explain Fry::Shell's innards
and to rewrite the Class::DBI libraries so that they are compatible with this version.
Then ...

	priority 1
		autoload modules
			develop framework around &objectAct
			be able to load:
				OO methods ie List::Compare
				class methods ie Class::DBI 
				functions ie Date::Manip
		view plugin: cgi view 
		develop configuration format for autoloaded modules and plugins
			menu or option-based choosing of a class's global settings
			menu or option-based choosing of a module's functions
		error framework
		readline
			edit cmd in file
			save history between sessions
			save cmds to file to edit + reexecute
				save currently done cmds,quit and redo w/ a command
			map commands to keys
			cmdline options in how + what to autocomplete
	priority 2	
		make parser object to be used by option parsesub
		opt
			autoset w/ cmds
			check that var exists for opt of type var
		cmd
			define pre+post subs
				autoaliasing arguments
			define a return attribute- this could allow autocompleting
				commands that can be piped another command's input
			autousage from arg

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
