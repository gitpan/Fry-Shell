package Fry::List;
#public
	my $list = {};
	our $Warn = 0;
	sub new ($%) {
		my ($class,%arg) = @_;
		if (! exists $arg{id}) { warn "id attribute not set";return 0 } 
		$class->setHashDefault(\%arg);
		bless \%arg,$class;
		#$class->$currentList->{$arg{id}} = \%arg;
		$class->list->{$arg{id}} = \%arg ;
		#td: if (! exists $cls->list->{$arg{id};
	}
	#sub list { die "This is an abstract method which shouldn't be called\n"; }
	sub list {$list}
	sub _hash_default {return {}}
	#both
	sub manyNew ($%) {
		my ($class,%arg) = @_; 
		$class->setId(%arg);
		for (values %arg) { $class->new(%$_) }
	}
#inter-core class int
#Fry::Shell interface
	#get/set obj
	#sub objExists ($$) { (exists $_[0]->list->{$_[1]})?1 :0}
	sub objExists ($$) { 
		if (exists $_[0]->list->{$_[1]}) { return  1}
		elsif ($Warn ==1) {warn "nonexistent obj $_[1] specified from ".(caller(1))[3]."\n";return 0 };
	}
	sub obj ($$;$) {
		$_[0]->list->{$_[1]} = $_[2] if (@_ > 2); 
		return $_[0]->list->{$_[1]} 
	}
	sub unloadObj ($@) {
		my ($cls,@ids) = @_;
		for my $id (@ids) {
			delete $cls->list->{$id};
		}
	}
	sub setObj ($%) {
		my ($cls,%arg) = @_;
		while (my ($id,$obj) = each %arg){
			#e:new obj not created
			$cls->list->{$id} = $obj if ($cls->objExists($id));
		}
	}
	sub getObj ($%) {
		my ($cls,@ids) = @_;
		my @valid;
		for (@ids) { push(@valid,$cls->list->{$_}) if ($cls->objExists($_)) }
		return @valid;
	}
	#get/set attr
	sub get ($$$) { return $_[0]->list->{$_[1]}{$_[2]} if ($_[0]->objExists($_[1])) }
	sub set ($$$$) { return $_[0]->list->{$_[1]}{$_[2]} = $_[3] if ($_[0]->objExists($_[1])) }
	sub getMany ($$@) { 
		my ($cls,$attr,@ids) = @_; 
		my @valid;
		for (@ids) { push(@valid,$cls->list->{$_}{$attr}) if ($cls->objExists($_)) }
		return @valid;
	}
	sub setMany ($$%) {
		my ($cls,$attr,%arg) = @_;
		while (my ($id,$value) = each %arg) {
			next if	(! $cls->objExists($id));
			$cls->list->{$id}{$attr} = $value
		}
	}
#misc	
	sub listIds ($){ return keys %{$_[0]->list} }
	sub listAlias ($) { return map { $_[0]->list->{$_}{a} } keys %{$_[0]->list} }
	sub listAliasAndIds ($) { return ($_[0]->listIds,$_[0]->listAlias) }
	sub findAlias ($$) {
		#d: returns alias if alias is a cmd,returns alias if found,returns undef if not found
		my ($cls,$alias) = @_;
		return $alias if (exists $cls->list->{$alias});
		for my $id ($cls->listIds) {
			return $id if ($cls->list->{$id}{a} eq $alias)
		}	
		#to delete autovivified delete $o->{cmd}{$cmd};
		$cls->objExists($alias);
		return undef;
	}
	sub anyAlias ($$) {
		#d: returns alias if not found
		return $_[0]->findAlias($_[1]) || $_[1];
	}
	sub pushArray($$$@) {
		my $cls = shift; my $id = shift; my $attr = shift;

		#e: warn if not array
		if  (ref ($cls->obj($id)->{$attr}) eq "ARRAY" or ! exists $cls->obj($id)->{$attr}) {
			push(@{$cls->obj($id)->{$attr}},@_);
		}
	}
#private	
	sub setHashDefault ($\%) {
		my $cls = shift; my $arg = shift;
		my %default = %{shift() || $cls->_hash_default};
		while (my ($k,$v)= each %default) {
			$arg->{$k} = $v if (! exists $arg->{$k});
		}
	}
	sub setId ($%){
		#d: sets hash's id by given key
		my ($class,%arg) = @_; 
		while (my ($id,$obj) = each %arg) {
			$obj->{id} = $id;
		}
	}
	#old
	sub setHashDefaults ($$\%) {
		#handles multiple hashes	
		my ($o,$hashes,$default) = @_;
		my @hashes = (ref $hashes eq "ARRAY") ? @$hashes : $hashes; 
		for my $hash (@hashes) {
			while (my ($k,$v) = each %$default) {
				#print "$k,$v\n";
				$hash->{$k} = $v if (! exists $hash->{$k});
			}
		}
	}	
1;
__END__	

=head1 NAME

Fry::List - Base class serving as a container for its subclass's objects.

=head1 DESCRIPTION 

This base class provides to its sub classes class methods for storing and accessing its objects.
It also comes with a &new constructor which creates a hash-based object and stores it in the
container or list.  

Here are a few key points you should know:

	- All objects must have a unique 'id' in the list.
	- For now only one list of objects can be created per class.
	This list is stored in &list. You must create a &list in the subclass
	namespace to have a unique list. 
	- One alias to an object's id is supported via an 'a' attribute in an
	object. Use &findAlias to get the aliased id.
	- Default values for required attributes can be set via
	&_hash_default.They will only be made and set if the attribute isn't
	defined.
	- Warnings in this class can be turned on and off by the variable $Fry::List::Warn

=head1 CLASS METHODS

	new(%attr_to_value): Given hash is blessed as an object after setting defaults. 
	manyNew(%id_to_obj): Makes several objects.

	Get and Set methods
		obj($id,$object): Get and set an obj by id.
		setObj(%id_to_obj): Set multiple objects with a hash of id to object pairs.
		getObj(@ids): Gets several objects by id.
		unloadObj(@ids): Unload/delete objects from list.
		get($id,$attr): Gets an attribute value of the object specified by id.
		set($id,$attr,$value): Sets an attribute value of the object specified by id.
		getMany($attr,@ids): Gets same attribute of several objects
		setMany($attr,%id_to_values): Sets same attribute of objects via a hash of object to attribute-value pairs.

	Other methods
		listIds(): Returns list of all object id's.
		listAlias (): Returns list of all aliases of all objects.
		listAliasAndIds (): Returns list of all aliases and all ids.
		findAlias($alias): Returns id that alias points to. Returns undef if no id found.
		anyAlias($alias): Wrapper around &findAlias which returns $alias instead.
		pushArray($id,$attr,@values): Pushes values onto array stored in object's attribute.
		objExists($id): Checks to see if object exists. Throws warning if it doesn't.

	Subclassable subs
		list: Returns a hash reference for holding all objects.
		_hash_default: Returns a hash reference with default attributes and values.


=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
