package Fry::Lib::DBI;
use strict;
use DBI;
our ($dbh);
sub _default_data {
	return {
		vars=>{user=>'bozo',pwd=>'bozo',db=>'pg',dbname=>'useful',
			dsn=>{qw/mysql dbi:mysql: pg dbi:Pg:dbname= sqlite dbi:SQLite:dbname=/}, 
			attr=>{},
		},
		lib=>{
			#class: avail,data_sources,trace
			#dbh: select*,do; table_info commit*,err,get_info,tables,type_info_all,primary_key_info
			cmds=>[qw/selectall_arrayref selectall_hashref selectrow_arrayref selectrow_hashref
				available_drivers trace get_info table_info column_info primary_key_info
				tables type_info_all do err errstr set_err begin_work commit rollback/],
			#other obj:
		},
	}
}
sub _initLib {
	my ($o,%arg) = @_;
	my ($dsn,$db,$dbname,$user,$pwd,$attr) = $o->varMany(qw/dsn db dbname user pwd attr/);
	#print join(',',$o->varMany(qw/dsn db dbname user pwd attr/));
	$o->{obj}{dbh}{o} = $dbh = DBI->connect($dsn->{$db}.$dbname,$user,$pwd,$attr);
	#$o->lib->obj('Fry::Lib::DBI')->{obj}{dbh} = $dbh = DBI->connect($dsn->{$db}.$dbname,$user,$pwd,$attr);
	#$o->{obj}{dbh}{class} = "Fry::Lib::DBI";
}
1;

__END__	

=head1 NAME

Fry::Lib::DBI - Autoloaded library for DBI's object methods. 

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
