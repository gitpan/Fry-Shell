package Fry::Lib::Default;
use strict;

	sub _default_data {
		return {
			cmds=>{
				objectAct=>{a=>'o',u=>'$obj $libcmd @args',
					d=>'Executes given method and its arguments using current autoloaded object'
				},
				classMethods=>{qw/a \cm/,
					d=>'Prints a class \'s public methods', u=>'$class'},
				classAct=>{a=>'c',u=>'$lib $method @args',
				d=>''},
				printVarObj=>{a=>'\pv',arg=>'@var', d=>'Dumps variable objects'},
				printCmdObj=>{a=>'\pc',arg=>'@cmd', d=>'Dumps command objects'},
				printOptObj=>{a=>'\po',arg=>'@opt', d=>'Dumps option objects' },
				printLibObj=>{a=>'\pl',arg=>'@lib', d=>'Dumps library objects'},
				printGeneralAttr=>{a=>'\pg',u=>'$sh_comp$attr@ids',
					d=>'Dumps an attribute of specified shell component'},
				listVars=>
					{d=>'List variables',u=>'',a=>'\lv'},
				listOptions=> {d=>'List loaded options',
					u=>'',a=>'\lo'},
				listCmds=>
					{d=>'List loaded commands',
					u=>'',a=>'\lc',} ,
				listLibs=>{a=>'\ll',d=>'List loaded libraries'},	
				helpUsage=>{d=>'Prints usage of function(s)',
					a=>'h',arg=>'@cmd'},
				helpDescription=>
					{d=>'Prints brief description of function(s)',
					,a=>'\h',arg=>'@cmd'},
				quit=>{d=>'Quits shell', u=>'',a=>'q'},
				perlExe=>
					{d=>'Executes arguments as perl code with eval',
					u=>'$perl_code',a=>'\p'},
				evalVar=>
					{ d=>'Set a variable equal to any data structure via an eval',
					u=>'$accessor $data_structure',a=>'\sv'},
				unloadLib=>{a=>'\ul',arg=>'@lib',d=>'Unloads libraries'},
				unloadCmd=>{a=>'\uc',arg=>'@cmd',d=>'Unloads commands'},
				unloadOpt=>{a=>'\uo',arg=>'@opt',d=>'Unloads options'},
				unloadVar=>{a=>'\uv',arg=>'@var',d=>'Unloads variables'},
				initLibs=>{a=>'\lL',d=>'Loads and initializes libraries',u=>'@lib'},
				#setVar=>{a=>'\sV',arg=>'%var',d=>'sets},
				sysExe=>{a=>'!',d=>'Executes system calls via system()',u=>'$sysCmd'},
			},
			vars=>{
				#action_class=>'DBI',
				autolib=>'Fry::Lib::DBI',
			},
		}
	}
	#h: multiple aliases for help
	*help = \&helpDescription;
	sub listCmds ($) { 
		my $o = shift;
		my @list = sort $o->List('cmd');
		#my @lines = map {$_ = $_.": ".$o->cmdObj($_)->{a} } @list;
		#$o->View->list(@list); 
		$o->saveArray(@list) if ($o->Flag('menu'));
		return @list;
	}
	sub listOptions ($) {
		my $o = shift;	
		my @list = sort $o->List('opt');
		#$o->View->list(@list);
		$o->saveArray(@list) if ($o->Flag('menu'));
		return @list;
	}
	sub listVars ($) {
		my $o = shift;	
		my @list = sort $o->List('var');
		#$o->View->list(@list);
		$o->saveArray(@list) if ($o->Flag('menu'));
		return @list;
	}
	sub listLibs ($) { 
		my $o = shift;	
		my @list = sort $o->List('lib');
		#$o->View->list(@list);
		return @list;
		$o->saveArray(@list) if ($o->Flag('menu'));
	}
	#?: sub listGeneral($$){}
	sub printOptObj ($@) {
		my ($o,@opts) = @_;
		$o->printGeneralObj('opt',@opts);
	}
	sub printCmdObj ($@) {
		my ($o,@cmds) = @_;
		$o->printGeneralObj('cmd',@cmds);
	}
	sub printVarObj ($@) {
		my ($o,@vars) = @_;
		$o->printGeneralObj('var',@vars);
	}
	sub printLibObj ($@) {
		my ($o,@libs) = @_;
		$o->printGeneralObj('lib',@libs);
	}
	sub printGeneralObj ($$@) {
		my ($o,$attr,@ids) = @_;
		my $output;
		#local $Data::Dumper::Deparse=1;
		local $Data::Dumper::Terse = 1;

		@ids = sort $o->List($attr) if (scalar(@ids) == 0);
		my $sub = $attr."Obj"; 
		for my $id (@ids) {
			$output->{$id} = $o->dumper($o->$sub($id));
		}
		#$o->View->hash($output,{quote=>1,sort=>1});
		$o->setVar(view_options=>{quote=>1,sort=>1});
		return $output;
	}
	sub helpDescription($@) { shift->printGeneralAttr('cmd','d',@_) }
	sub helpUsage ($@) {
		my ($o,@cmds) = @_;
		#$o->view("Note: wrap <> around optional chunks\n\n");
		$o->printGeneralAttr('cmd','u',@cmds);
	}
	#?: printVar
	sub printGeneralAttr ($$$@) {
		my ($o,$attr,$field,@ids) = @_;
		my ($output,$quote);
		local $Data::Dumper::Terse = 1;
		no strict 'refs';
		my $sub = $attr."Obj";

		@ids = sort $o->List($attr) if (scalar(@ids) == 0);
		for my $id (@ids) {
			if ($attr eq "var") {
				$output->{$id} = $o->dumper($o->$sub($id)->{$field});
			}
			else {
				$output->{$id} = $o->$sub($id)->{$field};
				$quote =1;
			}
		}
		$o->setVar(view_options=>{quote=>$quote,sort=>1});
		return $output;
		#$o->View->hash($output,{quote=>$quote,sort=>1});
	}
	#other
	sub unloadLib ($@) {
		my ($o,@libs) = @_;
		@libs = $o->lib->fullName(@libs);

		for my $l (@libs) {
			$o->unloadCmd(@{$o->libObj($l)->{cmds}});
			$o->unloadOpt(@{$o->libObj($l)->{opts}});
			$o->unloadVar(@{$o->libObj($l)->{vars}});
			$o->unloadGeneral('lib',$l);
		}
	}
	sub unloadCmd ($@) { shift->unloadGeneral('cmd',@_) }
	sub unloadOpt ($@) { shift->unloadGeneral('opt',@_) }
	sub unloadVar ($@) { shift->unloadGeneral('var',@_) }
	sub evalVar ($$@) {
		my ($o,$var,@value) = @_;
		my $textvar = '$o->varObj($var)->{value}';
		eval "$textvar = @value ";
	}
	sub sysExe ($@) {
		shift;
		system(@_);
	}	
	sub perlExe ($@) { 
		#?: how does it set Data::Dumper::
		my $o = shift;	
		my $code = "@_";
		#$code =~ s/->/$o->/g;
		eval "$code";
		#eval "@_";
	}
	sub quit ($) { $_[0]->setFlag(quit=>1) }
	sub objectAct ($$@) {
		my ($o,$obj,$sub,@args) = @_;

		#$o->setVar(autolib=>$o->{obj}{$obj}{class});
		my @output = $o->{obj}{$obj}{o}->$sub(@args);
		return @output;
	}
	sub classAct ($$$@) {
		#?:don't even need lib
		my ($o,$lib,$sub,@args) = @_;
		$lib = ($o->lib->fullName($lib))[0];

		#print $o->lib->obj($lib)->{class},"\n";
		my @output = $o->lib->obj($lib)->{class}->$sub(@args);
		#$o->view($o->dumper(\@output));
		return @output;
	}
	sub classMethods ($$) {
		my ($o,$lib) = @_;
		no strict 'refs';
		my @methods = sort keys %{"$lib\::"};
		@methods = grep(/^[^_A-Z]/,@methods);
		$o->saveArray(@methods);
		#$o->View->list(@methods);
		return @methods;
	}
	#test subs
	sub t_gen {
		my ($o,$attr,@cmds) = @_;
		for (@cmds) {
			#w: will break if obj accessors change
			return 0 if (not $o->$attr->objExists($_))
		}
		return 1
	}
	sub t_cmd { shift->t_gen('cmd',@_); }
	sub t_opt { shift->t_gen('opt',@_); }
	sub t_var { shift->t_gen('var',@_); }
	sub t_lib { my $o = shift; $o->t_gen('lib',$o->lib->fullName(@_)); }
	sub t_libcmd { return 1 }
	#cmpl subs
	#was used with objectAct
	sub cmpl_libcmd { my $o = shift; return @{$o->libObj($o->Var('autolib'))->{cmds}} }
	sub cmpl_cmd { shift->List('cmd') }
	sub cmpl_opt { shift->List('opt') }
	sub cmpl_lib { shift->List('lib') }
	sub cmpl_var { shift->List('var') }
