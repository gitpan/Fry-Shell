package Fry::Opt;
use strict;
use base 'Fry::List';
use base 'Fry::Base';
my $list = {};

#sub list { return $list }
#sub _hash_default {return {qw/default 0 type none/} }
sub _hash_default {return {qw/type none default 0/} }

	sub Opt ($$) {
		#d: special case of get w/ 'value'
		my ($cls,$id) = @_;
		#only allow defined id past here
		$id = $cls->findAlias($id) || return undef;

		my $type = $cls->obj($id)->{type};

		if ($type eq "var") {
			return $cls->_varClass->get($id,'value')
		}
		elsif ($type eq "flag") {
			return $cls->_shellClass->Flag($id);
		}
		else { return $cls->obj($id)->{value} }
	}
	sub findSetOptions ($) {
		my $cls = shift;
		my %opt;
		for my $opid ($cls->listIds) {
			$opt{$opid} = $cls->Opt($opid) if ($cls->Opt($opid) ne $cls->obj($opid)->{default})
		}
		return %opt;
	}
	sub resetOptions ($\%) {
		my ($cls,$options) = @_;
		my %opt;
		for my $opid ($cls->listIds) {

			#skip reset
			if (exists $cls->obj($opid)->{stop} && $cls->obj($opid)->{stop} > 0) {
				$cls->obj($opid)->{stop} = $cls->obj($opid)->{stop} - 1;
				next if (! exists $options->{reset});
			}
			next if ($cls->obj($opid)->{noreset} && ! exists $options->{reset});

			$opt{$opid} = $cls->obj($opid)->{default} || 0;
		}
		$cls->setOptions(%opt);
	}
	sub setOptions ($%) {
		#d: special case of setMany w/ 'value'
		my ($cls,%arg) = @_;

		while (my ($id,$value) = each %arg) {
			#convert alias to fullname
			$id = $cls->findAlias($id) || do { $cls->_warn("option $id isn't valid, skipped");next };
			#td: convert to %opttype
			my $type = $cls->obj($id)->{type};

			if ($type eq "flag") {
				#$cls->{flag}{$id} = $value;
				$cls->_shellClass->setFlag($id=>$value);
			}
			elsif ($type eq "var") {
				$cls->_varClass->set($id,'value',$value);
			}
			#elsif ($type eq "sub") { 
				#$cls->{opt}{$id}{value} = $value ;
				#$cls->$id($value);
			#}
			else { $cls->obj($id)->{value} = $value }

		}
	}
	sub preParseCmd ($%) {
		#d: need only opt ids so far	
		my ($cls,%arg) = @_;
		while (my ($id,$value) = each %arg) {
			$id = $cls->findAlias($id) || do { $cls->_warn("option $id isn't valid, skipped");next };

			if (exists $cls->obj($id)->{tags} && $cls->obj($id)->{tags} =~ /counter/) {
				$cls->obj($id)->{stop} = 1;
			}

			if (exists $cls->obj($id)->{action}) {
				$cls->obj($id)->{action}->($cls->_shellClass->_obj,$value);
			}
		}
	}

	#Deprecated
	sub setDefaults ($) {
		my $cls = shift;

		for my $opt ($cls->listIds) {
			#if (! exists $cls->obj($opt)->{default}) {
				#$cls->obj($opt)->{default} = (exists $cls->obj($opt)->{value}) ?
				#$cls->obj($opt)->{value} : 0;
				$cls->obj($opt)->{default} = ($cls->Opt($opt)) ?
					$cls->Opt($opt): 0;
					#}		
		}
	}
	#sub new ($%) {
		#my ($class,%arg) = @_;
		#$class->SUPER::new(%arg);
		#$class->setDefaults;
	#}
1;

__END__	

=head1 NAME

Fry::Opt - Class for shell options.

=head1 DESCRIPTION 

Most option methods are called only when an option is set from the commandline. Such an option is
called an active option.  Near the end of each loop iteration, options along with other shell
components are reset. &resetOptions is then called and depending on an option's attributes is reset.

An option object has the following attributes:

	Attributes with a '*' next to them are always defined.

	*id($): Unique id which is its name.	
	a($): Option alias.
	tags($): Contains a value which modifies an option's behavior. Only defined value is 'counter' which sets 
		an active option's stop value.
	value($): Can contain an option's value. Currently only options' with no type store their value here.
	*type($): Indicates where an option gets/sets its value. Currently can be one of three: flag,var,none. 'none' is the default.
		A flag type syncs it value with a shell flag. A var type syncs its value with a
		variable. A none type gets its value from the attribute value.
	action(\&): Given subroutine is called before a command for an active option.
		Subroutine is passed the shell object and the options' value set from the
		commandline. 
	stop($): Maintains an option's value for $stop + 1 loop iterations where $stop
		is this attribute's value. This gives an active option a timed noreset interval. Used mostly with menu option.
	noreset($): If set, the active option can't be reset (except for an overriding flag to &resetOptions).
	*default($): Default value that an option starts with and is set to whenever reset. Default value is 0.

=head1 Class Methods

	Opt($opt): Returns an option's value.
	findSetOptions(): Returns hash of options that differ from their default
		values. Used when displaying the prompt.
	resetOptions(): Iterates through all options and resets them according to attributes.
	setOptions(%opt_to_value): Sets options to their values.  
	preParseCmd(%opt_to_value): Called before command execution with active
		options and their values to do various things depending on an option's
		attributes.

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 COPYRIGHT & LICENSE

Copyright (c) 2004, Gabriel Horner. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
