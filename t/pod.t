#!/usr/bin/perl
use Test::More;
#plan tests=>1;
eval "use Test::Pod";
plan skip_all => "Test::Pod required for testing POD" if $@;
all_pod_files_ok();
exit;
my @files = qw# t/fry_base.t t/fry_cmd.t t/fry_error.t t/fry_lib.t t/fry_opt.t t/fry_shell.t
	t/fry_sub.t t/fry_var.t#;
for (@files) {	
	pod_file_ok($_,'Valid POD');
}