1;	

__END__	

=head1 NAME

Fry::Lib::Default -  Default library loaded by Fry::Shell

=head1 DESCRIPTION 

This library contains the basic commands to manipulate shell components: listing them,
dumping (printing) their objects,unloading them, loading them via a library and a few
general-purpose functions. Currently the commands are documented by their above definitions in
&_default_data ie their 'u' attribute describes what input they take and their 'd' attribute describes
them.

=head1 Autoloaded Libraries

There are currently two ways of using an autoloaded library via a library's class methods or a library's object
methods. These two ways use the commands classAct and objectAct respectively. Before using either
command you must load an autoload library via &initLibs.

=head2 &classAct

The only current autoload library for &classAct is Fry::Lib::Inspector. After
installing Class::Inspector, start a shell session and load this library (ie 'initLibs :Inspector').
You can now execute the class methods of Class::Inspector! Looking at the 'u' (usage) attribute of
classAct above you see that the first argument is a library followed by a method and then its
arguments. For example you could run the &resolved_filename method of Class::Inspector ie
'classAct :Inspector resolved_filename Class::Inspector'. Note that I don't have to
change the parsing of this line as the arguments neatly split on whitespaces (the default parser).
Also, the :$basename is a shorthand for libraries under Fry::Lib space.

=head2 &objectAct

We'll use Fry::Lib::DBI as our sample library. Installing DBI and load the library as before ie
'initLibs :DBI'. To establish your own database connection you need to define your own variables
for user, password (pwd),dbms (db) and database (dbname) in a separate config file (or just change
them in the module in &_initLib for a quick hack ;)). The former requires using &loadFile $filename
at the commandline. You can now act on methods of a basic database handle. The usage for &objectAct
indicates to pass the object name followed by its method and its arguments ie 'objectAct dbh tables' which
will print out all the database's tables. A more advanced command could be "-p=e objectAct dbh
selectall_arrayref,,'select * from perlfn' ". This commandline changes the parse subroutine to
&parseEval and executes an sql query on the perlfn table. You should have gotten a list of records.
You now have a simple DBI shell without having hardwritten any perl code!


=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
