#!/usr/bin/perl -w

use strict;
use lib '../lib';
use Mail::Graph;

my $mg = Mail::Graph->new( 
  input => 'archive',		# input path
  output => 'output',		# output path
  template => 'index.tpl',	# the output will be templatename.html
				# so change index.tpl to stats.tpl to get
				# stats.html as output
  no_title => 1,		# should graphs have a title? 1 => no, 0 => yes
  );
die "Error: ",$mg->error(),"\n" if $mg->error();
$mg->generate();

print "\nDone\n";
